import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/ui/glass.dart';
import '../../../../core/utils/week.dart';
import '../../data/models/weekly_goal.dart';
import '../../providers/weekly_provider.dart';
import '../week_labels.dart';
import '../widgets/move_goal_sheet.dart';

/// 每周目标页（MainScreen 的第 1 个 Tab）。
///
/// 与待办页平行的「周」视角：头部翻周 + 概览，列表是当前浏览周的目标。
/// 所有增删改都落在**浏览中的周**上——翻到下周添加就是提前规划，
/// 翻回旧周就是回看历史。
class WeeklyScreen extends StatefulWidget {
  const WeeklyScreen({super.key});

  @override
  State<WeeklyScreen> createState() => _WeeklyScreenState();
}

class _WeeklyScreenState extends State<WeeklyScreen> {
  @override
  void initState() {
    super.initState();
    // 延迟加载，避免在 build 期间调用（与其它 Tab 页一致）
    Future.microtask(() => context.read<WeeklyProvider>().loadGoals());
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: '每周目标',
      titleIcon: Icons.flag_rounded,
      body: Consumer<WeeklyProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              _buildHeader(provider),
              Expanded(
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildGoalList(provider),
              ),
            ],
          );
        },
      ),
      floatingActionButton: GlassFab(
        heroTag: 'weekly_fab',
        label: '添加目标',
        onPressed: () => _showEditSheet(context, null),
      ),
    );
  }

  Widget _buildHeader(WeeklyProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.xs,
        AppSpacing.screenH,
        AppSpacing.md,
      ),
      child: Column(
        children: <Widget>[
          // 周导航：结构照待办页的日期选择器，翻的单位换成周
          GlassCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxs,
              vertical: AppSpacing.xxs,
            ),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    GlassIconButton(
                      icon: Icons.chevron_left_rounded,
                      onTap: provider.previousWeek,
                      color: AppColors.textSecondary,
                      size: GlassIconButton.sizeChrome,
                      iconSize: 22,
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _selectWeek(context, provider),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: provider.isCurrentWeek
                                ? AppColors.primarySubtle
                                : Colors.transparent,
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Icon(
                                provider.isCurrentWeek
                                    ? Icons.today_rounded
                                    : Icons.calendar_month_rounded,
                                size: 18,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                provider.isCurrentWeek
                                    ? '本周'
                                    : weekRangeLabel(provider.selectedWeekStart),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    GlassIconButton(
                      icon: Icons.chevron_right_rounded,
                      onTap: provider.nextWeek,
                      color: AppColors.textSecondary,
                      size: GlassIconButton.sizeChrome,
                      iconSize: 22,
                    ),
                  ],
                ),
                // 翻走之后给一条显式的归位路径，省得连点箭头回去
                if (!provider.isCurrentWeek)
                  GestureDetector(
                    onTap: provider.goToCurrentWeek,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        bottom: AppSpacing.xxs,
                      ),
                      child: Text(
                        '回到本周',
                        style: AppText.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // 概览：进度条 + 数字滚动，视觉沿用原「本周目标」卡
          GlassCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      _overviewTitle(provider),
                      style: AppText.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    // 数字滚动：分母是字符串拼接，只让分子动
                    CountUpText(
                      value: provider.completed,
                      format: (int v) => '$v/${provider.total}',
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

  String _overviewTitle(WeeklyProvider provider) {
    final String? short = weekShortLabel(provider.selectedWeekStart);
    if (short != null) return '$short目标';
    return '${weekRangeLabel(provider.selectedWeekStart)} 的目标';
  }

  Widget _buildGoalList(WeeklyProvider provider) {
    if (provider.goals.isEmpty) {
      return _buildEmptyState(provider);
    }

    // 错峰入场：与待办页同一套写法（StaggeredEntrance 在上限之后
    // 直接返回 child，eager 构建不产生多余动画对象）
    var slot = 0;
    Widget staged(Widget child) =>
        StaggeredEntrance(index: slot++, child: child);

    return StaggerScope(
      // 每周页是 MainScreen 里的第 1 个 Tab
      slotIndex: 1,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          0,
          AppSpacing.screenH,
          AppSpacing.navInset,
        ),
        children: <Widget>[
          for (final WeeklyGoal goal in provider.goals)
            staged(_buildGoalCard(context, goal, provider)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(WeeklyProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: const BoxDecoration(
              color: AppColors.primarySubtle,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.flag_outlined,
              size: 48,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            '暂无目标',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            provider.isCurrentWeek
                ? '点击下方按钮，记下这周想完成什么'
                : '这一周还没有目标，翻到其它周看看',
            style: AppText.caption.copyWith(color: AppColors.textHint),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(
    BuildContext context,
    WeeklyGoal goal,
    WeeklyProvider provider,
  ) {
    return Dismissible(
      key: Key(goal.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.textOnPrimary),
      ),
      confirmDismiss: (_) => _confirmDelete(context, goal),
      onDismissed: (_) => provider.deleteGoal(goal.id),
      child: GlassCard(
        margin: const EdgeInsets.only(bottom: 10),
        // 点击整行进编辑；勾选与挪周是行内的独立按钮
        onTap: () => _showEditSheet(context, goal),
        child: Row(
          children: <Widget>[
            GlassCheckCircle(
              isChecked: goal.isCompleted,
              onTap: () => provider.toggleGoal(goal.id),
              size: 22,
              semanticLabel: goal.title,
            ),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(
              child: Text(
                goal.title,
                style: AppText.taskTitle.copyWith(
                  color: goal.isCompleted
                      ? AppColors.textHint
                      : AppColors.textPrimary,
                  decoration: goal.isCompleted
                      ? TextDecoration.lineThrough
                      : null,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            _buildMoveButton(context, goal),
          ],
        ),
      ),
    );
  }

  Widget _buildMoveButton(BuildContext context, WeeklyGoal goal) {
    return GestureDetector(
      onTap: () => showMoveGoalSheet(context, goal),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Semantics(
          button: true,
          label: '挪到其他周',
          child: const Icon(
            Icons.event_repeat_outlined,
            size: 20,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, WeeklyGoal goal) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('删除目标'),
        content: Text('确定要删除「${goal.title}」吗？'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _selectWeek(
    BuildContext context,
    WeeklyProvider provider,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: provider.selectedWeekStart,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (BuildContext context, Widget? child) {
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
    // 选周内任意一天都会归一到周一
    if (picked != null) {
      provider.selectWeek(picked);
    }
  }

  /// [goal] 为 null 时是新增
  void _showEditSheet(BuildContext context, WeeklyGoal? goal) {
    showGlassSheet(
      context,
      showHandle: false,
      builder: (BuildContext sheetContext) => _WeeklyGoalSheet(
        initial: goal,
        onSubmit: (String title) {
          final WeeklyProvider provider =
              sheetContext.read<WeeklyProvider>();
          if (goal == null) {
            provider.addGoal(title);
          } else {
            provider.updateGoal(goal.copyWith(title: title));
          }
          Navigator.pop(sheetContext);
        },
      ),
    );
  }
}

/// 新增 / 编辑目标的表单。只有一个输入框，所以不带拖拽把手
/// （沿用待办页添加弹窗的既有取舍）。
class _WeeklyGoalSheet extends StatefulWidget {
  const _WeeklyGoalSheet({required this.initial, required this.onSubmit});

  final WeeklyGoal? initial;
  final ValueChanged<String> onSubmit;

  @override
  State<_WeeklyGoalSheet> createState() => _WeeklyGoalSheetState();
}

class _WeeklyGoalSheetState extends State<_WeeklyGoalSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial?.title ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.initial != null;
    // 新增落在当前浏览的周；编辑显示目标所在周（挪周走行尾按钮）
    final String weekKey =
        widget.initial?.weekKey ?? context.read<WeeklyProvider>().selectedWeekKey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          isEditing ? '编辑目标' : '添加目标',
          style: AppText.h3.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: const InputDecoration(hintText: '这周想完成什么'),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            const Icon(
              Icons.event_outlined,
              size: 14,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              '${isEditing ? '所在周' : '将添加到'}：${_weekHint(weekKey)}',
              style: AppText.caption.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submit,
            child: Text(isEditing ? '保存' : '添加'),
          ),
        ),
      ],
    );
  }

  /// 「本周（10/20 - 10/26）」；更远的周只有日期区间
  String _weekHint(String weekKey) {
    final DateTime monday = DateTime.parse(weekKey);
    final String? short = weekShortLabel(monday);
    final String range = weekRangeLabel(monday);
    return short != null ? '$short（$range）' : range;
  }

  void _submit() {
    final String title = _controller.text.trim();
    if (title.isEmpty) return;
    widget.onSubmit(title);
  }
}
