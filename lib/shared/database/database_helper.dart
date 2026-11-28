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
    'leisure_items',
    'calendar_notes',
    'reward_products',
    'reward_inventory',
    'coin_transactions',
    'reward_meta',
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
      final dynamic rows = data[table];
      if (rows == null) {
        data[table] = <dynamic>[];
        continue;
      }
      if (rows is! List) {
        throw FormatException('表 $table 必须是数组');
      }
      if (rows.any((dynamic row) => row is! Map<String, dynamic>)) {
        throw FormatException('表 $table 的每一行必须是对象');
      }
    }
  }

  Map<String, dynamic> _data = _emptyData();

  bool _initialized = false;
  Future<void>? _initFuture;

  /// 写队列：把所有落盘操作串行化。
  ///
  /// `_saveData` 内部有多个 await（path_provider 通道、写临时文件、
  /// 两次 rename），两条写链一旦交错：共享同一个固定 `.tmp` 路径会撞
  /// Windows 的文件占用（errno 32）；更坏的序列是 A 把 tmp rename 走后
  /// B 的 rename 找不到 tmp 抛异常——被吞掉后正式文件处于缺失状态。
  /// 所有写入口都经由 [_enqueueMutation] 排队，一条链跑完才轮到下一条。
  Future<void> _writeQueue = Future<void>.value();

  /// 自增序号，让每次写入用独立的 tmp 文件，彻底消除共享路径
  int _writeSeq = 0;

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
          debugPrint('Error loading data: $e');
          // 读坏了，落到下面走备份
        }
      } else {
        debugPrint('Data file missing, trying backup');
      }

      final File backupFile = await _backupFile;
      if (await backupFile.exists()) {
        try {
          _data = jsonDecode(await backupFile.readAsString());
          _ensureTables(_data);
          debugPrint('Restored from backup');
          return;
        } catch (e) {
          debugPrint('Error loading backup: $e');
        }
      }

      // 两份都没有或都坏了：确实是首次启动
      _data = _emptyData();
    } catch (e) {
      // 连路径都拿不到（比如 path_provider 不可用）
      debugPrint('Error loading data: $e');
      _data = _emptyData();
    }
  }

  /// 把「修改内存 + 落盘」作为同一事务排进写队列。
  ///
  /// 快照在真正执行时创建，避免在队列等待期间把其它写入回滚掉。
  Future<void> _enqueueMutation(void Function() mutate) {
    final Future<void> task = _writeQueue.catchError((Object _) {}).then((
      _,
    ) async {
      await _ensureInitialized();
      final Map<String, dynamic> previousData = _data;
      _data = <String, dynamic>{
        for (final MapEntry<String, dynamic> entry in _data.entries)
          entry.key: entry.value is List
              ? List<dynamic>.from(entry.value)
              : entry.value,
      };
      try {
        mutate();
        await _doSave();
      } catch (_) {
        _data = previousData;
        rethrow;
      }
    });
    _writeQueue = task.then((_) {}, onError: (Object _) {});
    return task;
  }

  Future<T> transaction<T>(T Function(Map<String, dynamic> data) mutate) {
    final Future<T> task = _writeQueue.catchError((Object _) {}).then((
      _,
    ) async {
      await _ensureInitialized();
      final Map<String, dynamic> previousData = _data;
      _data = <String, dynamic>{
        for (final MapEntry<String, dynamic> entry in _data.entries)
          entry.key: entry.value is List
              ? List<dynamic>.from(entry.value)
              : entry.value,
      };
      try {
        final T result = mutate(_data);
        await _doSave();
        return result;
      } catch (_) {
        _data = previousData;
        rethrow;
      }
    });
    _writeQueue = task.then((_) {}, onError: (Object _) {});
    return task;
  }

  Future<void> _doSave() async {
    final File file = await _localFile;
    final File backupFile = await _backupFile;
    // 每次写入用独立的 tmp 路径：并发场景（理论上已被写队列排除）
    // 与上次失败残留的 tmp 都不会再互相干扰
    final File tmpFile = File('${file.path}.${_writeSeq++}.tmp');

    // 1. 先写临时文件。flush: true 让它真正落盘，而不是停在 OS 缓存里。
    await tmpFile.writeAsString(jsonEncode(_data), flush: true);

    // 2. 把当前这份留作备份。
    //
    //    用 rename 而不是 copy：同一目录内的 rename 只改元数据、不复制
    //    数据体。"每次写入都全量复制一份备份"的 O(文件大小) 开销没有。
    //
    //    必须先删旧备份——Windows 上 rename 到已存在的路径会失败。
    //    删失败（比如杀毒软件短暂占用）不致命：跳过本次备份更新。
    if (await file.exists()) {
      try {
        if (await backupFile.exists()) {
          await backupFile.delete();
        }
        await file.rename(backupFile.path);
      } catch (e) {
        debugPrint('Warning: skip backup rotation: $e');
      }
    }

    // 3. 原子替换正式文件。
    //
    //    走到这里，正式文件要么是旧内容、要么不存在；这一步之后要么是
    //    旧内容、要么是新内容，**永远不会是半截 JSON**。
    try {
      await _renameWithRetry(tmpFile, file.path);
    } catch (e) {
      // rename 彻底失败时清理 tmp，并尽可能把被移走的旧正式文件还原，
      // 避免磁盘上只剩备份、下一次冷启动被迫回退一个版本。
      try {
        await tmpFile.delete();
      } catch (_) {}
      if (!await file.exists() && await backupFile.exists()) {
        try {
          await _renameWithRetry(backupFile, file.path);
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// 带退避重试的 rename。
  ///
  /// Windows 上杀毒软件 / 搜索索引服务会短暂持有新写入文件的句柄，
  /// 让紧随其后的 rename 报「另一个程序正在使用此文件」（errno 32/5）。
  /// 这类占用是瞬时的（通常 <100ms），退避重试几次就能过去——
  /// 并行测试里多个 isolate 同时做大量小文件 IO 时尤其容易撞上。
  Future<void> _renameWithRetry(File from, String to) async {
    for (int attempt = 0; ; attempt++) {
      try {
        await from.rename(to);
        return;
      } catch (e) {
        if (attempt >= 2) rethrow;
        await Future<void>.delayed(
          Duration(milliseconds: 25 * (attempt + 1) * (attempt + 1)),
        );
      }
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
    await _enqueueMutation(() {
      final List<dynamic> list = _data[table] as List? ?? <dynamic>[];
      _data[table] = list;
      list.add(record);
    });
  }

  Future<void> update(
    String table,
    Map<String, dynamic> record,
    String idField,
  ) async {
    await _enqueueMutation(() {
      final list = _data[table] as List? ?? [];
      final index = list.indexWhere((r) => r[idField] == record[idField]);
      if (index != -1) {
        list[index] = record;
      } else {
        debugPrint(
          'Warning: Record not found for update in $table with '
          '$idField=${record[idField]}',
        );
      }
    });
  }

  /// 批量更新同一表的多行，**只落盘一次**。
  ///
  /// 拖拽排序要重写整周的 sort_order。逐行调 [update] 会排 N 次写队列，
  /// 每次都是一遍全量 JSON 编码 + 备份轮转 + 两次 rename——10 条目标
  /// 拖一下就是 10 次全库写盘。这里先在内存里改完，再排一次队。
  Future<void> updateAll(
    String table,
    List<Map<String, dynamic>> records,
    String idField,
  ) async {
    await _enqueueMutation(() {
      final list = _data[table] as List? ?? [];
      for (final Map<String, dynamic> record in records) {
        final index = list.indexWhere((r) => r[idField] == record[idField]);
        if (index != -1) {
          list[index] = record;
        }
      }
    });
  }

  Future<void> delete(String table, String idField, String id) async {
    await _enqueueMutation(() {
      final list = _data[table] as List? ?? [];
      list.removeWhere((r) => r[idField] == id);
    });
  }

  Future<void> deleteWhere(String table, bool Function(dynamic) test) async {
    await _enqueueMutation(() {
      final list = _data[table] as List? ?? [];
      list.removeWhere(test);
    });
  }

  Future<void> deleteTaskCascade(String taskId) async {
    await _enqueueMutation(() {
      final tasks = _data['tasks'] as List? ?? [];
      final records = _data['task_records'] as List? ?? [];
      tasks.removeWhere((dynamic row) => row['id'] == taskId);
      records.removeWhere((dynamic row) => row['task_id'] == taskId);
    });
  }

  // ==================== 导入导出 ====================

  Future<Map<String, dynamic>> exportAll() async {
    await _ensureInitialized();
    final out = Map<String, dynamic>.from(_data);
    // 凭据不随数据导出：备份会上传云端、导出文件可能被分享，
    // 密码（应用密码）只留在本地库里。恢复旧备份后需要重新输入。
    final syncTable = out['sync_config'];
    if (syncTable is List && syncTable.isNotEmpty) {
      out['sync_config'] = <dynamic>[
        for (final row in syncTable)
          if (row is Map<String, dynamic>)
            <String, dynamic>{...row}..remove('password')
          else
            row,
      ];
    }
    return out;
  }

  static void validateImportData(Map<String, dynamic> data) {
    if (!data.containsKey('tasks') ||
        !data.containsKey('task_records') ||
        !data.containsKey('plans')) {
      throw Exception('Invalid data format: missing required fields');
    }
    _ensureTables(Map<String, dynamic>.from(data));
  }

  Future<void> importAll(Map<String, dynamic> data) async {
    validateImportData(data);

    // 先等在途的磁盘读取落地再覆盖：冷启动后立刻导入时，_loadData
    // 完成后会把 _data 整体写回旧磁盘数据，导入被静默回滚。
    await _ensureInitialized();

    await _enqueueMutation(() {
      _data = Map<String, dynamic>.from(data);
      _ensureTables(_data);
    });
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
