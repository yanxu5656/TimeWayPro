/// 带数据的真实 App 截图。
///
/// 空数据下 3 个 Tab 只会渲染 spinner，看不到任何布局。这个文件把种子数据
/// 直接灌进 DatabaseHelper 单例的内存缓存，让任务 / 统计 / 规划三页渲染出
/// 真实内容。
///
/// ## 关键坑：为什么必须用 runAsync 且必须在 pump 之前
///
/// `flutter_test` 跑在 FakeAsync 区里，**`dart:io` 的真实 Future 永远不会
/// 完成**（试过在 pumpWidget 之后再 runAsync，救不回来——Future 是在 fake
/// 区里创建的，无法追溯）。所以必须在 `pumpWidget` **之前**用 `runAsync`
/// 把数据灌进单例；之后 provider 的读取只走内存缓存 + 微任务，而微任务在
/// FakeAsync 里是正常推进的。
///
/// 需要时显式跑（文件名不以 _test.dart 结尾，不进默认 flutter test）：
///
///     flutter test test/golden/app_with_data.golden.dart --update-goldens
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_way_pro/app/app.dart';
import 'package:time_way_pro/core/ui/glass.dart';
import 'package:time_way_pro/shared/database/database_helper.dart';

String get _todayKey => DateFormat('yyyy-MM-dd').format(DateTime.now());

DateTime _todayAt(int hour, [int minute = 0]) {
  final DateTime now = DateTime.now();
  return DateTime(now.year, now.month, now.day, hour, minute);
}

/// 构造一份形状与 DatabaseHelper 一致的种子数据
Map<String, dynamic> _seed() {
  final DateTime now = DateTime.now();
  final String nowIso = now.toIso8601String();
  final String today = _todayKey;

  Map<String, dynamic> task(
    String id,
    String title, {
    String? desc,
    int timerType = 0,
    int? duration,
    int repeatType = 0,
    int repeatCount = 1,
    bool completed = false,
    int completedCount = 0,
  }) =>
      <String, dynamic>{
        'id': id,
        'title': title,
        'description': desc,
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
  ) =>
      <String, dynamic>{
        'id': id,
        'task_id': taskId,
        'start_time': _todayAt(hour).toIso8601String(),
        'end_time': _todayAt(hour, minutes).toIso8601String(),
        'duration': minutes * 60,
        'completed_at': _todayAt(hour, minutes).toIso8601String(),
      };

  return <String, dynamic>{
    'tasks': <Map<String, dynamic>>[
      task('t1', '写周报', desc: '总结本周进展'),
      task('t2', '冥想', timerType: 1, duration: 900, repeatType: 1, repeatCount: 2,
          completedCount: 1),
      task('t3', '读书', repeatType: 1, repeatCount: 3, completedCount: 2),
      task('t4', '整理书桌', completed: true, completedCount: 1),
    ],
    'task_records': <Map<String, dynamic>>[
      record('r1', 't1', 9, 80),
      record('r2', 't2', 8, 15),
      record('r3', 't3', 21, 45),
      record('r4', 't3', 13, 30),
      record('r5', 't4', 15, 20),
    ],
    'plans': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'p1',
        'title': '成为更好的工程师',
        'description': '长期目标',
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
      <String, dynamic>{
        'id': 'p3',
        'title': '每季度复盘一次',
        'description': null,
        'parent_id': 'p1',
        'progress': 1.0,
        'sort_order': 1,
        'created_at': nowIso,
        'updated_at': nowIso,
      },
    ],
    'daily_tasks': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'd1',
        'title': '晨会',
        'description': null,
        'time_period': 0,
        'is_completed': 1,
        'date_key': today,
        'sort_order': 0,
        'created_at': nowIso,
      },
      <String, dynamic>{
        'id': 'd2',
        'title': '给妈妈打电话',
        'description': '记得问体检结果',
        'time_period': 2,
        'is_completed': 0,
        'date_key': today,
        'sort_order': 0,
        'created_at': nowIso,
      },
      <String, dynamic>{
        'id': 'd3',
        'title': '取快递',
        'description': null,
        'time_period': 1,
        'is_completed': 0,
        'date_key': today,
        'sort_order': 0,
        'created_at': nowIso,
      },
    ],
    'sync_config': <Map<String, dynamic>>[],
  };
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('带数据时各 Tab 的真实渲染', (WidgetTester tester) async {
    UiEffects.resetForTesting();
    UiEffects.tier.value = UiEffectTier.reduced;

    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // 必须在 pumpWidget 之前：见文件头注释
    await tester.runAsync(() => DatabaseHelper().importAll(_seed()));

    await tester.pumpWidget(const TimeWayProApp());
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    const List<String> labels = <String>['待办', '任务', '统计', '规划', '设置'];
    for (int i = 0; i < labels.length; i++) {
      if (i > 0) {
        await tester.tap(find.text(labels[i]));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
      }
      await expectLater(
        find.byType(TimeWayProApp),
        matchesGoldenFile('goldens/data_$i.png'),
      );
    }

    expect(tester.takeException(), isNull);
  });
}
