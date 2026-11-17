import 'package:flutter/material.dart';
import '../data/models/leisure_item.dart';
import '../data/repositories/leisure_repository.dart';

enum LeisureFilter { all, pending, done }

class LeisureProvider extends ChangeNotifier {
  final LeisureRepository _repository = LeisureRepository();

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
    _isLoading = true;
    notifyListeners();
    try {
      _items = await _repository.getAll();
    } catch (e) {
      debugPrint('Error loading leisure items: $e');
      _items = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addItem({required String title, String? note}) async {
    await _repository.addItem(
      LeisureItem(
        id: '',
        title: title,
        note: note,
        sortOrder: _items.length,
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
    _items = _items.where((i) => i.id != id).toList();
    notifyListeners();
    await _repository.deleteItem(id);
    await loadItems();
  }

  Future<void> toggleDone(String id) async {
    await _repository.toggleDone(id);
    await loadItems();
  }
}