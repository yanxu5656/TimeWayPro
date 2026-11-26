import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_way_pro/features/focus/providers/focus_timer_provider.dart';
import 'package:time_way_pro/features/leisure/data/models/leisure_item.dart';
import 'package:time_way_pro/features/leisure/data/repositories/leisure_repository.dart';
import 'package:time_way_pro/features/leisure/providers/leisure_provider.dart';
import 'package:time_way_pro/features/planning/data/models/plan.dart';
import 'package:time_way_pro/features/planning/data/repositories/plan_repository.dart';
import 'package:time_way_pro/features/planning/providers/plan_provider.dart';
import 'package:time_way_pro/features/settings/models/sync_config.dart';
import 'package:time_way_pro/features/settings/providers/settings_provider.dart';
import 'package:time_way_pro/features/settings/repositories/sync_repository.dart';
import 'package:time_way_pro/features/task/data/models/task.dart';
import 'package:time_way_pro/features/task/data/models/task_record.dart';
import 'package:time_way_pro/features/task/data/repositories/task_repository.dart';
import 'package:time_way_pro/features/task/providers/task_provider.dart';
import 'package:time_way_pro/shared/database/database_helper.dart';
import 'package:time_way_pro/shared/services/notification_service.dart';

import 'support/app_harness.dart';

class _DeferredTaskRepository implements TaskRepository {
  final List<Completer<List<Task>>> requests = <Completer<List<Task>>>[];
  final Map<String, Completer<List<TaskRecord>>> recordRequests =
      <String, Completer<List<TaskRecord>>>{};

  @override
  Future<List<Task>> getAllTasks() {
    final Completer<List<Task>> request = Completer<List<Task>>();
    requests.add(request);
    return request.future;
  }

