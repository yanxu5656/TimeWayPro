import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/ui/paper.dart';
import '../../../../core/utils/week.dart';
import '../../data/models/task.dart';
import '../../providers/task_provider.dart';
import '../widgets/task_card.dart';
import 'add_task_screen.dart';

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  DateTime _selectedDate = DateTime.now();
  Map<String, int> _dailyDurations = {};
  bool _isLoadingDurations = false;
  int _lastDataVersion = -1;

  /// 加载中又来了新请求时置位，等当前这次结束后补跑一次。
  /// 见 [_loadDailyDurations] 的说明。
  bool _pendingDurationReload = false;

  /// 卡片上那个时长的前缀。选中今天是「今日」，翻到别的日期是「当日」。
  String get _durationLabel => _isToday(_selectedDate) ? '今日' : '当日';

  @override
  void initState() {
    super.initState();
    _loadDailyDurations();
  }

  /// 换日期。三个入口（前一天 / 后一天 / 日期选择器）都走这里，
  /// 保证换日期的同时一定会重新拉那一天的时长——
  /// 原先三处都只 setState，所以标题变了、数字不变。
  void _changeDate(DateTime newDate) {
    if (newDate == _selectedDate) return;
    setState(() => _selectedDate = newDate);
    _loadDailyDurations();
  }

  Future<void> _loadDailyDurations() async {
    // 已经在加载中：**记下还需要再跑一次**，而不是直接丢弃请求。
    // 原先是 `if (_isLoadingDurations) return;`，快速连点日期箭头时
    // 后面的请求会被全部跳过，数字停在半路。
    if (_isLoadingDurations) {
      _pendingDurationReload = true;
      return;
    }
    _isLoadingDurations = true;
    final DateTime requestedDate = _selectedDate;

    try {
      final provider = context.read<TaskProvider>();
      // 传入选中的日期——「今天」不再写死在 provider 里
      final durations = await provider.getAllTaskDailyDurations(
        day: requestedDate,
      );
      if (mounted && requestedDate == _selectedDate) {
        setState(() {
          _dailyDurations = durations;
        });
      }
    } catch (e) {
      debugPrint('Error loading daily durations: $e');
    } finally {
      _isLoadingDurations = false;
      if (_pendingDurationReload && mounted) {
        _pendingDurationReload = false;
        _loadDailyDurations();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PaperScaffold(
      body: Consumer<TaskProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: context.colors.primary,
              ),
            );
          }

          if (_lastDataVersion != provider.dataVersion) {
            _lastDataVersion = provider.dataVersion;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _loadDailyDurations();
              }
            });
          }

          final activeTasks = provider.activeTasks;

          return Column(
            children: [
              _buildHeader(activeTasks, provider),
              Expanded(
                child: activeTasks.isEmpty
                    ? _buildEmptyState()
                    : _buildTaskList(activeTasks, provider),
              ),
            ],
          );
        },
      ),
      floatingActionButton: PaperFab(
        heroTag: 'task_fab',
        label: '新任务',
        onPressed: _addTask,
      ),
    );
  }

  Widget _buildHeader(List<Task> tasks, TaskProvider provider) {
    final totalTasks = tasks.length;
    final runningTasks = provider.activeTimers.length;
    final repeatableTasks = tasks.where((t) => t.isRepeatable).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.xs,
        AppSpacing.screenH,
        AppSpacing.md,
      ),
      child: Column(
        children: [
          // 刊头。标题用应用名「时途」：这一页是计时主场，
          // 刊头正好点题（原顶栏就是这么做的）
          Masthead(
            kicker: 'TIME WAY',
            title: '时途',
            meta: Text.rich(
              TextSpan(
                style: AppText.caption.copyWith(
                  color: context.colors.textSecondary,
                  letterSpacing: 0.4,
                ),
                children: <InlineSpan>[
                  TextSpan(
                    text: '${_selectedDate.year} 年 ${_selectedDate.month} 月 · ',
                  ),
                  const TextSpan(text: '第 '),
                  TextSpan(
                    text: '${isoWeekNumber(_selectedDate)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: context.colors.primary,
                    ),
                  ),
                  TextSpan(text: ' 周'),
                  if (provider.activeTimers.isNotEmpty) ...<InlineSpan>[
                    TextSpan(text: ' · 计时中 '),
                    TextSpan(
                      text: '${provider.activeTimers.length}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: context.colors.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ghost: '${_selectedDate.day}'.padLeft(2, '0'),
          ),
          const SizedBox(height: AppSpacing.xs),

          // 日期行：衬线日期 + 两侧箭头，今天用陶土标注
          Row(
            children: [
              _buildDateButton(
                icon: Icons.chevron_left_rounded,
                onTap: () => _changeDate(
                  DateTime(
                    _selectedDate.year,
                    _selectedDate.month,
                    _selectedDate.day - 1,
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: _selectDate,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isToday(_selectedDate)
                              ? '今天'
                              : DateFormat('MM月dd日').format(_selectedDate),
                          style: context.text.titleSerif.copyWith(
                            color: _isToday(_selectedDate)
                                ? context.colors.primary
                                : context.colors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          _getWeekday(_selectedDate),
                          style: AppText.caption.copyWith(
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _buildDateButton(
                icon: Icons.chevron_right_rounded,
                onTap: () => _changeDate(
                  DateTime(
                    _selectedDate.year,
                    _selectedDate.month,
                    _selectedDate.day + 1,
                  ),
                ),
              ),
            ],
          ),

          // 统计数字条：三栏衬线数字，竖发丝线分隔
          IntrinsicHeight(
            child: Row(
              children: [
                _buildStatColumn(
                  '全部任务',
                  totalTasks,
                  context.colors.textPrimary,
                ),
                const VerticalDivider(width: 1, thickness: 1),
                _buildStatColumn(
                  '进行中',
                  runningTasks,
                  runningTasks > 0
                      ? context.colors.success
                      : context.colors.textHint,
                ),
                const VerticalDivider(width: 1, thickness: 1),
                _buildStatColumn(
                  '常驻任务',
                  repeatableTasks,
                  context.colors.textPrimary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return PaperIconButton(
      icon: icon,
      onTap: onTap,
      color: context.colors.textSecondary,
      size: PaperIconButton.sizeChrome,
      iconSize: 22,
    );
  }

  Widget _buildStatColumn(String label, int value, Color color) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Column(
          children: [
            CountUpText(
              value: value,
              format: (v) => '$v',
              duration: const Duration(milliseconds: 450),
              style: context.text.serifNum.copyWith(fontSize: 30, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppText.labelSm.copyWith(
                color: context.colors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: context.colors.primarySubtle,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.task_alt_rounded,
              size: 48,
              color: context.colors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '暂无任务',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击下方按钮添加新任务',
            style: TextStyle(fontSize: 14, color: context.colors.textHint),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList(List<Task> tasks, TaskProvider provider) {
    final repeatableTasks = tasks.where((t) => t.isRepeatable).toList();
    final oneTimeTasks = tasks.where((t) => !t.isRepeatable).toList();

    // 获取所有任务（包括可能在计时中的任务）
    final allTasks = provider.tasks;

    // 错峰入场。StaggeredEntrance 在 maxItems(8) 之后直接返回 child，
    // 所以 eager 的 ListView(children:) 不会产生多余的动画对象——
    // builder 化只是滚动性能优化，与本轮动效无关。
    var slot = 0;
    Widget staged(Widget child) =>
        StaggeredEntrance(index: slot++, child: child);

    return StaggerScope(
      // 任务页是 MainScreen 里的第 2 个 Tab（待办、每周之后）
      slotIndex: 2,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          0,
          AppSpacing.screenH,
          AppSpacing.navInset,
        ),
        children: [
          // 进行中的任务
          if (provider.activeTimers.isNotEmpty) ...[
            staged(
              SectionHeader(
                index: 1,
                title: '进行中',
                trailing: '${provider.activeTimers.length} 项',
              ),
            ),
            ...provider.activeTimers.keys.map((taskId) {
              // 从所有任务中查找，而不是只从活跃任务中查找
              final task = allTasks.where((t) => t.id == taskId).firstOrNull;
              if (task == null) return const SizedBox.shrink();

              return staged(
                TaskCard(
                  task: task,
                  isRunning: true,
                  elapsedSeconds: provider.getTaskElapsedSeconds(taskId),
                  dailyDuration: _dailyDurations[taskId] ?? 0,
                  durationLabel: _durationLabel,
                  onComplete: () => _completeTask(task),
                  onEdit: () => _editTask(task),
                  onDelete: () => _deleteTask(task),
                  onStart: () => _stopTask(task),
                  onStop: () => _stopTask(task),
                ),
              );
            }),
            const SizedBox(height: 20),
          ],

          // 常驻任务
          if (repeatableTasks.isNotEmpty) ...[
            staged(
              SectionHeader(
                index: 2,
                title: '常驻任务',
                trailing: '${repeatableTasks.length} 项',
              ),
            ),
            ...repeatableTasks.map((task) {
              final isRunning = provider.isTaskRunning(task.id);
              return staged(
                TaskCard(
                  task: task,
                  isRunning: isRunning,
                  elapsedSeconds: provider.getTaskElapsedSeconds(task.id),
                  dailyDuration: _dailyDurations[task.id] ?? 0,
                  durationLabel: _durationLabel,
                  onComplete: () => _completeTask(task),
                  onEdit: () => _editTask(task),
                  onDelete: () => _deleteTask(task),
                  onStart: () => _startTask(task),
                  onStop: () => _stopTask(task),
                ),
              );
            }),
            const SizedBox(height: 20),
          ],

          // 待完成任务
          if (oneTimeTasks.isNotEmpty) ...[
            staged(
              SectionHeader(
                index: 3,
                title: '待完成任务',
                trailing: '${oneTimeTasks.length} 项',
              ),
            ),
            ...oneTimeTasks.map((task) {
              final isRunning = provider.isTaskRunning(task.id);
              return staged(
                TaskCard(
                  task: task,
                  isRunning: isRunning,
                  elapsedSeconds: provider.getTaskElapsedSeconds(task.id),
                  dailyDuration: _dailyDurations[task.id] ?? 0,
                  durationLabel: _durationLabel,
                  onComplete: () => _completeTask(task),
                  onEdit: () => _editTask(task),
                  onDelete: () => _deleteTask(task),
                  onStart: () => _startTask(task),
                  onStop: () => _stopTask(task),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  String _getWeekday(DateTime date) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return weekdays[date.weekday - 1];
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 10, 12, 31),
    );
    if (picked != null) {
      _changeDate(picked);
    }
  }

  void _addTask() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddTaskScreen()),
    ).then((_) => _loadDailyDurations());
  }

  void _editTask(Task task) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddTaskScreen(task: task)),
    ).then((_) => _loadDailyDurations());
  }

  void _showTaskError(String action, Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('$action失败：$error'),
          backgroundColor: context.colors.error,
        ),
      );
  }

  Future<void> _completeTask(Task task) async {
    final provider = context.read<TaskProvider>();
    try {
      await provider.completeTask(task.id);
      await _loadDailyDurations();
    } catch (e) {
      _showTaskError('完成任务', e);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: context.colors.textOnPrimary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(task.isRepeatable ? '完成次数 +1' : '任务已完成'),
            ],
          ),
          backgroundColor: context.colors.success,
        ),
      );
  }

  Future<void> _deleteTask(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => PaperAlertDialog(
        title: const Text('删除任务'),
        content: Text('确定要删除「${task.title}」吗？此操作不可撤销。'),
        actions: [
          PaperTextButton(
            onPressed: () => Navigator.pop(context, false),
            label: '取消',
          ),
          PaperTextButton(
            onPressed: () {
              AppHaptics.confirm();
              Navigator.pop(context, true);
            },
            color: context.colors.error,
            label: '删除',
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<TaskProvider>().deleteTask(task.id);
    } catch (e) {
      _showTaskError('删除任务', e);
    }
  }

  Future<void> _startTask(Task task) async {
    final provider = context.read<TaskProvider>();
    try {
      await provider.startTimer(task.id);
    } catch (e) {
      _showTaskError('开始计时', e);
      return;
    }
    if (!mounted || !provider.isTaskRunning(task.id)) return;

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.play_circle,
                color: context.colors.textOnPrimary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text('开始计时: ${task.title}'),
            ],
          ),
          backgroundColor: context.colors.primary,
        ),
      );
  }

  void _stopTask(Task task) {
    final isCountUp = task.timerType == TimerType.countUp;
    _stopTaskAndRefresh(task, isCountUp);
  }

  /// 结束计时 → **等 stopTimer 写完记录** → 再查当日时长。
  ///
  /// 原先 stopTimer 未 await 就 _loadDailyDurations：记录更新还挂在
  /// 微任务链上，时长查询先读了旧数据，本次会话不进「今日 X分钟」。
  Future<void> _stopTaskAndRefresh(Task task, bool isCountUp) async {
    try {
      await context.read<TaskProvider>().stopTimer(task.id);
      await _loadDailyDurations();
    } catch (e) {
      _showTaskError('结束计时', e);
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: context.colors.textOnPrimary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(isCountUp ? '时间已记录' : '任务已完成'),
              ],
            ),
            backgroundColor: context.colors.success,
          ),
        );
    }
  }
}
