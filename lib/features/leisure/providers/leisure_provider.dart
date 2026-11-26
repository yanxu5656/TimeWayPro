import 'package:flutter/material.dart';
import '../data/models/leisure_item.dart';
import '../data/repositories/leisure_repository.dart';

enum LeisureFilter { all, pending, done }

class LeisureProvider extends ChangeNotifier {
  LeisureProvider({LeisureRepository? repository})
    : _repository = repository ?? LeisureRepository();

  final LeisureRepository _repository;
  int _loadGeneration = 0;
  bool _disposed = false;

  List<LeisureItem> _items = [];
  bool _isLoading = false;
  LeisureFilter _filter = LeisureFilter.all;

  List<LeisureItem> get items => _items;
  bool get isLoading => _isLoading;
  LeisureFilter get filter => _filter;

  int get totalCount => _items.length;
  int get doneCount => _items.where((i) => i.isDone).length;

  List<LeisureItem> get filteredItems => switch (_filter) {
    LeisureFilter.all => _items,
    LeisureFilter.pending => _items.where((i) => !i.isDone).toList(),
    LeisureFilter.done => _items.where((i) => i.isDone).toList(),
  };

  void setFilter(LeisureFilter filter) {
    if (_filter == filter) return;
    _filter = filter;
    notifyListeners();
  }

  Future<void> loadItems() async {
    final int generation = ++_loadGeneration;
    _isLoading = true;
    notifyListeners();
    try {
      final List<LeisureItem> items = await _repository.getAll();
      if (_disposed || generation != _loadGeneration) return;
      _items = items;
    } catch (e) {
      if (!_disposed && generation == _loadGeneration) {
        debugPrint('Error loading leisure items: $e');
      }
    } finally {
      if (!_disposed && generation == _loadGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> addItem({required String title, String? note}) async {
    await _repository.addItem(
      LeisureItem(
        id: '',
        title: title,
        note: note,
        sortOrder:
            _items.fold<int>(
              -1,
              (max, item) => item.sortOrder > max ? item.sortOrder : max,
            ) +
            1,
        createdAt: DateTime.now(),
      ),
    );
    await loadItems();
  }

  Future<void> updateItem(LeisureItem item) async {
    await _repository.updateItem(item);
    await loadItems();
  }

  Future<void> deleteItem(String id) async {
    // 乐观删除：Dismissible 动画播完才触发 onDismissed，先同步更新
    // 状态让 UI 立即一致，再走持久化（与每周目标同一时序约定）
    final previousItems = _items;
    _items = _items.where((i) => i.id != id).toList();
    notifyListeners();
    try {
      await _repository.deleteItem(id);
      await loadItems();
    } catch (_) {
      _items = previousItems;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> toggleDone(String id) async {
    await _repository.toggleDone(id);
    await loadItems();
  }

  @override
  void dispose() {
    _disposed = true;
    _loadGeneration++;
    super.dispose();
  }
}