  @override
  Future<List<TaskRecord>> getRecordsByTaskId(String taskId) {
    final Completer<List<TaskRecord>> request = Completer<List<TaskRecord>>();
    recordRequests[taskId] = request;
    return request.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DeferredStartTaskRepository implements TaskRepository {
  final Completer<String> insert = Completer<String>();
  int deleteCalls = 0;

  @override
  Future<Task?> getTaskById(String id) async {
    final DateTime now = DateTime.now();
    return Task(id: id, title: id, createdAt: now, updatedAt: now);
  }

  @override
  Future<String> insertRecord(TaskRecord record) => insert.future;

  @override
  Future<void> deleteRecord(String id) async {
    deleteCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DeferredPlanRepository implements PlanRepository {
  final List<Completer<List<Plan>>> requests = <Completer<List<Plan>>>[];

  @override
  Future<List<Plan>> getAllPlans() {
    final Completer<List<Plan>> request = Completer<List<Plan>>();
    requests.add(request);
    return request.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DeferredLeisureRepository implements LeisureRepository {
  final List<Completer<List<LeisureItem>>> requests =
      <Completer<List<LeisureItem>>>[];

  @override
  Future<List<LeisureItem>> getAll() {
    final Completer<List<LeisureItem>> request = Completer<List<LeisureItem>>();
    requests.add(request);
    return request.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DeferredSyncRepository implements SyncRepository {
  final Completer<bool> connection = Completer<bool>();
  int connectionCalls = 0;
  int saveCalls = 0;

  @override
  Future<bool> testConnection(SyncConfig config) {
    connectionCalls++;
    return connection.future;
  }

  @override
  Future<void> saveSyncConfig(SyncConfig config) async {
    saveCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final DateTime now = DateTime.now();
  const MethodChannel notificationChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  const MethodChannel alarmChannel = MethodChannel(
    'com.timewaypro.time_way_pro/alarm',
  );

  void mockNotifications({bool cancelFails = false}) {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationChannel, (MethodCall call) async {
          if (call.method == 'initialize') return true;
          if (call.method == 'cancel' && cancelFails) {
            throw PlatformException(code: 'cancel_failed');
          }
          return null;
        });
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    installPathProviderMock();
    mockNotifications();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          alarmChannel,
          (MethodCall call) async => true,
        );
  });

  tearDown(() {
    NotificationService().stopPeriodicUpdate();
  });

  test('系统时间回拨不会产生负计时', () {
    final TimerState state = TimerState(
      taskId: 't1',
      recordId: 'r1',
      startTime: now.add(const Duration(hours: 1)),
    );
    expect(state.currentElapsedSeconds, 0);
  });

  test('任务乱序加载时旧结果不能覆盖新结果', () async {
    final _DeferredTaskRepository repository = _DeferredTaskRepository();
    final TaskProvider provider = TaskProvider(repository: repository);
    addTearDown(provider.dispose);
    Task task(String id) =>
        Task(id: id, title: id, createdAt: now, updatedAt: now);

    final Future<void> oldLoad = provider.loadTasks();
    final Future<void> newLoad = provider.loadTasks();
    repository.requests[1].complete(<Task>[task('new')]);
    await newLoad;
    repository.requests[0].complete(<Task>[task('old')]);
    await oldLoad;

    expect(provider.tasks.single.id, 'new');
    expect(provider.isLoading, isFalse);
  });

  test('任务记录乱序加载时旧任务结果不能覆盖新任务', () async {
    final _DeferredTaskRepository repository = _DeferredTaskRepository();
    final TaskProvider provider = TaskProvider(repository: repository);
    addTearDown(provider.dispose);
    TaskRecord record(String id) =>
        TaskRecord(id: id, taskId: id, startTime: now);

    final Future<void> oldLoad = provider.loadRecords('old');
    final Future<void> newLoad = provider.loadRecords('new');
    repository.recordRequests['new']!.complete(<TaskRecord>[record('new')]);
    await newLoad;
    repository.recordRequests['old']!.complete(<TaskRecord>[record('old')]);
    await oldLoad;

    expect(provider.records.single.id, 'new');
  });

  test('导入失败恢复会重新挂起原计时状态', () async {
    await DatabaseHelper().importAll(seedData());
    final TaskProvider provider = TaskProvider();
    addTearDown(provider.dispose);
    await provider.loadTasks();
    await provider.startTimer('t1');
    final List<TimerState> suspended = await provider
        .stopAllTimersForDataReset();
    expect(provider.activeTimers, isEmpty);

    await provider.restoreTimersAfterFailedDataReset(suspended);

    expect(provider.isTaskRunning('t1'), isTrue);
    expect(provider.activeTimers['t1']!.recordId, suspended.single.recordId);
    await provider.stopTimer('t1');
  });

  test('数据重置会取消仍在写入的任务计时记录', () async {
    final _DeferredStartTaskRepository repository =
        _DeferredStartTaskRepository();
    final TaskProvider provider = TaskProvider(repository: repository);
    addTearDown(provider.dispose);

    final Future<void> start = provider.startTimer('t1');
    await Future<void>.delayed(Duration.zero);
    await provider.stopAllTimersForDataReset();
    repository.insert.complete('orphan-record');
    await start;

    expect(repository.deleteCalls, 1);
    expect(provider.activeTimers, isEmpty);
  });

  test('通知取消平台异常不会中断任务停止', () async {
    mockNotifications(cancelFails: true);
    await DatabaseHelper().importAll(seedData());
    final TaskProvider provider = TaskProvider();
    addTearDown(provider.dispose);
    await provider.loadTasks();
    await provider.startTimer('t1');

    await provider.stopTimer('t1');

    expect(provider.activeTimers, isEmpty);
  });

  test('规划乱序加载时旧结果不能覆盖新结果', () async {
    final _DeferredPlanRepository repository = _DeferredPlanRepository();
    final PlanProvider provider = PlanProvider(repository: repository);
    addTearDown(provider.dispose);
    Plan plan(String id) =>
        Plan(id: id, title: id, createdAt: now, updatedAt: now);

    final Future<void> oldLoad = provider.loadPlans();
    final Future<void> newLoad = provider.loadPlans();
    repository.requests[1].complete(<Plan>[plan('new')]);
    await newLoad;
    repository.requests[0].complete(<Plan>[plan('old')]);
    await oldLoad;

    expect(provider.allPlans.single.id, 'new');
    expect(provider.isLoading, isFalse);
  });

  test('闲时乱序加载时旧结果不能覆盖新结果', () async {
    final _DeferredLeisureRepository repository = _DeferredLeisureRepository();
    final LeisureProvider provider = LeisureProvider(repository: repository);
    addTearDown(provider.dispose);
    LeisureItem item(String id) =>
        LeisureItem(id: id, title: id, createdAt: now);

    final Future<void> oldLoad = provider.loadItems();
    final Future<void> newLoad = provider.loadItems();
    repository.requests[1].complete(<LeisureItem>[item('new')]);
    await newLoad;
    repository.requests[0].complete(<LeisureItem>[item('old')]);
    await oldLoad;

    expect(provider.items.single.id, 'new');
    expect(provider.isLoading, isFalse);
  });

  test('云同步配置保存拒绝并发重入', () async {
    final _DeferredSyncRepository repository = _DeferredSyncRepository();
    final SettingsProvider provider = SettingsProvider(
      syncRepository: repository,
    );
    addTearDown(provider.dispose);
    final SyncConfig config = SyncConfig(
      webdavUrl: 'https://example.invalid',
      username: 'user',
      password: 'password',
    );

    final Future<bool> first = provider.saveSyncConfig(config);
    final Future<bool> second = provider.saveSyncConfig(config);
    expect(await second, isFalse);
    expect(repository.connectionCalls, 1);
    repository.connection.complete(true);

    expect(await first, isTrue);
    expect(repository.saveCalls, 1);
    expect(provider.isSyncing, isFalse);
  });

  test('专注恢复过期闹铃不会重放', () async {
    final List<String> calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(alarmChannel, (MethodCall call) async {
          calls.add(call.method);
          return true;
        });
    SharedPreferences.setMockInitialValues(<String, Object>{
      'focus_timer_state': jsonEncode(<String, dynamic>{
        'phase': FocusPhase.focusAlarm.index,
        'alarmAt': now.subtract(const Duration(minutes: 11)).toIso8601String(),
        'completedRounds': 1,
      }),
    });
    final FocusTimerProvider provider = FocusTimerProvider();
    addTearDown(provider.dispose);

    await provider.restoreState();

    expect(provider.phase, FocusPhase.idle);
    expect(calls, isNot(contains('startAlarm')));
    expect(calls, contains('stopAll'));
  });

  test('十分钟内的专注闹铃恢复只触发一次', () async {
    final List<String> calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(alarmChannel, (MethodCall call) async {
          calls.add(call.method);
          return true;
        });
    SharedPreferences.setMockInitialValues(<String, Object>{
      'focus_timer_state': jsonEncode(<String, dynamic>{
        'phase': FocusPhase.focusAlarm.index,
        'alarmAt': now.subtract(const Duration(minutes: 1)).toIso8601String(),
        'completedRounds': 1,
      }),
    });
    final FocusTimerProvider provider = FocusTimerProvider();
    addTearDown(provider.dispose);

    await provider.restoreState();
    await provider.syncWithClock();

    expect(provider.phase, FocusPhase.focusAlarm);
    expect(calls.where((String call) => call == 'startAlarm'), hasLength(1));
    expect(provider.completedRounds, 1);
  });

  test('闹铃落盘期间停止专注不会继续调用原生响铃', () async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Completer<SharedPreferences> alarmPersist =
        Completer<SharedPreferences>();
    int preferenceCalls = 0;
    DateTime clock = DateTime.now();
    final List<String> calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(alarmChannel, (MethodCall call) async {
          calls.add(call.method);
          return true;
        });
    final FocusTimerProvider provider = FocusTimerProvider(
      focusDurationSeconds: 1,
      clock: () => clock,
      preferences: () {
        preferenceCalls++;
        return preferenceCalls == 1
            ? Future<SharedPreferences>.value(prefs)
            : alarmPersist.future;
      },
    );
    addTearDown(provider.dispose);
    await provider.startFocus();
    clock = clock.add(const Duration(seconds: 2));

    final Future<void> trigger = provider.syncWithClock();
    await Future<void>.delayed(Duration.zero);
    final Future<void> stop = provider.stop();
    alarmPersist.complete(prefs);
    await Future.wait(<Future<void>>[trigger, stop]);

    expect(provider.phase, FocusPhase.idle);
    expect(calls, isNot(contains('startAlarm')));
    expect(calls, contains('stopAll'));
  });

  test('过期闹铃清理期间用户开始新专注不会被旧恢复停止', () async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'focus_timer_state',
      jsonEncode(<String, dynamic>{
        'phase': FocusPhase.focusAlarm.index,
        'alarmAt': now.subtract(const Duration(minutes: 11)).toIso8601String(),
        'completedRounds': 1,
      }),
    );
    final Completer<SharedPreferences> delayed = Completer<SharedPreferences>();
    int preferenceCalls = 0;
    final List<String> calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(alarmChannel, (MethodCall call) async {
          calls.add(call.method);
          return true;
        });
    final FocusTimerProvider provider = FocusTimerProvider(
      focusDurationSeconds: 120,
      preferences: () {
        preferenceCalls++;
        return preferenceCalls == 2 ? delayed.future : Future.value(prefs);
      },
    );
    addTearDown(provider.dispose);

    final Future<void> restore = provider.restoreState();
    await Future<void>.delayed(Duration.zero);
    await provider.startFocus();
    delayed.complete(prefs);
    await restore;

    expect(provider.phase, FocusPhase.focusing);
    expect(calls, <String>['startCountdown']);
    await provider.stop();
  });

  test('用户开始新专注后旧恢复结果不能覆盖', () async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'focus_timer_state',
      jsonEncode(<String, dynamic>{
        'phase': FocusPhase.focusAlarm.index,
        'alarmAt': now.toIso8601String(),
        'completedRounds': 3,
      }),
    );
    final Completer<SharedPreferences> delayed = Completer<SharedPreferences>();
    final FocusTimerProvider provider = FocusTimerProvider(
      focusDurationSeconds: 120,
      preferences: () => delayed.future,
    );
    addTearDown(provider.dispose);

    final Future<void> restore = provider.restoreState();
    final Future<void> start = provider.startFocus();
    await Future<void>.delayed(Duration.zero);
    delayed.complete(prefs);
    await Future.wait(<Future<void>>[restore, start]);

    expect(provider.phase, FocusPhase.focusing);
    expect(provider.completedRounds, 0);
    expect(provider.remainingSeconds, greaterThan(0));
    await provider.stop();
  });
}
