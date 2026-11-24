import 'package:flutter_test/flutter_test.dart';
import 'package:time_way_pro/features/daily/data/models/daily_task.dart';
import 'package:time_way_pro/features/planning/data/models/plan.dart';
import 'package:time_way_pro/features/task/data/models/task.dart';
import 'package:time_way_pro/features/task/data/models/task_record.dart';
import 'package:time_way_pro/features/leisure/data/models/leisure_item.dart';
import 'package:time_way_pro/shared/services/notification_service.dart';

void main() {
  final DateTime now = DateTime.now();

  group('可空字段 copyWith', () {
    test('Task 可清空全部可空字段，省略参数时保留原值', () {
      final Task task = Task(
        id: 't',
        title: '任务',
        description: '描述',
        timerType: TimerType.countDown,
        duration: 300,
        dueDate: now,
        reminderMinutes: 15,
        repeatType: RepeatType.daily,
        completedCount: 2,
        lastCompletedDate: DateTime(now.year, now.month, now.day - 1),
        createdAt: now,
        updatedAt: now,
      );

      expect(task.needsDailyReset, isTrue);
      final Task preserved = task.copyWith(title: '改名');
      expect(preserved.description, '描述');
      expect(preserved.duration, 300);
      expect(preserved.dueDate, now);
      expect(preserved.reminderMinutes, 15);
      expect(preserved.lastCompletedDate, isNotNull);

      final Task cleared = task.copyWith(
        description: null,
        duration: null,
        dueDate: null,
        reminderMinutes: null,
        lastCompletedDate: null,
        isCompleted: false,
        completedCount: 0,
      );
      expect(cleared.description, isNull);
      expect(cleared.duration, isNull);
      expect(cleared.dueDate, isNull);
      expect(cleared.reminderMinutes, isNull);
      expect(cleared.lastCompletedDate, isNull);
      expect(cleared.needsDailyReset, isFalse);
    });

    test('TaskRecord 可清空结束时间和完成时间', () {
      final TaskRecord record = TaskRecord(
        id: 'r',
        taskId: 't',
        startTime: now,
        endTime: now,
        completedAt: now,
      );
      expect(record.copyWith(duration: 60).endTime, now);
      final TaskRecord cleared = record.copyWith(
        endTime: null,
        completedAt: null,
      );
      expect(cleared.endTime, isNull);
      expect(cleared.completedAt, isNull);
    });

    test('DailyTask 可清空描述并修正非法时间段', () {
      final DailyTask task = DailyTask(
        id: 'd',
        title: '待办',
        description: '描述',
        timePeriod: TimePeriod.afternoon,
        dateKey: '2026-11-24',
        createdAt: now,
      );
      expect(task.copyWith(title: '改名').description, '描述');
      expect(task.copyWith(description: null).description, isNull);

      final Map<String, dynamic> high = task.toMap()..['time_period'] = 99;
      final Map<String, dynamic> low = task.toMap()..['time_period'] = -1;
      expect(DailyTask.fromMap(high).timePeriod, TimePeriod.evening);
      expect(DailyTask.fromMap(low).timePeriod, TimePeriod.morning);
    });

    test('Plan 可清空描述和父级，导入进度始终有限且落在 0..1', () {
      final Plan plan = Plan(
        id: 'p',
        title: '规划',
        description: '描述',
        parentId: 'parent',
        progress: 0.5,
        createdAt: now,
        updatedAt: now,
      );
      expect(plan.copyWith(title: '改名').parentId, 'parent');
      final Plan cleared = plan.copyWith(description: null, parentId: null);
      expect(cleared.description, isNull);
      expect(cleared.parentId, isNull);

      expect(Plan.fromMap(plan.toMap()..['progress'] = 4).progress, 1);
      expect(Plan.fromMap(plan.toMap()..['progress'] = -1).progress, 0);
      expect(Plan.fromMap(plan.toMap()..['progress'] = double.nan).progress, 0);
      expect(
        Plan.fromMap(plan.toMap()..['progress'] = double.infinity).progress,
        0,
      );
      expect(Plan.fromMap(plan.toMap()..remove('progress')).progress, 0);
    });

    test('LeisureItem 可清空备注', () {
      final LeisureItem item = LeisureItem(
        id: 'l',
        title: '游戏',
        note: '备注',
        createdAt: now,
      );
      expect(item.copyWith(title: '新游戏').note, '备注');
      expect(item.copyWith(note: null).note, isNull);
    });

    test('Task 对非法枚举导入回退默认值而不是越界', () {
      final Task task = Task(
        id: 't',
        title: '任务',
        createdAt: now,
        updatedAt: now,
      );
      expect(
        Task.fromMap(task.toMap()..['timer_type'] = -1).timerType,
        TimerType.countUp,
      );
      expect(
        Task.fromMap(task.toMap()..['timer_type'] = 99).timerType,
        TimerType.countUp,
      );
      expect(
        Task.fromMap(task.toMap()..['repeat_type'] = -1).repeatType,
        RepeatType.none,
      );
      expect(
        Task.fromMap(task.toMap()..['repeat_type'] = 99).repeatType,
        RepeatType.none,
      );
    });
  });

  group('截止提醒时间', () {
    test('按截止日 09:00 减去所选提前量', () {
      final DateTime due = DateTime.now().add(const Duration(days: 3));
      final Task task = Task(
        id: 't',
        title: '任务',
        dueDate: due,
        reminderMinutes: 30,
        createdAt: now,
        updatedAt: now,
      );
      expect(
        NotificationService.taskReminderAt(task),
        DateTime(due.year, due.month, due.day, 8, 30),
      );
    });

    test('已完成、无截止日、无提醒和非法提前量不调度', () {
      final DateTime due = DateTime.now().add(const Duration(days: 3));
      Task task({DateTime? dueDate, int? reminder, bool completed = false}) =>
          Task(
            id: 't',
            title: '任务',
            dueDate: dueDate,
            reminderMinutes: reminder,
            isCompleted: completed,
            createdAt: now,
            updatedAt: now,
          );

      expect(
        NotificationService.taskReminderAt(
          task(completed: true, reminder: 15, dueDate: due),
        ),
        isNull,
      );
      expect(NotificationService.taskReminderAt(task(reminder: 15)), isNull);
      expect(NotificationService.taskReminderAt(task(dueDate: due)), isNull);
      expect(
        NotificationService.taskReminderAt(task(dueDate: due, reminder: -1)),
        isNull,
      );
    });

    test('同步时取消已删除任务的提醒且不影响计时通知', () {
      expect(
        NotificationService.staleTaskReminderIds(
          <int>[1001, 1002, 2000, 3000, 100001999, 100002000],
          <int>[3000],
        ),
        orderedEquals(<int>[2000, 100001999]),
      );
    });

    test('已经过去的提醒时间不补发', () {
      final Task task = Task(
        id: 't',
        title: '任务',
        dueDate: DateTime.now().subtract(const Duration(days: 1)),
        reminderMinutes: 0,
        createdAt: now,
        updatedAt: now,
      );
      expect(NotificationService.taskReminderAt(task), isNull);
    });
  });
}
