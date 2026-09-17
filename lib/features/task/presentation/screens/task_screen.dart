import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/ui/glass.dart';
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

  @override
  void initState() {
    super.initState();
    _loadDailyDurations();
  }

  Future<void> _loadDailyDurations() async {
    if (_isLoadingDurations) return;
    _isLoadingDurations = true;

    try {
      final provider = context.read<TaskProvider>();
      final durations = await provider.getAllTaskDailyDurations();
      if (mounted) {
        setState(() {
          _dailyDurations = durations;
        });
      }
    } catch (e) {
      debugPrint('Error loading daily durations: $e');
    } finally {
      _isLoadingDurations = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: '时途',
      // 刻意不跟底部导航的图标（check_circle）对齐：这一页的顶栏标题是
      // 应用名而不是「任务」，配时钟正好呼应「时途」
      titleIcon: Icons.access_time_rounded,
      actions: [
        GlassIconButton(
          icon: Icons.calendar_today_rounded,
          onTap: _selectDate,
          color: AppColors.textPrimary,
          size: 40,
          iconSize: 20,
          tooltip: '选择日期',
        ),
      ],
      body: Consumer<TaskProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary,
              ),
            );
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
      floatingActionButton: GlassFab(
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
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        children: [
          // 日期选择器
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildDateButton(
                  icon: Icons.chevron_left_rounded,
                  onTap: () {
                    setState(() {
                      _selectedDate = _selectedDate.subtract(
                        const Duration(days: 1),
                      );
                    });
                  },
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: _selectDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.primarySubtle,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isToday(_selectedDate)
                                ? Icons.today_rounded
                                : Icons.calendar_month_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isToday(_selectedDate)
                                ? '今天'
                                : DateFormat('MM月dd日').format(_selectedDate),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _getWeekday(_selectedDate),
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.primary.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _buildDateButton(
                  icon: Icons.chevron_right_rounded,
                  onTap: () {
                    setState(() {
                      _selectedDate = _selectedDate.add(
                        const Duration(days: 1),
                      );
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 统计卡片
          Row(
            children: [
              _buildStatCard(
                '全部任务',
                totalTasks,
                Icons.list_alt_rounded,
                AppColors.primary,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                '进行中',
                runningTasks,
                Icons.play_circle_outline_rounded,
                runningTasks > 0 ? AppColors.success : AppColors.textHint,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                '常驻任务',
                repeatableTasks,
                Icons.repeat_rounded,
                AppColors.info,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GlassIconButton(
      icon: icon,
      onTap: onTap,
      color: AppColors.textSecondary,
      size: 40,
      iconSize: 22,
    );
  }

  Widget _buildStatCard(String label, int value, IconData icon, Color color) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.sm,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            CountUpText(
              value: value,
              format: (v) => '$v',
              duration: const Duration(milliseconds: 450),
              style: AppText.numLg.copyWith(color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppText.labelSm.copyWith(
                color: AppColors.textSecondary,
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
              color: AppColors.primarySubtle,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.task_alt_rounded,
              size: 48,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '暂无任务',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击下方按钮添加新任务',
            style: TextStyle(fontSize: 14, color: AppColors.textHint),
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
      // 任务页是 MainScreen 里的第 1 个 Tab
      slotIndex: 1,
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
              _buildSectionTitle(
                '进行中',
                provider.activeTimers.length,
                AppColors.success,
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
              _buildSectionTitle(
                '常驻任务',
                repeatableTasks.length,
                AppColors.info,
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
              _buildSectionTitle(
                '待完成任务',
                oneTimeTasks.length,
                AppColors.warning,
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

  Widget _buildSectionTitle(String title, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
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
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.textOnPrimary,
              surface: AppColors.surface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
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

  void _completeTask(Task task) {
    final provider = context.read<TaskProvider>();
    provider.completeTask(task.id);

    // 重新加载每日时长
    _loadDailyDurations();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle,
              color: AppColors.textOnPrimary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(task.isRepeatable ? '完成次数 +1' : '任务已完成'),
          ],
        ),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _deleteTask(Task task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除任务'),
        content: Text('确定要删除「${task.title}」吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<TaskProvider>().deleteTask(task.id);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _startTask(Task task) {
    final provider = context.read<TaskProvider>();
    provider.startTimer(task.id);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.play_circle, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text('开始计时: ${task.title}'),
          ],
        ),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _stopTask(Task task) {
    final isCountUp = task.timerType == TimerType.countUp;
    final content = isCountUp
        ? '结束计时后时间将被记录，但任务不会自动完成。\n需要点击左侧圆圈才算完成。'
        : '倒计时结束后将自动标记为完成。';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('结束计时'),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<TaskProvider>().stopTimer(task.id);

              // 重新加载每日时长
              _loadDailyDurations();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.textOnPrimary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(isCountUp ? '时间已记录' : '任务已完成'),
                    ],
                  ),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('结束计时'),
          ),
        ],
      ),
    );
  }
}
