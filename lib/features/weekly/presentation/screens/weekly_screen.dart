import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

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
    final provider = context.read<WeeklyProvider>();
    Future.microtask(() {
      if (mounted) provider.loadGoals();
    });
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
    final int weeks =
        DateTime.utc(
          monday.year,
          monday.month,
          monday.day,
        ).difference(DateTime.utc(2020, 1, 6)).inDays ~/
        7;
    return weeks < 0 ? 1 : weeks + 1;
  }

  /// 刊头元信息行：`第 44 周 · 10/19 - 10/25 · VOL.359`
  /// （周号陶土，期号衬线——把原先散落的期号/日期收拢成一行）
  Widget _buildMeta(String weekKey) {
    final DateTime monday = DateTime.parse(weekKey);
    return Text.rich(
      TextSpan(
        style: AppText.caption.copyWith(
          color: context.colors.textSecondary,
          letterSpacing: 0.4,
        ),
        children: <InlineSpan>[
          const TextSpan(text: '第 '),
          TextSpan(
            text: '${isoWeekNumber(monday)}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: context.colors.primary,
            ),
          ),
          TextSpan(text: ' 周 · ${weekRangeLabel(monday)} · '),
          TextSpan(
            text: 'VOL.${_volNumber(weekKey)}',
            style: context.text.serifNum.copyWith(
              fontSize: 12.5,
              color: context.colors.textSecondary,
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
    final String remaining = remainingCount > 0
        ? '还剩 $remainingCount 条'
        : '全部完成';
    final String daysPart = provider.isCurrentWeek && daysLeft > 0
        ? ' · $daysLeft 天'
        : '';

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
            ghost: '${isoWeekNumber(provider.selectedWeekStart)}'.padLeft(
              2,
              '0',
            ),
          ),

          // 周行：衬线的「本周」+ 英文大写日期（与眉题同一套编辑语言）
          Row(
            children: <Widget>[
              PaperIconButton(
                icon: Icons.chevron_left_rounded,
                onTap: provider.previousWeek,
                color: context.colors.textSecondary,
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
                          style: context.text.titleSerif.copyWith(
                            fontSize: 18,
                            color: provider.isCurrentWeek
                                ? context.colors.primary
                                : context.colors.textPrimary,
                          ),
                        ),
                        Text(
                          weekRangeCaps(provider.selectedWeekStart),
                          style: AppText.caption.copyWith(
                            color: context.colors.textSecondary,
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
                color: context.colors.textSecondary,
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
                    color: context.colors.primary,
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
                style: context.text.serifNum.copyWith(
                  fontSize: 64,
                  color: context.colors.textPrimary,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  ' /${provider.total}',
                  style: context.text.serifNum.copyWith(
                    fontSize: 26,
                    color: context.colors.textHint,
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

  Widget _buildGoalList(WeeklyProvider provider) {
    if (provider.goals.isEmpty) {
      return _buildEmptyState(provider);
    }

    return StaggerScope(
      // 每周页是 MainScreen 里的第 1 个 Tab
      slotIndex: 1,
      child: ReorderableListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          0,
          AppSpacing.screenH,
          AppSpacing.navInset,
        ),
        // 分区标题不参与排序，onReorderItem 的下标不含它
        header: StaggeredEntrance(
          index: 0,
          child: SectionHeader(
            index: 1,
            title: '本周记事',
            trailing: '${provider.goals.length} 条',
          ),
        ),
        // 排序只走行尾的显式把手，见 _buildDragHandle
        buildDefaultDragHandles: false,
        itemCount: provider.goals.length,
        // onReorderItem 给的已经是「移除后」的落点，不用再自己减 1
        onReorderItem: (int oldIndex, int newIndex) {
          runPaperAction(
            context,
            () => provider.reorderGoals(oldIndex, newIndex),
          );
        },
        // 错峰入场的序号直接用列表下标：builder 是懒构建，累加计数器
        // 会随构建顺序漂移，拿不到稳定的视觉次序
        itemBuilder: (BuildContext context, int i) {
          final WeeklyGoal goal = provider.goals[i];
          return StaggeredEntrance(
            key: ValueKey<String>(goal.id),
            index: i + 1,
            child: _buildGoalRow(context, i, goal, provider),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(WeeklyProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.flag_outlined, size: 44, color: context.colors.textHint),
          const SizedBox(height: AppSpacing.md),
          Text('暂无目标', style: context.text.titleSerif),
          const SizedBox(height: AppSpacing.xs),
          Text(
            provider.isCurrentWeek ? '点击下方按钮，记下这周想完成什么' : '这一周还没有目标，翻到其它周看看',
            style: AppText.caption.copyWith(
              color: context.colors.textSecondary,
            ),
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
        // 与卡片同一份下间距，否则滑动时红底会伸进卡间的空隙
        margin: const EdgeInsets.only(bottom: AppSpacing.cardGap),
        padding: const EdgeInsets.only(right: AppSpacing.md),
        decoration: BoxDecoration(
          color: context.colors.error,
          borderRadius: BorderRadius.circular(context.shape.cardRadius),
        ),
        child: Icon(Icons.delete_outline, color: context.colors.textOnPrimary),
      ),
      confirmDismiss: (_) => _confirmDelete(context, goal),
      onDismissed: (_) {
        runPaperAction(context, () => provider.deleteGoal(goal.id));
      },
      child: PaperCard(
        tone: PaperTone.row,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.cardPad,
          vertical: 15,
        ),
        margin: const EdgeInsets.only(bottom: AppSpacing.cardGap),
        tint: goal.isCompleted ? context.colors.success : null,
        // 点击整行进编辑；勾选与挪周是行内的独立按钮
        onTap: () => _showEditSheet(context, goal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                SizedBox(
                  width: 26,
                  child: Text(
                    no,
                    style: context.text.serifNum.copyWith(
                      fontSize: 13,
                      color: goal.isCompleted
                          ? context.colors.primary
                          : context.colors.textHint,
                    ),
                  ),
                ),
                InkCheckCircle(
                  isChecked: goal.isCompleted,
                  onTap: () {
                    runPaperAction(context, () => provider.toggleGoal(goal.id));
                  },
                  size: 21,
                  semanticLabel: goal.title,
                ),
                const SizedBox(width: AppSpacing.sm + 2),
                Expanded(
                  child: Text(
                    goal.title,
                    style: context.text.bodySerif.copyWith(
                      color: goal.isCompleted
                          ? context.colors.textHint
                          : context.colors.textPrimary,
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
                _buildDragHandle(index),
              ],
            ),
            if (goal.coinReward > 0)
              Padding(
                padding: const EdgeInsets.only(left: 26, top: 6),
                child: Text(
                  goal.rewardClaimedAt != null
                      ? '已领取 ${goal.coinReward} 金币'
                      : '完成奖励 ${goal.coinReward} 金币',
                  key: Key('weekly_reward_${goal.id}'),
                  style: AppText.caption.copyWith(
                    color: goal.rewardClaimedAt != null
                        ? context.colors.success
                        : context.colors.primary,
                  ),
                ),
              ),
            if (goal.hasMilestones)
              _buildMilestoneSection(context, goal, provider),
          ],
        ),
      ),
    );
  }

  Widget _buildMilestoneSection(
    BuildContext context,
    WeeklyGoal goal,
    WeeklyProvider provider,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Divider(height: 1, color: context.colors.divider),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Text(
                goal.progressMode == WeeklyProgressMode.count ? '打卡进度' : '阶段进度',
                style: AppText.label.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                '${goal.completedMilestones}/${goal.milestones.length}',
                style: context.text.serifNum.copyWith(
                  fontSize: 18,
                  color: goal.isCompleted
                      ? context.colors.success
                      : context.colors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          LinearProgressIndicator(
            value: goal.progress,
            backgroundColor: context.colors.surfaceVariant,
            valueColor: AlwaysStoppedAnimation<Color>(
              goal.isCompleted
                  ? context.colors.success
                  : context.colors.primary,
            ),
            minHeight: 4,
            borderRadius: AppRadius.brFull,
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xxs,
            children: <Widget>[
              for (final WeeklyMilestone milestone in goal.milestones)
                _buildMilestoneChip(context, goal, milestone, provider),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneChip(
    BuildContext context,
    WeeklyGoal goal,
    WeeklyMilestone milestone,
    WeeklyProvider provider,
  ) {
    return Semantics(
      button: true,
      checked: milestone.isCompleted,
      label: '${milestone.title}，${milestone.isCompleted ? '已完成' : '未完成'}',
      onTap: () {
        runPaperAction(
          context,
          () => provider.toggleMilestone(goal.id, milestone.id),
        );
      },
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              runPaperAction(
                context,
                () => provider.toggleMilestone(goal.id, milestone.id),
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                InkCheckCircle(
                  isChecked: milestone.isCompleted,
                  onTap: () {
                    runPaperAction(
                      context,
                      () => provider.toggleMilestone(goal.id, milestone.id),
                    );
                  },
                  size: 18,
                  color: goal.isCompleted
                      ? context.colors.success
                      : context.colors.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  milestone.title,
                  style: AppText.caption.copyWith(
                    color: milestone.isCompleted
                        ? context.colors.textHint
                        : context.colors.textPrimary,
                    decoration: milestone.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 拖拽把手：按住这一小块上下拖动改顺序。
  ///
  /// 不用 ReorderableListView 默认的整行长按——整行已经承担了点击编辑
  /// 与左滑删除，再叠一个长按拖拽会让三种手势互相抢。显式把手把「排序」
  /// 圈在这一块里，其余手势不受影响。
  Widget _buildDragHandle(int index) {
    return ReorderableDragStartListener(
      index: index,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxs),
        child: Semantics(
          button: true,
          label: '拖动调整顺序',
          child: Icon(
            Icons.drag_handle_rounded,
            size: 20,
            color: context.colors.textSecondary,
          ),
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
          child: Icon(
            Icons.event_repeat_outlined,
            size: 20,
            color: context.colors.textSecondary,
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
          PaperTextButton(
            onPressed: () => Navigator.pop(ctx, false),
            label: '取消',
          ),
          PaperTextButton(
            onPressed: () {
              AppHaptics.confirm();
              Navigator.pop(ctx, true);
            },
            color: context.colors.error,
            label: '删除',
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
      lastDate: DateTime(DateTime.now().year + 10, 12, 31),
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
        onSubmit:
            (
              String title,
              List<WeeklyMilestone> milestones,
              WeeklyProgressMode? progressMode,
              int coinReward,
            ) async {
              final WeeklyProvider provider = sheetContext
                  .read<WeeklyProvider>();
              final success = await runPaperAction(sheetContext, () async {
                if (goal == null) {
                  await provider.addGoal(
                    title,
                    milestones: milestones,
                    progressMode: progressMode,
                    coinReward: coinReward,
                  );
                } else {
                  await provider.updateGoal(
                    goal.copyWith(
                      title: title,
                      milestones: milestones,
                      progressMode: progressMode,
                      coinReward: goal.rewardClaimedAt != null
                          ? goal.coinReward
                          : coinReward,
                    ),
                  );
                }
              });
              if (success && sheetContext.mounted) Navigator.pop(sheetContext);
            },
      ),
    );
  }
}

/// 新增 / 编辑目标的表单，支持普通目标与可勾选的分段目标。
class _WeeklyGoalSheet extends StatefulWidget {
  const _WeeklyGoalSheet({required this.initial, required this.onSubmit});

  final WeeklyGoal? initial;
  final Future<void> Function(
    String title,
    List<WeeklyMilestone> milestones,
    WeeklyProgressMode? progressMode,
    int coinReward,
  )
  onSubmit;

  @override
  State<_WeeklyGoalSheet> createState() => _WeeklyGoalSheetState();
}

class _WeeklyGoalSheetState extends State<_WeeklyGoalSheet> {
  static const int _maxMilestones = 30;
  final Uuid _uuid = const Uuid();

  late final TextEditingController _controller = TextEditingController(
    text: widget.initial?.title ?? '',
  );
  late final TextEditingController _countController;
  late final TextEditingController _coinController;
  late bool _progressEnabled;
  late bool _rewardEnabled;
  String? _coinError;
  late WeeklyProgressMode _mode;
  late List<WeeklyMilestone> _milestones;
  String? _countError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final WeeklyGoal? initial = widget.initial;
    _progressEnabled = initial?.hasMilestones ?? false;
    _rewardEnabled = (initial?.coinReward ?? 0) > 0;
    _coinController = TextEditingController(
      text: '${initial?.coinReward ?? 30}',
    );
    _mode = initial?.progressMode ?? WeeklyProgressMode.stages;
    _milestones = List<WeeklyMilestone>.of(
      initial?.milestones ?? const <WeeklyMilestone>[],
    );
    _countController = TextEditingController(
      text: '${_milestones.isEmpty ? 3 : _milestones.length}',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _countController.dispose();
    _coinController.dispose();
    super.dispose();
  }

  void _refreshMilestones({bool resetCompletion = false}) {
    final int? count = _parsedCount;
    if (count == null) {
      _countError = '请输入 1–$_maxMilestones';
      return;
    }
    _countError = null;
    final List<WeeklyMilestone> previous = _milestones;
    _milestones = <WeeklyMilestone>[
      for (int i = 0; i < count; i++)
        if (!resetCompletion && i < previous.length)
          previous[i].copyWith(title: _milestoneTitle(i), sortOrder: i)
        else
          WeeklyMilestone(
            id: _uuid.v4(),
            title: _milestoneTitle(i),
            sortOrder: i,
          ),
    ];
  }

  int? get _parsedCount {
    final int? count = int.tryParse(_countController.text.trim());
    if (count == null || count < 1 || count > _maxMilestones) return null;
    return count;
  }

  int? get _parsedCoinReward {
    final int? value = int.tryParse(_coinController.text.trim());
    if (value == null || value < 1 || value > 999999) return null;
    return value;
  }

  String _milestoneTitle(int index) => _mode == WeeklyProgressMode.stages
      ? '阶段 ${index + 1}'
      : '第 ${index + 1} 次';

  void _setProgressEnabled(bool value) {
    setState(() {
      _progressEnabled = value;
      if (value) {
        _refreshMilestones(resetCompletion: true);
      } else {
        _milestones = <WeeklyMilestone>[];
        _countError = null;
      }
    });
  }

  void _changeMode(WeeklyProgressMode mode) {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      _refreshMilestones(resetCompletion: true);
    });
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
          style: context.text.titleSerif.copyWith(
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          key: const Key('weekly_goal_title'),
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: const InputDecoration(hintText: '这周想完成什么'),
        ),
        const SizedBox(height: AppSpacing.md),
        PaperCard(
          tone: PaperTone.raised,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
              key: const Key('weekly_reward_switch'),
              contentPadding: EdgeInsets.zero,
              title: const Text('完成奖励金币'),
              subtitle: Text(
                widget.initial?.rewardClaimedAt != null
                    ? '奖励已领取，金额不可修改'
                    : '全部完成后一次性到账，可在商店兑换奖励',
              ),
              value: _rewardEnabled,
              activeThumbColor: context.colors.primary,
              onChanged: _saving || widget.initial?.rewardClaimedAt != null
                  ? null
                  : (bool value) => setState(() {
                      _rewardEnabled = value;
                      _coinError = null;
                    }),
            ),
          ),
        ),
        if (_rewardEnabled) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const Key('weekly_coin_reward'),
            controller: _coinController,
            enabled: widget.initial?.rewardClaimedAt == null,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            maxLength: 6,
            onChanged: (_) => setState(() => _coinError = null),
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: '奖励金币',
              prefixIcon: const Icon(Icons.monetization_on_outlined, size: 20),
              suffixText: '金币',
              counterText: '',
              errorText: _coinError,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        PaperCard(
          tone: PaperTone.raised,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
              key: const Key('weekly_progress_switch'),
              contentPadding: EdgeInsets.zero,
              title: const Text('分段完成'),
              subtitle: const Text('拆成阶段，或按次数逐点打卡'),
              value: _progressEnabled,
              activeThumbColor: context.colors.primary,
              onChanged: _saving ? null : _setProgressEnabled,
            ),
          ),
        ),
        if (_progressEnabled) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          SegmentedControl<WeeklyProgressMode>(
            segments: const <Segment<WeeklyProgressMode>>[
              Segment<WeeklyProgressMode>(WeeklyProgressMode.stages, '按阶段'),
              Segment<WeeklyProgressMode>(WeeklyProgressMode.count, '按次数'),
            ],
            value: _mode,
            onChanged: _saving ? (_) {} : _changeMode,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('weekly_milestone_count'),
            controller: _countController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            maxLength: 2,
            onChanged: (_) => setState(() => _refreshMilestones()),
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: _mode == WeeklyProgressMode.stages ? '阶段数量' : '打卡次数',
              hintText: '1–$_maxMilestones',
              suffixText: _mode == WeeklyProgressMode.stages ? '个' : '次',
              errorText: _countError,
            ),
          ),
          if (_parsedCount != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _buildPreview(),
          ],
          if (isEditing && (widget.initial?.hasMilestones ?? false))
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                '调整数量会保留对应序号的完成状态；切换类型会重新开始。',
                style: AppText.caption.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            Icon(
              Icons.event_outlined,
              size: 14,
              color: context.colors.textSecondary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${isEditing ? '所在周' : '将添加到'}：${_weekHint(weekKey)}',
                style: AppText.caption.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: PaperButton(
            onPressed: _saving ? null : _submit,
            loading: _saving,
            loadingLabel: '正在保存',
            label: isEditing ? '保存' : '添加',
          ),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    final List<WeeklyMilestone> preview = _milestones.take(6).toList();
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: <Widget>[
        for (final WeeklyMilestone milestone in preview)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: context.colors.primary.withValues(alpha: 0.08),
              borderRadius: AppRadius.brSm,
              border: Border.all(color: context.colors.divider),
            ),
            child: Text(
              milestone.title,
              style: AppText.caption.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ),
        if (_milestones.length > preview.length)
          Text(
            '等 ${_milestones.length} 个打卡点',
            style: AppText.caption.copyWith(
              color: context.colors.textSecondary,
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

  Future<void> _submit() async {
    if (_saving) return;
    final String title = _controller.text.trim();
    if (title.isEmpty) return;
    if (_progressEnabled && _parsedCount == null) {
      setState(() => _countError = '请输入 1–$_maxMilestones');
      return;
    }
    if (_rewardEnabled && _parsedCoinReward == null) {
      setState(() => _coinError = '请输入 1–999999 金币');
      return;
    }
    if (_progressEnabled) _refreshMilestones();
    setState(() => _saving = true);
    await runPaperAction(
      context,
      () => widget.onSubmit(
        title,
        _progressEnabled ? _milestones : const <WeeklyMilestone>[],
        _progressEnabled ? _mode : null,
        _rewardEnabled ? (_parsedCoinReward ?? 0) : 0,
      ),
    );
    if (mounted) setState(() => _saving = false);
  }
}
