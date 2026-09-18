import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_way_pro/app/app.dart';
import 'package:time_way_pro/core/ui/glass.dart';
import 'package:time_way_pro/core/utils/week.dart';
import 'package:time_way_pro/shared/database/database_helper.dart';

/// widget 测试的共用脚手架。
///
/// ## 为什么要注入数据
///
/// 空数据下任务 / 统计 / 规划三页只会渲染 spinner，任何与内容相关的
/// 断言（列表避让、卡片布局）都会静默地什么都不检查。
///
/// ## 为什么必须在 pumpWidget 之前用 runAsync
///
/// `flutter_test` 跑在 FakeAsync 区里，**`dart:io` 的真实 Future 永远不会
/// 完成**——试过在 pumpWidget 之后再 `runAsync`，救不回来，因为 Future 是
/// 在 fake 区里创建的、无法追溯（会直接挂死）。
/// 所以必须在 `pumpWidget` **之前**把数据灌进 `DatabaseHelper` 单例；
/// 之后 provider 的读取只走内存缓存 + 微任务，而微任务在 FakeAsync 里正常推进。

/// 一份覆盖各页的最小种子数据
Map<String, dynamic> seedData() {
  final DateTime now = DateTime.now();
  final String nowIso = now.toIso8601String();
  final String today =
      '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> task(
    String id,
    String title, {
    int timerType = 0,
    int? duration,
    int repeatType = 0,
    int repeatCount = 1,
    bool completed = false,
    int completedCount = 0,
  }) => <String, dynamic>{
    'id': id,
    'title': title,
    'description': null,
    'timer_type': timerType,
    'duration': duration,
    'repeat_type': repeatType,
    'repeat_count': repeatCount,
    'due_date': null,
    'reminder_minutes': null,
    'is_completed': completed ? 1 : 0,
    'completed_count': completedCount,
    'last_completed_date': completedCount > 0 ? nowIso : null,
    'created_at': nowIso,
    'updated_at': nowIso,
  };

  Map<String, dynamic> record(
    String id,
    String taskId,
    int hour,
    int minutes,
  ) => <String, dynamic>{
    'id': id,
    'task_id': taskId,
    'start_time': DateTime(
      now.year,
      now.month,
      now.day,
      hour,
    ).toIso8601String(),
    'end_time': DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minutes,
    ).toIso8601String(),
    'duration': minutes * 60,
    'completed_at': DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minutes,
    ).toIso8601String(),
  };

  return <String, dynamic>{
    'tasks': <Map<String, dynamic>>[
      task('t1', '写周报'),
      task(
        't2',
        '冥想',
        timerType: 1,
        duration: 900,
        repeatType: 1,
        repeatCount: 2,
        completedCount: 1,
      ),
      task('t3', '读书', repeatType: 1, repeatCount: 3, completedCount: 2),
      task('t4', '整理书桌', completed: true, completedCount: 1),
    ],
    'task_records': <Map<String, dynamic>>[
      record('r1', 't1', 9, 80),
      record('r2', 't2', 8, 15),
      record('r3', 't3', 21, 45),
      // 昨天的一条，用来验证任务页翻日期时那个数字会跟着变。
      // 它不会出现在"今天"的视图里，所以不影响截图基线。
      <String, dynamic>{
        'id': 'r-yesterday',
        'task_id': 't1',
        'start_time': DateTime(
          now.year,
          now.month,
          now.day - 1,
          10,
        ).toIso8601String(),
        'end_time': DateTime(
          now.year,
          now.month,
          now.day - 1,
          10,
          37,
        ).toIso8601String(),
        // 故意用一个今天不存在的数值（今天是 80/15/45 分钟），
        // 否则断言可能因为数字撞车而在有 bug 时也通过——踩过这个坑
        'duration': 37 * 60,
        'completed_at': null,
      },
    ],
    'plans': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'p1',
        'title': '成为更好的工程师',
        'description': null,
        'parent_id': null,
        'progress': 0.45,
        'sort_order': 0,
        'created_at': nowIso,
        'updated_at': nowIso,
      },
      <String, dynamic>{
        'id': 'p2',
        'title': '读完 12 本技术书',
        'description': null,
        'parent_id': 'p1',
        'progress': 0.33,
        'sort_order': 0,
        'created_at': nowIso,
        'updated_at': nowIso,
      },
    ],
    'daily_tasks': <Map<String, dynamic>>[
      for (int i = 0; i < 3; i++)
        <String, dynamic>{
          'id': 'd$i',
          'title': '待办 $i',
          'description': null,
          'time_period': i,
          'is_completed': i == 0 ? 1 : 0,
          'date_key': today,
          'sort_order': 0,
          'created_at': nowIso,
        },
    ],
    'weekly_goals': <Map<String, dynamic>>[
      for (int i = 0; i < 3; i++)
        <String, dynamic>{
          'id': 'w$i',
          'title': '本周目标 $i',
          'is_completed': i == 0 ? 1 : 0,
          'week_key': weekKeyOf(now),
          'sort_order': i,
          'created_at': nowIso,
        },
      // 上一周的目标：用来验证「只显示本周」
      <String, dynamic>{
        'id': 'w-old',
        'title': '上周的目标（不该显示）',
        'is_completed': 0,
        'week_key': weekKeyOf(now.subtract(const Duration(days: 7))),
        'sort_order': 0,
        'created_at': nowIso,
      },
    ],
    'sync_config': <Map<String, dynamic>>[],
  };
}

