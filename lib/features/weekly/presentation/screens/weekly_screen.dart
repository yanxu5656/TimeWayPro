import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/ui/paper.dart';
import '../../../../core/utils/week.dart';
import '../../data/models/weekly_goal.dart';
import '../../providers/weekly_provider.dart';
import '../week_labels.dart';
import '../widgets/move_goal_sheet.dart';

/// 每周目标页（MainScreen 的第 1 个 Tab）——「周账本」。
///
/// 与待办页平行的「周」视角：刊头 + 衬线周行 + 大分数 + 编号账本行。
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
    return PaperScaffold(
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
      floatingActionButton: PaperFab(
        heroTag: 'weekly_fab',
        label: '添加目标',
        onPressed: () => _showEditSheet(context, null),
      ),
    );
  }

  /// 期号：2020-01-06 是周一，作为第 1 期的锚点。
  /// 编辑刊物的 VOL 编号，是个趣味性的栏目细节。
  /// utc 运算避免 DST 时区差一小时导致期号偏 1；下限钳到 1，
  /// 锚点之前的周（日期选择器已限到锚点，防御左箭头连点）不出 VOL.0
  int _volNumber(String weekKey) {
    final DateTime monday = DateTime.parse(weekKey);
    final int weeks = DateTime.utc(monday.year, monday.month, monday.day)
        .difference(DateTime.utc(2020, 1, 6))
        .inDays ~/ 7;
    return weeks < 0 ? 1 : weeks + 1;
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Masthead(
            kicker: 'WEEKLY LEDGER',
            title: '每周目标',
            trailing: Text('VOL.${_volNumber(provider.selectedWeekKey)}'),
          ),
          const SizedBox(height: AppSpacing.xs),

          // 周行：衬线的「本周」+ 日期区间，两侧箭头
          Row(
            children: <Widget>[
              PaperIconButton(
                icon: Icons.chevron_left_rounded,
                onTap: provider.previousWeek,
                color: AppColors.textSecondary,
                size: PaperIconButton.sizeChrome,
                iconSize: 22,
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectWeek(context, provider),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      children: <Widget>[
                        Text(
                          provider.isCurrentWeek
                              ? '本周'
                              : (weekShortLabel(provider.selectedWeekStart) ??
                                  ''),
                          style: AppText.titleSerif.copyWith(
                            color: provider.isCurrentWeek
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          weekRangeLabel(provider.selectedWeekStart),
                          style: AppText.caption.copyWith(
                            color: AppColors.textSecondary,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              PaperIconButton(
                icon: Icons.chevron_right_rounded,
                onTap: provider.nextWeek,
                color: AppColors.textSecondary,
                size: PaperIconButton.sizeChrome,
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
                padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                child: Text(
                  '回到本周',
                  style: AppText.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

          // 大分数：衬线数字是这一页的主角
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                '${_overviewTitle(provider)} · 已完成',
                style: AppText.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              CountUpText(
                value: provider.completed,
                format: (int v) => '$v',
                duration: const Duration(milliseconds: 450),
                style: AppText.serifNum.copyWith(
                  fontSize: 44,
                  color: AppColors.textPrimary,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  '/${provider.total}',
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
          for (final (int i, WeeklyGoal goal) in provider.goals.indexed)
            staged(_buildGoalRow(context, i, goal, provider)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(WeeklyProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(
            Icons.flag_outlined,
            size: 44,
            color: AppColors.textHint,
          ),
          const SizedBox(height: AppSpacing.md),
          const Text('暂无目标', style: AppText.titleSerif),
          const SizedBox(height: AppSpacing.xs),
          Text(
            provider.isCurrentWeek
                ? '点击下方按钮，记下这周想完成什么'
                : '这一周还没有目标，翻到其它周看看',
            style: AppText.caption.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  /// 账本行：两位序号（衬线）+ 勾选圆 + 标题（衬线）+ 挪周
  Widget _buildGoalRow(
    BuildContext context,
    int index,
    WeeklyGoal goal,
    WeeklyProvider provider,
  ) {
    final String no = (index + 1).toString().padLeft(2, '0');

    return Dismissible(
      key: Key(goal.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.textOnPrimary),
      ),
      confirmDismiss: (_) => _confirmDelete(context, goal),
      onDismissed: (_) => provider.deleteGoal(goal.id),
      child: PaperCard(
        tone: PaperTone.row,
        padding: const EdgeInsets.symmetric(vertical: 14),
        tint: goal.isCompleted ? AppColors.success : null,
        // 点击整行进编辑；勾选与挪周是行内的独立按钮
        onTap: () => _showEditSheet(context, goal),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 26,
              child: Text(
                no,
                style: AppText.serifNum.copyWith(
                  fontSize: 13,
                  color: goal.isCompleted
                      ? AppColors.primary
                      : AppColors.textHint,
                ),
              ),
            ),
            InkCheckCircle(
              isChecked: goal.isCompleted,
              onTap: () => provider.toggleGoal(goal.id),
              size: 21,
              semanticLabel: goal.title,
            ),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(
              child: Text(
                goal.title,
                style: AppText.bodySerif.copyWith(
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
      firstDate: DateTime(2020, 1, 6), // 期号锚点周一，往前的周没有 VOL 号
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
    showPaperSheet(
      context,
      showHandle: false,
      builder: (BuildContext sheetContext) => _WeeklyGoalSheet(
        initial: goal,
        onSubmit: (String title) {
          final WeeklyProvider provider = sheetContext.read<WeeklyProvider>();
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
        widget.initial?.weekKey ??
        context.read<WeeklyProvider>().selectedWeekKey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          isEditing ? '编辑目标' : '添加目标',
          style: AppText.titleSerif.copyWith(color: AppColors.textPrimary),
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
