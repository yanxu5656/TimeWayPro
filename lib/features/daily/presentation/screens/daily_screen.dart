import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/ui/paper.dart';
import '../../../../core/utils/week.dart';
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
    final provider = context.read<DailyProvider>();
    Future.microtask(() {
      if (mounted) provider.loadTasks();
    });
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
            meta: Text.rich(
              TextSpan(
                style: AppText.caption.copyWith(
                  color: context.colors.textSecondary,
                  letterSpacing: 0.4,
                ),
                children: <InlineSpan>[
                  TextSpan(
                    text:
                        '${provider.selectedDate.year} 年 ${provider.selectedDate.month} 月 · ',
                  ),
                  const TextSpan(text: '第 '),
                  TextSpan(
                    text: '${isoWeekNumber(provider.selectedDate)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: context.colors.primary,
                    ),
                  ),
                  TextSpan(text: ' 周 · 共 '),
                  TextSpan(
                    text: '${provider.totalTasks}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: context.colors.primary,
                    ),
                  ),
                  const TextSpan(text: ' 条'),
                ],
              ),
            ),
            ghost: '${provider.selectedDate.day}'.padLeft(2, '0'),
          ),
          const SizedBox(height: AppSpacing.xs),

          // 日期行：衬线日期 + 两侧箭头，今天用陶土标注
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
                          style: context.text.titleSerif.copyWith(
                            color: isToday
                                ? context.colors.primary
                                : context.colors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          _getWeekday(provider.selectedDate),
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
                onTap: provider.nextDay,
              ),
            ],
          ),

          // 进度：48px 衬线大分数 + 右侧两行小注 + 陶土粗条
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              CountUpText(
                value: provider.completedTasks,
                format: (v) => '$v',
                duration: const Duration(milliseconds: 450),
                style: context.text.serifNum.copyWith(
                  fontSize: 48,
                  color: context.colors.textPrimary,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  ' /${provider.totalTasks}',
                  style: context.text.serifNum.copyWith(
                    fontSize: 22,
                    color: context.colors.textHint,
                  ),
                ),
              ),
              const Spacer(),
              // Flexible + 截断：与每周页同款防御（320dp 挤压时不溢出）
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      provider.totalTasks - provider.completedTasks > 0
                          ? '还剩 ${provider.totalTasks - provider.completedTasks} 条'
                          : '全部完成',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '完成度 ${(provider.progress * 100).round()}%',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          LinearProgressIndicator(
            value: provider.progress,
            backgroundColor: context.colors.surfaceVariant,
            valueColor: AlwaysStoppedAnimation<Color>(
              provider.progress >= 1.0
                  ? context.colors.success
                  : context.colors.primary,
            ),
            minHeight: 5,
            borderRadius: AppRadius.brFull,
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
              SectionHeader(
                index: 1,
                title: '上午',
                trailing: '${provider.morningTasks.length} 条',
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
              SectionHeader(
                index: 2,
                title: '下午',
                trailing: '${provider.afternoonTasks.length} 条',
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
              SectionHeader(
                index: 3,
                title: '晚上',
                trailing: '${provider.eveningTasks.length} 条',
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
              color: context.colors.primarySubtle,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.event_note_rounded,
              size: 48,
              color: context.colors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '暂无待办',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击下方按钮添加今日待办',
            style: TextStyle(fontSize: 14, color: context.colors.textHint),
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
        // 与卡片同一份下间距，否则滑动时红底会伸进卡间的空隙
        margin: const EdgeInsets.only(bottom: AppSpacing.cardGap),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: context.colors.error,
          borderRadius: BorderRadius.circular(context.shape.cardRadius),
        ),
        child: Icon(Icons.delete_outline, color: context.colors.textOnPrimary),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('删除待办'),
            content: Text('确定要删除「${task.title}」吗？'),
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
      },
      onDismissed: (direction) {
        runPaperAction(context, () => provider.deleteTask(task.id));
      },
      // 列表项卡：暖白底 + 两层暖阴影，完成的行整圈换 success 细描边
      child: PaperCard(
        tone: PaperTone.row,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.cardPad,
          vertical: 15,
        ),
        margin: const EdgeInsets.only(bottom: AppSpacing.cardGap),
        tint: task.isCompleted ? context.colors.success : null,
        onTap: () {
          runPaperAction(context, () => provider.toggleComplete(task.id));
        },
        onLongPress: () => _showEditDialog(context, task, provider),
        child: Row(
          children: [
            // 完成按钮。与任务页共用 InkCheckCircle
            // （原先这里是 26px，任务页是 28px）
            InkCheckCircle(
              isChecked: task.isCompleted,
              onTap: () {
                runPaperAction(context, () => provider.toggleComplete(task.id));
              },
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
                    style: context.text.bodySerif.copyWith(
                      color: task.isCompleted
                          ? context.colors.textHint
                          : context.colors.textPrimary,
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
                        color: context.colors.textHint,
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
                  style: AppText.labelSm.copyWith(
                    color: context.colors.success,
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
      lastDate: DateTime(DateTime.now().year + 10, 12, 31),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: context.colors.primary,
              onPrimary: context.colors.textOnPrimary,
              surface: context.colors.surface,
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
  bool _saving = false;

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
        Text(
          '添加待办',
          style: context.text.titleSerif.copyWith(
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 24),

        // 任务名称
        Text(
          '待办内容',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.colors.textSecondary,
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
        Text(
          '备注（可选）',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.colors.textSecondary,
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
        Text(
          '时间段',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.colors.textSecondary,
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
          child: PaperButton(
            onPressed: _saving ? null : _addTask,
            loading: _saving,
            loadingLabel: '正在添加',
            label: '添加',
          ),
        ),
      ],
    );
  }

  Future<void> _addTask() async {
    if (_saving || _titleController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final success = await runPaperAction(
      context,
      () => context.read<DailyProvider>().addTask(
        title: _titleController.text.trim(),
        description: _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
        timePeriod: _selectedPeriod,
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (success) Navigator.pop(context);
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
  bool _saving = false;

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
        Text(
          '编辑待办',
          style: context.text.titleSerif.copyWith(
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 24),

        // 任务名称
        Text(
          '待办内容',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.colors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(hintText: '输入待办内容'),
        ),
        const SizedBox(height: 20),

        // 备注
        Text(
          '备注（可选）',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.colors.textSecondary,
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
        Text(
          '时间段',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.colors.textSecondary,
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
          child: PaperButton(
            onPressed: _saving ? null : _saveTask,
            loading: _saving,
            loadingLabel: '正在保存',
            label: '保存',
          ),
        ),
      ],
    );
  }

  Future<void> _saveTask() async {
    if (_saving || _titleController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final success = await runPaperAction(
      context,
      () => context.read<DailyProvider>().updateTask(
        widget.task.copyWith(
          title: _titleController.text.trim(),
          description: _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
          timePeriod: _selectedPeriod,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (success) Navigator.pop(context);
  }
}
