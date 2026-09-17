import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  /// 所有逻辑表。**加新表只需要改这一处**。
  ///
  /// 原先这份清单在文件里重复了 6 次（3 处完整 Map 字面量 + 2 处 `??=` 兜底
  /// + 1 处初始值），加一张表要同步改 5 个地方，漏任何一处新表就会在
  /// 「首次启动 / 无文件 / 备份损坏」某条路径下不存在。
  static const List<String> _tables = <String>[
    'tasks',
    'task_records',
    'plans',
    'daily_tasks',
    'weekly_goals',
    'sync_config',
  ];

  static Map<String, dynamic> _emptyData() => <String, dynamic>{
    for (final String table in _tables) table: <dynamic>[],
  };

  /// 补齐缺失的表。
  ///
  /// 读取旧版本写的文件、或导入旧备份时，新加的表在数据里不存在——
  /// 这里统一补成空列表，后续 `query` / `insert` 就不必各写各的兜底。
  static void _ensureTables(Map<String, dynamic> data) {
    for (final String table in _tables) {
      data[table] ??= <dynamic>[];
    }
  }

  Map<String, dynamic> _data = _emptyData();

  bool _initialized = false;
  Future<void>? _initFuture;

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      _initFuture ??= _loadData();
      await _initFuture;
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

  Future<File> get _backupFile async {
    final path = await _localPath;
    return File(p.join(path, 'time_way_pro_data.json.bak'));
  }

  Future<void> _loadData() async {
    try {
      final file = await _localFile;
      if (await file.exists()) {
        final contents = await file.readAsString();
        _data = jsonDecode(contents);
        _ensureTables(_data);
      }
    } catch (e) {
      print('Error loading data: $e');
      // 尝试从备份恢复
      try {
        final backupFile = await _backupFile;
        if (await backupFile.exists()) {
          final contents = await backupFile.readAsString();
          _data = jsonDecode(contents);
          _ensureTables(_data);
          print('Restored from backup');
        } else {
          _data = _emptyData();
        }
      } catch (e2) {
        print('Error loading backup: $e2');
        _data = _emptyData();
      }
    }
  }

  Future<void> _saveData() async {
    try {
      final file = await _localFile;
      final backupFile = await _backupFile;

      // 先备份当前文件
      if (await file.exists()) {
        await file.copy(backupFile.path);
      }

      // 写入新数据
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
    } else {
      print(
        'Warning: Record not found for update in $table with $idField=${record[idField]}',
      );
    }
  }

  Future<void> delete(String table, String idField, String id) async {
    await _ensureInitialized();
    final list = _data[table] as List? ?? [];
    list.removeWhere((r) => r[idField] == id);
    await _saveData();
  }

  Future<void> deleteWhere(String table, bool Function(dynamic) test) async {
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
    // 验证数据格式
    if (!data.containsKey('tasks') ||
        !data.containsKey('task_records') ||
        !data.containsKey('plans')) {
      throw Exception('Invalid data format: missing required fields');
    }

    if (data['tasks'] is! List ||
        data['task_records'] is! List ||
        data['plans'] is! List) {
      throw Exception('Invalid data format: fields must be lists');
    }

    _data = data;
    // 导入的是旧版本备份时，新加的表不在里面——补成空列表。
    // 原先这里直接赋值、不跑兜底，于是导入后新表的 key 是 null；
    // 访问器虽然都对 null 容错不会崩，但数据形状不一致。
    _ensureTables(_data);
    _initialized = true;
    await _saveData();
  }

  Future<void> close() async {
    // JSON存储不需要关闭连接
  }
}
