import 'package:uuid/uuid.dart';
import '../../../../core/utils/row_parse.dart';
import '../../../../shared/database/database_helper.dart';
import '../models/leisure_item.dart';

class LeisureRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _uuid = const Uuid();

  /// 没试过的排前面，同组内按排序号 / 创建时间
  Future<List<LeisureItem>> getAll() async {
    final maps = await _dbHelper.query('leisure_items');
    final items = parseRows(maps, LeisureItem.fromMap);
    items.sort((a, b) {
      if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
      if (a.sortOrder != b.sortOrder) {
        return a.sortOrder.compareTo(b.sortOrder);
      }
      return a.createdAt.compareTo(b.createdAt);
    });
    return items;
  }

  Future<String> addItem(LeisureItem item) async {
    final id = item.id.isEmpty ? _uuid.v4() : item.id;
    await _dbHelper.insert('leisure_items', item.copyWith(id: id).toMap());
    return id;
  }

  Future<void> updateItem(LeisureItem item) async {
    await _dbHelper.update('leisure_items', item.toMap(), 'id');
  }

  Future<void> deleteItem(String id) async {
    await _dbHelper.delete('leisure_items', 'id', id);
  }

  Future<void> toggleDone(String id) async {
    final maps = await _dbHelper.queryWhere(
      'leisure_items',
      (map) => map['id'] == id,
    );
    if (maps.isNotEmpty) {
      final item = LeisureItem.fromMap(maps.first);
      await updateItem(item.copyWith(isDone: !item.isDone));
    }
  }
}
