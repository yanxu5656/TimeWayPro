import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Map<String, dynamic> _data = {
    'tasks': [],
    'task_records': [],
    'plans': [],
    'sync_config': [],
  };

  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await _loadData();
      _initialized = true;
    }
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File(p.join(path, 'time_way_pro_data.json'));
  }

  Future<void> _loadData() async {
    try {
      final file = await _localFile;
      if (await file.exists()) {
        final contents = await file.readAsString();
        _data = jsonDecode(contents);
      }
    } catch (e) {
      print('Error loading data: $e');
      _data = {
        'tasks': [],
        'task_records': [],
        'plans': [],
        'sync_config': [],
      };
    }
  }

  Future<void> _saveData() async {
    try {
      final file = await _localFile;
      await file.writeAsString(jsonEncode(_data));
    } catch (e) {
      print('Error saving data: $e');
    }
  }

  // ==================== 通用查询方法 ====================

  Future<List<Map<String, dynamic>>> query(String table) async {
    await _ensureInitialized();
    return List<Map<String, dynamic>>.from(_data[table] ?? []);
  }

  Future<List<Map<String, dynamic>>> queryWhere(
    String table,
    bool Function(Map<String, dynamic>) test,
  ) async {
    await _ensureInitialized();
    final list = List<Map<String, dynamic>>.from(_data[table] ?? []);
    return list.where(test).toList();
  }

  Future<void> insert(String table, Map<String, dynamic> record) async {
    await _ensureInitialized();
    if (_data[table] == null) {
      _data[table] = [];
    }
    (_data[table] as List).add(record);
    await _saveData();
  }

  Future<void> update(
    String table,
    Map<String, dynamic> record,
    String idField,
  ) async {
    await _ensureInitialized();
    final list = _data[table] as List? ?? [];
    final index = list.indexWhere((r) => r[idField] == record[idField]);
    if (index != -1) {
      list[index] = record;
      await _saveData();
    }
  }

  Future<void> delete(String table, String idField, String id) async {
    await _ensureInitialized();
    final list = _data[table] as List? ?? [];
    list.removeWhere((r) => r[idField] == id);
    await _saveData();
  }

  Future<void> deleteWhere(
    String table,
    bool Function(dynamic) test,
  ) async {
    await _ensureInitialized();
    final list = _data[table] as List? ?? [];
    list.removeWhere(test);
    await _saveData();
  }

  // ==================== 导入导出 ====================

  Future<Map<String, dynamic>> exportAll() async {
    await _ensureInitialized();
    return Map<String, dynamic>.from(_data);
  }

  Future<void> importAll(Map<String, dynamic> data) async {
    _data = data;
    await _saveData();
  }

  Future<void> close() async {
    // JSON存储不需要关闭连接
  }
}
