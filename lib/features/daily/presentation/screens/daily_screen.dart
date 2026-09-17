import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/ui/glass.dart';
import '../../data/models/daily_task.dart';
import '../../providers/daily_provider.dart';

class DailyScreen extends StatefulWidget {
  const DailyScreen({super.key});

  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen> {
  @override
  void initState() {
    super.initState();
    // 延迟加载，避免在build期间调用
    Future.microtask(() => context.read<DailyProvider>().loadTasks());
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: '每日待办',
      titleIcon: Icons.today_rounded,
      body: Consumer<DailyProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              // 日期选择器和统计
              _buildHeader(provider),

              // 任务列表
              Expanded(
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildTaskList(provider),
              ),
            ],
          );
        },
      ),
      floatingActionButton: GlassFab(
        heroTag: 'daily_fab',
        label: '添加待办',
        onPressed: () => _showAddTaskDialog(context),
      ),
    );
  }

  Widget _buildHeader(DailyProvider provider) {
    final now = DateTime.now();
    final isToday =
        provider.selectedDate.year == now.year &&
        provider.selectedDate.month == now.month &&
        provider.selectedDate.day == now.day;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.xs,
        AppSpacing.screenH,
        AppSpacing.md,
      ),
      child: Column(
        children: [
          // 日期选择器
          GlassCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxs,
              vertical: AppSpacing.xxs,
            ),
            child: Row(
              children: [
                _buildDateButton(
                  icon: Icons.chevron_left_rounded,
                  onTap: provider.previousDay,
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectDate(context, provider),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isToday
                            ? AppColors.primarySubtle
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isToday
                                ? Icons.today_rounded
                                : Icons.calendar_month_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isToday
                                ? '今天'
                                : DateFormat(
                                    'MM月dd日',
                                  ).format(provider.selectedDate),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _getWeekday(provider.selectedDate),
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
                  onTap: provider.nextDay,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 进度条和统计
          GlassCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '今日进度',
                      style: AppText.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    // 数字滚动：分母是字符串拼接，只让分子动
                    CountUpText(
                      value: provider.completedTasks,
                      format: (v) => '$v/${provider.totalTasks}',
                      duration: const Duration(milliseconds: 450),
                      style: AppText.title.copyWith(color: AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: LinearProgressIndicator(
                    value: provider.progress,
                    backgroundColor: AppColors.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      provider.progress >= 1.0
                          ? AppColors.success
                          : AppColors.primary,
                    ),
                    minHeight: 8,
                  ),
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
    return GlassIconButton(
      icon: icon,
      onTap: onTap,
      color: AppColors.textSecondary,
      size: 40,
      iconSize: 22,
    );
  }

  Widget _buildTaskList(DailyProvider provider) {
    if (provider.tasks.isEmpty) {
      return _buildEmptyState();
    }

    // 错峰入场：三段待办拍平后统一编号，序号跨分组连续。
    // 注意 StaggeredEntrance 在第 maxItems 项之后直接返回 child，
    // 所以这里用 ListView(children:) 的 eager 构建不会产生多余的动画对象，
    // 无需为此改成 ListView.builder。
    var slot = 0;
    Widget staged(Widget child) =>
        StaggeredEntrance(index: slot++, child: child);

    return StaggerScope(
      // 每日待办是 MainScreen 里的第 0 个 Tab
      slotIndex: 0,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          0,
          AppSpacing.screenH,
          AppSpacing.navInset,
        ),
        children: [
          // 上午
          if (provider.morningTasks.isNotEmpty) ...[
            staged(
              _buildSectionTitle(
                '上午',
                Icons.wb_sunny_outlined,
                AppColors.warning,
              ),
            ),
            ...provider.morningTasks.map(
              (task) => staged(_buildTaskCard(task, provider)),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // 下午
          if (provider.afternoonTasks.isNotEmpty) ...[
            staged(
              _buildSectionTitle(
                '下午',
                Icons.wb_cloudy_outlined,
                AppColors.info,
              ),
            ),
            ...provider.afternoonTasks.map(
              (task) => staged(_buildTaskCard(task, provider)),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // 晚上
          if (provider.eveningTasks.isNotEmpty) ...[
            staged(
              _buildSectionTitle(
                '晚上',
                Icons.nights_stay_outlined,
                AppColors.primary,
              ),
            ),
            ...provider.eveningTasks.map(
              (task) => staged(_buildTaskCard(task, provider)),
            ),
          ],
        ],
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
              Icons.event_note_rounded,
              size: 48,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '暂无待办',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击下方按钮添加今日待办',
            style: TextStyle(fontSize: 14, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(DailyTask task, DailyProvider provider) {
    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.textOnPrimary),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('删除待办'),
            content: Text('确定要删除「${task.title}」吗？'),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('删除'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        provider.deleteTask(task.id);
      },
      child: GlassCard(
        // 含标题 + 备注两行文字，走 strong 档保对比度
        tone: GlassTone.strong,
        margin: const EdgeInsets.only(bottom: 10),
        tint: task.isCompleted ? AppColors.success : null,
        onTap: () => provider.toggleComplete(task.id),
        onLongPress: () => _showEditDialog(context, task, provider),
        child: Row(
          children: [
            // 完成按钮
            GestureDetector(
              onTap: () => provider.toggleComplete(task.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: task.isCompleted
                        ? AppColors.success
                        : AppColors.textHint.withValues(alpha: 0.5),
                    width: 2,
                  ),
                  color: task.isCompleted
                      ? AppColors.success
                      : Colors.transparent,
                ),
                child: task.isCompleted
                    ? const Icon(
                        Icons.check,
                        size: 16,
                        color: AppColors.textOnPrimary,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 14),

            // 任务信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: task.isCompleted
                          ? AppColors.textHint
                          : AppColors.textPrimary,
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  if (task.description != null &&
                      task.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      task.description!,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textHint,
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // 已完成标记
            if (task.isCompleted)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Text(
                  '已完成',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getWeekday(DateTime date) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return weekdays[date.weekday - 1];
  }

  Future<void> _selectDate(BuildContext context, DailyProvider provider) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: provider.selectedDate,
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
      provider.setDate(picked);
    }
  }

  void _showAddTaskDialog(BuildContext context) {
    showGlassSheet(context, builder: (context) => const _AddDailyTaskSheet());
  }

  void _showEditDialog(
    BuildContext context,
    DailyTask task,
    DailyProvider provider,
  ) {
    showGlassSheet(
      context,
      builder: (context) => _EditDailyTaskSheet(task: task),
    );
  }
}

class _AddDailyTaskSheet extends StatefulWidget {
  const _AddDailyTaskSheet();

  @override
  State<_AddDailyTaskSheet> createState() => _AddDailyTaskSheetState();
}

class _AddDailyTaskSheetState extends State<_AddDailyTaskSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  TimePeriod _selectedPeriod = _getCurrentPeriod();

  static TimePeriod _getCurrentPeriod() {
    final hour = DateTime.now().hour;
    if (hour < 12) return TimePeriod.morning;
    if (hour < 18) return TimePeriod.afternoon;
    return TimePeriod.evening;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 键盘避让 / SafeArea / 滚动 / 拖拽把手 / 玻璃底板均由 GlassSheet 提供
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '添加待办',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 24),

        // 任务名称
        const Text(
          '待办内容',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _titleController,
          autofocus: true,
          decoration: const InputDecoration(hintText: '输入待办内容'),
        ),
        const SizedBox(height: 20),

        // 备注
        const Text(
          '备注（可选）',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _descController,
          maxLines: 2,
          decoration: const InputDecoration(hintText: '输入备注'),
        ),
        const SizedBox(height: 20),

        // 时间段选择
        const Text(
          '时间段',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final period in TimePeriod.values) ...[
              GlassChip(
                label: switch (period) {
                  TimePeriod.morning => '上午',
                  TimePeriod.afternoon => '下午',
                  TimePeriod.evening => '晚上',
                },
                icon: switch (period) {
                  TimePeriod.morning => Icons.wb_sunny_outlined,
                  TimePeriod.afternoon => Icons.wb_cloudy_outlined,
                  TimePeriod.evening => Icons.nights_stay_outlined,
                },
                tint: switch (period) {
                  TimePeriod.morning => AppColors.warning,
                  TimePeriod.afternoon => AppColors.info,
                  TimePeriod.evening => AppColors.primary,
                },
                selected: _selectedPeriod == period,
                onTap: () => setState(() => _selectedPeriod = period),
                vertical: true,
              ),
              if (period != TimePeriod.evening)
                const SizedBox(width: AppSpacing.sm),
            ],
          ],
        ),
        const SizedBox(height: 30),

        // 添加按钮
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(onPressed: _addTask, child: const Text('添加')),
        ),
      ],
    );
  }

  void _addTask() {
    if (_titleController.text.trim().isEmpty) return;

    context.read<DailyProvider>().addTask(
      title: _titleController.text.trim(),
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      timePeriod: _selectedPeriod,
    );

    Navigator.pop(context);
  }
}

class _EditDailyTaskSheet extends StatefulWidget {
  final DailyTask task;

  const _EditDailyTaskSheet({required this.task});

  @override
  State<_EditDailyTaskSheet> createState() => _EditDailyTaskSheetState();
}

class _EditDailyTaskSheetState extends State<_EditDailyTaskSheet> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TimePeriod _selectedPeriod;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _descController = TextEditingController(
      text: widget.task.description ?? '',
    );
    _selectedPeriod = widget.task.timePeriod;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 键盘避让 / SafeArea / 滚动 / 拖拽把手 / 玻璃底板均由 GlassSheet 提供
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '编辑待办',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 24),

        // 任务名称
        const Text(
          '待办内容',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(hintText: '输入待办内容'),
        ),
        const SizedBox(height: 20),

        // 备注
        const Text(
          '备注（可选）',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _descController,
          maxLines: 2,
          decoration: const InputDecoration(hintText: '输入备注'),
        ),
        const SizedBox(height: 20),

        // 时间段选择
        const Text(
          '时间段',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final period in TimePeriod.values) ...[
              GlassChip(
                label: switch (period) {
                  TimePeriod.morning => '上午',
                  TimePeriod.afternoon => '下午',
                  TimePeriod.evening => '晚上',
                },
                icon: switch (period) {
                  TimePeriod.morning => Icons.wb_sunny_outlined,
                  TimePeriod.afternoon => Icons.wb_cloudy_outlined,
                  TimePeriod.evening => Icons.nights_stay_outlined,
                },
                tint: switch (period) {
                  TimePeriod.morning => AppColors.warning,
                  TimePeriod.afternoon => AppColors.info,
                  TimePeriod.evening => AppColors.primary,
                },
                selected: _selectedPeriod == period,
                onTap: () => setState(() => _selectedPeriod = period),
                vertical: true,
              ),
              if (period != TimePeriod.evening)
                const SizedBox(width: AppSpacing.sm),
            ],
          ],
        ),
        const SizedBox(height: 30),

        // 保存按钮
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(onPressed: _saveTask, child: const Text('保存')),
        ),
      ],
    );
  }

  void _saveTask() {
    if (_titleController.text.trim().isEmpty) return;

    context.read<DailyProvider>().updateTask(
      widget.task.copyWith(
        title: _titleController.text.trim(),
        description: _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
        timePeriod: _selectedPeriod,
      ),
    );

    Navigator.pop(context);
  }
}
