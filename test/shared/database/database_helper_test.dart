import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_way_pro/shared/database/database_helper.dart';

/// `DatabaseHelper` 的写入原子性与加载回退测试。
///
/// ## 为什么用普通 `test()` 而不是 `testWidgets()`
///
/// 这个文件测的是**真实的文件读写**。`testWidgets` 跑在 FakeAsync 区里，
/// `dart:io` 的 Future 永远不完成，所有 `await` 都会挂住。普通 `test()`
/// 没有这层包装，真实 IO 正常推进——所以这里不用也不该用 `pumpXxx` 那一套。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  final DatabaseHelper db = DatabaseHelper();

  late File liveFile;
  late File backupFile;
  late File tmpFile;

  /// 一份形状合法的最小数据集
  Map<String, dynamic> dataset({List<Map<String, dynamic>> tasks = const []}) =>
      <String, dynamic>{
        'tasks': tasks,
        'task_records': <dynamic>[],
        'plans': <dynamic>[],
        'daily_tasks': <dynamic>[],
        'weekly_goals': <dynamic>[],
        'sync_config': <dynamic>[],
      };

  Map<String, dynamic> fakeTask(String id) => <String, dynamic>{
    'id': id,
    'title': '任务 $id',
    'timer_type': 0,
    'repeat_type': 0,
  };

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('twp_db_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall call) async => tempDir.path,
        );

    liveFile = File('${tempDir.path}/time_way_pro_data.json');
    backupFile = File('${liveFile.path}.bak');
    tmpFile = File('${liveFile.path}.tmp');

    db.resetForTesting();
  });

  tearDown(() {
    db.resetForTesting();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('写入后文件状态', () {
    test('正式文件是合法 JSON 且内容正确', () async {
      await db.importAll(dataset(tasks: <Map<String, dynamic>>[fakeTask('a')]));

      expect(liveFile.existsSync(), isTrue, reason: '正式文件应存在');
      final Map<String, dynamic> onDisk =
          jsonDecode(liveFile.readAsStringSync()) as Map<String, dynamic>;
      expect(onDisk['tasks'], hasLength(1));
      expect((onDisk['tasks'] as List).first['id'], 'a');
    });

    test('临时文件不残留（被 rename 掉了）', () async {
      await db.importAll(dataset(tasks: <Map<String, dynamic>>[fakeTask('a')]));

      expect(
        tmpFile.existsSync(),
        isFalse,
        reason: '.tmp 应该已经 rename 成正式文件，不该留下',
      );
    });

    test('首次写入不产生 .bak', () async {
      // 还没有正式文件时，没有"上一版"可备份
      await db.importAll(dataset(tasks: <Map<String, dynamic>>[fakeTask('a')]));

      expect(liveFile.existsSync(), isTrue);
      expect(backupFile.existsSync(), isFalse, reason: '第一次写入时没有旧版本，不该造出一个空备份');
    });
  });

  group('备份语义：每次写都留上一版', () {
    test('.bak 是上一次写入的内容，不是最新内容', () async {
      await db.importAll(dataset(tasks: <Map<String, dynamic>>[fakeTask('a')]));
      final String afterFirst = liveFile.readAsStringSync();

      // 再写一次
      final List<Map<String, dynamic>> all = await db.query('tasks');
      await db.insert('tasks', fakeTask('b'));

      // 正式文件有两条
      final Map<String, dynamic> live =
          jsonDecode(liveFile.readAsStringSync()) as Map<String, dynamic>;
      expect(live['tasks'], hasLength(2));

      // 备份是"上一次写入后"的状态，也就是只有一条
      expect(backupFile.existsSync(), isTrue, reason: '第二次写入后应有备份');
      final Map<String, dynamic> bak =
          jsonDecode(backupFile.readAsStringSync()) as Map<String, dynamic>;
      expect(bak['tasks'], hasLength(1));
      expect(
        backupFile.readAsStringSync(),
        afterFirst,
        reason: '.bak 应逐字等于上一次写入的内容',
      );

      expect(all, hasLength(1));
    });

    test('连续写三次，.bak 始终是前一版（不是最旧那版）', () async {
      await db.importAll(dataset(tasks: <Map<String, dynamic>>[fakeTask('a')]));
      await db.insert('tasks', fakeTask('b'));
      await db.insert('tasks', fakeTask('c'));

      final Map<String, dynamic> live =
          jsonDecode(liveFile.readAsStringSync()) as Map<String, dynamic>;
      final Map<String, dynamic> bak =
          jsonDecode(backupFile.readAsStringSync()) as Map<String, dynamic>;

      expect(live['tasks'], hasLength(3));
      expect(bak['tasks'], hasLength(2), reason: '.bak 应停在两版之前的状态');
    });
  });

  group('事务与故障回滚', () {
    void blockDocumentsDirectory() {
      final File blocker = File('${tempDir.path}/blocked');
      blocker.writeAsStringSync('not a directory');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (MethodCall call) async => blocker.path,
          );
    }

    test('导入校验拒绝缺失表和错误行形状且不覆盖现有数据', () async {
      await db.importAll(dataset(tasks: <Map<String, dynamic>>[fakeTask('a')]));

      await expectLater(
        db.importAll(<String, dynamic>{'tasks': <dynamic>[]}),
        throwsException,
      );
      await expectLater(
        db.importAll(<String, dynamic>{
          'tasks': <dynamic>[
            <String, dynamic>{'id': 'bad'},
          ],
          'task_records': <String, dynamic>{},
          'plans': <dynamic>[],
        }),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        db.importAll(<String, dynamic>{
          'tasks': <dynamic>['not an object'],
          'task_records': <dynamic>[],
          'plans': <dynamic>[],
        }),
        throwsA(isA<FormatException>()),
      );

      expect((await db.query('tasks')).single['id'], 'a');
      expect((await db.query('tasks')), hasLength(1));
    });

    test('写盘失败时增删改和导入都回滚内存并保留磁盘数据', () async {
      await db.importAll(dataset(tasks: <Map<String, dynamic>>[fakeTask('a')]));
      final String before = liveFile.readAsStringSync();
      blockDocumentsDirectory();

      await expectLater(
        db.insert('tasks', fakeTask('b')),
        throwsA(isA<FileSystemException>()),
      );
      await expectLater(
        db.update('tasks', <String, dynamic>{
          ...fakeTask('a'),
          'title': 'changed',
        }, 'id'),
        throwsA(isA<FileSystemException>()),
      );
      await expectLater(
        db.delete('tasks', 'id', 'a'),
        throwsA(isA<FileSystemException>()),
      );
      await expectLater(
        db.importAll(dataset(tasks: <Map<String, dynamic>>[fakeTask('new')])),
        throwsA(isA<FileSystemException>()),
      );

      expect((await db.query('tasks')).single['id'], 'a');
      expect(liveFile.readAsStringSync(), before);
    });

    test('前一次失败不会回滚队列中的后一次成功写入', () async {
      await db.importAll(dataset(tasks: <Map<String, dynamic>>[fakeTask('a')]));
      final File blocker = File('${tempDir.path}/blocked');
      blocker.writeAsStringSync('not a directory');
      int pathCalls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (MethodCall call) async =>
                pathCalls++ < 2 ? blocker.path : tempDir.path,
          );

      await expectLater(
        db.insert('tasks', fakeTask('b')),
        throwsA(isA<FileSystemException>()),
      );
      await db.insert('tasks', fakeTask('c'));

      expect(
        (await db.query('tasks')).map((row) => row['id']),
        orderedEquals(<String>['a', 'c']),
      );
      final Map<String, dynamic> onDisk =
          jsonDecode(liveFile.readAsStringSync()) as Map<String, dynamic>;
      expect(
        (onDisk['tasks'] as List).map((row) => row['id']),
        orderedEquals(<String>['a', 'c']),
      );
    });

    test('删除任务在一次事务中同时移除任务和关联记录', () async {
      await db.importAll(<String, dynamic>{
        'tasks': <Map<String, dynamic>>[fakeTask('a'), fakeTask('b')],
        'task_records': <Map<String, dynamic>>[
          <String, dynamic>{'id': 'r1', 'task_id': 'a'},
          <String, dynamic>{'id': 'r2', 'task_id': 'b'},
        ],
        'plans': <dynamic>[],
      });

      await db.deleteTaskCascade('a');

      expect(
        (await db.query('tasks')).map((row) => row['id']),
        orderedEquals(<String>['b']),
      );
      expect(
        (await db.query('task_records')).map((row) => row['id']),
        orderedEquals(<String>['r2']),
      );
      final Map<String, dynamic> onDisk =
          jsonDecode(liveFile.readAsStringSync()) as Map<String, dynamic>;
      expect((onDisk['task_records'] as List).single['id'], 'r2');
    });
  });

  group('加载回退', () {
    test('正式文件缺失但 .bak 在 → 从备份恢复', () async {
      await db.importAll(dataset(tasks: <Map<String, dynamic>>[fakeTask('a')]));
      await db.insert('tasks', fakeTask('b')); // 制造出 .bak

      // 模拟原子替换过程中崩在窗口里：正式文件没了，只剩备份
      liveFile.deleteSync();
      expect(backupFile.existsSync(), isTrue);

      db.resetForTesting();
      final List<Map<String, dynamic>> restored = await db.query('tasks');

      expect(restored, hasLength(1), reason: '应从 .bak 恢复出上一版');
      expect(restored.first['id'], 'a');
    });

    test('正式文件是坏 JSON 但 .bak 好 → 从备份恢复', () async {
      await db.importAll(dataset(tasks: <Map<String, dynamic>>[fakeTask('a')]));
      await db.insert('tasks', fakeTask('b'));

      // 模拟写到一半被杀进程：正式文件是半截 JSON
      liveFile.writeAsStringSync('{"tasks": [{"id": "a"');

      db.resetForTesting();
      final List<Map<String, dynamic>> restored = await db.query('tasks');

      expect(restored, hasLength(1));
      expect(restored.first['id'], 'a');
    });

    test('正式文件表结构损坏但 .bak 好 → 从备份恢复', () async {
      await db.importAll(dataset(tasks: <Map<String, dynamic>>[fakeTask('a')]));
      await db.insert('tasks', fakeTask('b'));
      liveFile.writeAsStringSync(
        jsonEncode(<String, dynamic>{
          'tasks': <Map<String, dynamic>>[fakeTask('broken')],
          'task_records': <String, dynamic>{},
          'plans': <dynamic>[],
        }),
      );

      db.resetForTesting();
      final List<Map<String, dynamic>> restored = await db.query('tasks');

      expect(restored, hasLength(1));
      expect(restored.first['id'], 'a');
    });

    test('两份都没有 → 空表且不抛（确实是首次启动）', () async {
      db.resetForTesting();
      final List<Map<String, dynamic>> tasks = await db.query('tasks');

      expect(tasks, isEmpty);
      expect((await db.exportAll()).containsKey('weekly_goals'), isTrue);
    });

    test('两份都坏了 → 退回空表且不抛', () async {
      liveFile.writeAsStringSync('not json at all');
      backupFile.writeAsStringSync('also not json');

      db.resetForTesting();
      final List<Map<String, dynamic>> tasks = await db.query('tasks');

      expect(tasks, isEmpty);
    });
  });

  group('写入的边界情况', () {
    test('临时文件不残留', () async {
      await db.importAll(dataset(tasks: <Map<String, dynamic>>[fakeTask('a')]));

      expect(tmpFile.existsSync(), isFalse, reason: '.tmp 应已 rename 成正式文件');
    });

    test('数据量较大时写出的文件仍是完整可解析的', () async {
      final List<Map<String, dynamic>> many = <Map<String, dynamic>>[
        for (int i = 0; i < 500; i++) fakeTask('t$i'),
      ];
      await db.importAll(dataset(tasks: many));

      final Map<String, dynamic> parsed =
          jsonDecode(liveFile.readAsStringSync()) as Map<String, dynamic>;
      expect(parsed['tasks'], hasLength(500));
    });
  });
}
