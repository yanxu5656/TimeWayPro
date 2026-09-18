import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
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

  /// 读取本地数据文件。
  ///
  /// 三条路径，顺序不能变：
  /// 1. 正式文件存在 → 正常读
  /// 2. 正式文件**不存在**或读坏了 → 从 `.bak` 恢复
  /// 3. 两个都没有 → 确实是首次启动，用空表
  ///
  /// 第 2 条是本次新增的。原先只在**读取抛异常**时回退到备份，
  /// 正式文件不存在时不回退、`_data` 保持初始空表——也就是**静默地当作
  /// "没有数据"**。`_saveData` 改成原子写入后，它中间有一小段正式文件
  /// 不存在的窗口，所以这条回退是必需的。
  Future<void> _loadData() async {
    try {
      final File file = await _localFile;

      if (await file.exists()) {
        try {
          _data = jsonDecode(await file.readAsString());
          _ensureTables(_data);
          return;
        } catch (e) {
          print('Error loading data: $e');
          // 读坏了，落到下面走备份
        }
      } else {
        print('Data file missing, trying backup');
      }

      final File backupFile = await _backupFile;
      if (await backupFile.exists()) {
        try {
          _data = jsonDecode(await backupFile.readAsString());
          _ensureTables(_data);
          print('Restored from backup');
          return;
        } catch (e) {
          print('Error loading backup: $e');
        }
      }

      // 两份都没有或都坏了：确实是首次启动
      _data = _emptyData();
    } catch (e) {
      // 连路径都拿不到（比如 path_provider 不可用）
      print('Error loading data: $e');
      _data = _emptyData();
    }
  }

  Future<void> _saveData() async {
    try {
      final File file = await _localFile;
      final File backupFile = await _backupFile;
      final File tmpFile = File('${file.path}.tmp');

      // 1. 先写临时文件。flush: true 让它真正落盘，而不是停在 OS 缓存里。
      await tmpFile.writeAsString(jsonEncode(_data), flush: true);

      // 2. 把当前这份留作备份。
      //
      //    用 rename 而不是 copy：同一目录内的 rename 只改元数据、不复制
      //    数据体，于是「每次写入都全量复制一份备份」这个 O(文件大小) 的
      //    开销没有了，而备份频率与原先完全一致（每次写都更新）。
      //
      //    必须先删旧备份——Windows 上 rename 到已存在的路径会失败。
      if (await file.exists()) {
        if (await backupFile.exists()) {
          await backupFile.delete();
        }
        await file.rename(backupFile.path);
      }

      // 3. 原子替换正式文件。
      //
      //    走到这里，正式文件要么是旧内容、要么不存在；这一步之后要么是
      //    旧内容、要么是新内容，**永远不会是半截 JSON**。
      //    原先的 writeAsString 是直接覆盖，写到一半被杀进程就废了。
      await tmpFile.rename(file.path);
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

  /// 仅供测试：清空内存状态，让下一次访问重新从磁盘读。
  ///
  /// 这是个单例，`_initialized` 一旦为真就再也不会走 `_loadData()`。
  /// 要验证「从磁盘恢复」这类行为必须有办法把它打回未初始化。
  @visibleForTesting
  void resetForTesting() {
    _data = _emptyData();
    _initialized = false;
    _initFuture = null;
  }
}
