import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/ui/paper.dart';
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
    return PaperScaffold(
      body: Consumer<DailyProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              // 刊头 + 日期行 + 进度
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
      floatingActionButton: PaperFab(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Masthead(
            kicker: 'DAILY LIST',
            title: '每日待办',
            trailing: Text(DateFormat('yyyy/MM/dd').format(now)),
          ),
          const SizedBox(height: AppSpacing.xs),

          // 日期行：衬线日期 + 两侧箭头，今天用朱砂标注
          Row(
            children: [
              _buildDateButton(
                icon: Icons.chevron_left_rounded,
                onTap: provider.previousDay,
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectDate(context, provider),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isToday
                              ? '今天'
                              : DateFormat(
                                  'MM月dd日',
                                ).format(provider.selectedDate),
                          style: AppText.titleSerif.copyWith(
                            color: isToday
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          _getWeekday(provider.selectedDate),
                          style: AppText.caption.copyWith(
                            color: AppColors.textSecondary,
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

          // 进度：衬线大分数 + 细墨条
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '今日进度',
                style: AppText.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              // 数字滚动：分母是字符串拼接，只让分子动
              CountUpText(
                value: provider.completedTasks,
                format: (v) => '$v',
                duration: const Duration(milliseconds: 450),
                style: AppText.serifNum.copyWith(
                  fontSize: 40,
                  color: AppColors.textPrimary,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '/${provider.totalTasks}',
                  style: AppText.serifNum.copyWith(
                    fontSize: 20,
                    color: AppColors.textHint,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          LinearProgressIndicator(
            value: provider.progress,
            backgroundColor: AppColors.surfaceVariant,
            valueColor: AlwaysStoppedAnimation<Color>(
              provider.progress >= 1.0
                  ? AppColors.success
                  : AppColors.primary,
            ),
            minHeight: 3,
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
      color: AppColors.textSecondary,
      size: PaperIconButton.sizeChrome,
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
    // 编辑风的分组小标：字距拉开的墨色小字 + 细线，不再用彩色底块
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: AppText.label.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
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
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.textOnPrimary),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('删除待办'),
            content: Text('确定要删除「${task.title}」吗？'),
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
      // 账本行：透明底 + 下缘发丝线，完成的行左缘加朱砂着重线
      child: PaperCard(
        tone: PaperTone.row,
        padding: const EdgeInsets.symmetric(vertical: 14),
        tint: task.isCompleted ? AppColors.success : null,
        onTap: () => provider.toggleComplete(task.id),
        onLongPress: () => _showEditDialog(context, task, provider),
        child: Row(
          children: [
            // 完成按钮。与任务页共用 InkCheckCircle
            // （原先这里是 26px，任务页是 28px）
            InkCheckCircle(
              isChecked: task.isCompleted,
              onTap: () => provider.toggleComplete(task.id),
              semanticLabel: task.title,
            ),
            const SizedBox(width: 14),

            // 任务信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: AppText.bodySerif.copyWith(
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
                      style: AppText.caption.copyWith(
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
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xs),
                child: Text(
                  '已完成',
                  style: AppText.labelSm.copyWith(color: AppColors.success),
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
    showPaperSheet(context, builder: (context) => const _AddDailyTaskSheet());
  }

  void _showEditDialog(
    BuildContext context,
    DailyTask task,
    DailyProvider provider,
  ) {
    showPaperSheet(
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
    // 键盘避让 / SafeArea / 滚动 / 拖拽把手 / 玻璃底板均由 PaperSheet 提供
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
              PaperChip(
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
    // 键盘避让 / SafeArea / 滚动 / 拖拽把手 / 玻璃底板均由 PaperSheet 提供
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
              PaperChip(
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