/// 注入种子数据、调好视觉效果档位、设置画面尺寸，然后泵起 App。
///
/// 需要两次 `pump` 的理由：第一帧布局完成后 `MainScreen` 的 post-frame
/// 回调才量到导航栏高度，回填触发的重建在第二帧生效。
Future<void> pumpSeededApp(
  WidgetTester tester, {
  Size size = const Size(390, 900),
  bool seed = true,
}) async {
  UiEffects.resetForTesting();
  // reduced 而不是 minimal：保留真模糊，让布局与真机一致；
  // 极光靠 forceAnimated 之外的因素停住即可（这里 pump 不用 pumpAndSettle）。
  UiEffects.tier.value = UiEffectTier.reduced;

  // shared_preferences 必须 mock：TaskProvider._restoreActiveTimers 会
  // SharedPreferences.getInstance()，未 mock 时这个 Future 在 FakeAsync 里
  // 永不完成，isLoading 会一直卡在 true，页面就只剩一个 spinner。
  SharedPreferences.setMockInitialValues(<String, Object>{});

  // path_provider 也要 mock：DatabaseHelper 每次写入都会先
  // getApplicationDocumentsDirectory()。未 mock 时这一步直接抛
  // MissingPluginException（被 _saveData 吞掉），看似无害——但配合下面的
  // 真实 IO 说明就有问题了。
  _mockPathProvider();

  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  if (seed) {
    // 必须在 pumpWidget 之前，见文件头说明
    await tester.runAsync(() => DatabaseHelper().importAll(seedData()));
  }

  await tester.pumpWidget(const TimeWayProApp());
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Directory? _tempDir;

void _mockPathProvider() {
  _tempDir ??= Directory.systemTemp.createTempSync('timewaypro_test');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall call) async => _tempDir!.path,
      );
}

/// 让**真实的文件 IO** 有机会完成。
///
/// 触发了写入的交互（新建 / 编辑 / 删除）必须包在这个里面跑：`_saveData`
/// 会 File.writeAsString，而 `dart:io` 的真实 Future 在 FakeAsync 区里永不
/// 完成——不包的话 `insert` 不返回、provider 的 `loadTasks()` 永远不执行，
/// 表现为"操作了但列表没变"，而且测试会挂到超时。
///
/// 用法：
/// ```dart
/// await tapAndFlush(tester, find.text('添加'));
/// ```
Future<void> tapAndFlush(WidgetTester tester, Finder finder) async {
  await tester.runAsync(() async {
    await tester.tap(finder);
    // 让写入 + 随后的 loadTasks 走完
    await Future<void>.delayed(const Duration(milliseconds: 400));
  });
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// 切到指定 Tab 并等动画落定
Future<void> switchToTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}
