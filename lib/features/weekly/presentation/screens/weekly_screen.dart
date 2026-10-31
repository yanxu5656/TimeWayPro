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

  /// 刊头元信息行：`第 44 周 · 10/19 - 10/25 · VOL.359`
  /// （周号朱砂，期号衬线——把原先散落的期号/日期收拢成一行）
  Widget _buildMeta(String weekKey) {
    final DateTime monday = DateTime.parse(weekKey);
    return Text.rich(
      TextSpan(
        style: AppText.caption.copyWith(
          color: AppColors.textSecondary,
          letterSpacing: 0.4,
        ),
        children: <InlineSpan>[
          const TextSpan(text: '第 '),
          TextSpan(
            text: '${isoWeekNumber(monday)}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          TextSpan(text: ' 周 · ${weekRangeLabel(monday)} · '),
          TextSpan(
            text: 'VOL.${_volNumber(weekKey)}',
            style: AppText.serifNum.copyWith(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(WeeklyProvider provider) {
    final int daysLeft = 7 - DateTime.now().weekday; // 周日为 0
    final int remainingCount = provider.total - provider.completed;
    // 与设计稿一致用短式「还剩 2 条 · 2 天」——「距周末」三字会把
    // 390dp 下的分数行挤出 2.4px 溢出（golden 抓到过）
    final String remaining = remainingCount > 0 ? '还剩 $remainingCount 条' : '全部完成';
    final String daysPart =
        provider.isCurrentWeek && daysLeft > 0 ? ' · $daysLeft 天' : '';

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
            meta: _buildMeta(provider.selectedWeekKey),
            ghost:
                '${isoWeekNumber(provider.selectedWeekStart)}'.padLeft(2, '0'),
          ),

          // 周行：衬线的「本周」+ 英文大写日期（与眉题同一套编辑语言）
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
                            fontSize: 18,
                            color: provider.isCurrentWeek
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          weekRangeCaps(provider.selectedWeekStart),
                          style: AppText.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11.5,
                            letterSpacing: 1.6,
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

          // 大分数：64px 衬线数字是这一页的主角，右侧两行小注
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              CountUpText(
                value: provider.completed,
                format: (int v) => '$v',
                duration: const Duration(milliseconds: 450),
                style: AppText.serifNum.copyWith(
                  fontSize: 64,
                  color: AppColors.textPrimary,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  ' /${provider.total}',
                  style: AppText.serifNum.copyWith(
                    fontSize: 26,
                    color: AppColors.textHint,
                  ),
                ),
              ),
              const Spacer(),
              // 右侧两行小注：Flexible 让它在窄屏优雅截断而不是把
              // 分数行挤出溢出（320dp 实测溢出 19.8px，320dp 用例守护）
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      '$remaining$daysPart',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '完成度 ${(provider.progress * 100).round()}%',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(
                        color: AppColors.textSecondary,
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
          staged(
            SectionHeader(
              index: 1,
              title: '本周记事',
              trailing: '${provider.goals.length} 条',
            ),
          ),
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
        padding: const EdgeInsets.symmetric(vertical: 17),
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
