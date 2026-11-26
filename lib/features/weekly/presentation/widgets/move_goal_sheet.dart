import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/ui/paper.dart';
import '../../../../core/utils/week.dart';
import '../../data/models/weekly_goal.dart';
import '../../providers/weekly_provider.dart';
import '../week_labels.dart';

/// 把 [goal] 挪到其他周的快捷面板。
///
/// 快捷档固定为相对「真实本周」的 上周 / 本周 / 下周 / 下下周，各带日期
/// 区间所以不会歧义；更远的周走底部的「选其他周」。目标当前所在周
/// 高亮为「当前」且不可点——它已经在那了。
Future<void> showMoveGoalSheet(BuildContext context, WeeklyGoal goal) {
  return showPaperSheet(
    context,
    showHandle: false,
    builder: (BuildContext sheetContext) => _MoveGoalSheet(goal: goal),
  );
}

class _MoveGoalSheet extends StatelessWidget {
  const _MoveGoalSheet({required this.goal});

  final WeeklyGoal goal;

  /// 相对真实本周的偏移：上周、本周、下周、下下周
  static const List<int> _quickOffsets = <int>[-1, 0, 1, 2];

  @override
  Widget build(BuildContext context) {
    final DateTime thisMonday = startOfWeek(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          '挪到其他周',
          style: context.text.titleSerif.copyWith(
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '「${goal.title}」',
          style: AppText.caption.copyWith(color: context.colors.textSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.lg),
        // 编号账本行（01–04）：行线分节，序号衬线陶土
        for (final (int i, int offset) in _quickOffsets.indexed)
          _buildWeekOption(
            context,
            index: i + 1,
            monday: DateTime(
              thisMonday.year,
              thisMonday.month,
              thisMonday.day + 7 * offset,
            ),
          ),
        _buildCustomOption(context),
      ],
    );
  }

  Widget _buildWeekOption(
    BuildContext context, {
    required int index,
    required DateTime monday,
  }) {
    final String key = weekKeyOf(monday);
    final bool isCurrent = key == goal.weekKey;
    final String? short = weekShortLabel(monday);
    final Color strong = isCurrent
        ? context.colors.textHint
        : context.colors.textPrimary;
    final Color weak = isCurrent
        ? context.colors.textHint
        : context.colors.textSecondary;

    return PaperCard(
      tone: PaperTone.row,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.cardPad,
        vertical: 13,
      ),
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      // 当前所在周不可点：挪到原地没有意义，亮着反而让人怀疑没生效
      onTap: isCurrent ? null : () => _move(context, key),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 30,
            child: Text(
              index.toString().padLeft(2, '0'),
              style: context.text.serifNum.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isCurrent
                    ? context.colors.textHint
                    : context.colors.primary,
              ),
            ),
          ),
          Text(
            short ?? weekRangeLabel(monday),
            style: context.text.bodySerif.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: strong,
            ),
          ),
          if (short != null) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            Text(
              weekRangeLabel(monday),
              style: AppText.caption.copyWith(color: weak),
            ),
          ],
          const Spacer(),
          if (isCurrent)
            Text(
              '当前',
              style: AppText.labelSm.copyWith(color: context.colors.primary),
            )
          else
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: context.colors.textHint,
            ),
        ],
      ),
    );
  }

  Widget _buildCustomOption(BuildContext context) {
    return PaperCard(
      tone: PaperTone.row,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.cardPad,
        vertical: 13,
      ),
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      onTap: () => _pickWeek(context),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 30,
            child: Icon(
              Icons.calendar_month_rounded,
              size: 17,
              color: context.colors.primary,
            ),
          ),
          Text(
            '选其他周…',
            style: context.text.bodySerif.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.colors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _move(BuildContext context, String targetWeekKey) async {
    final provider = context.read<WeeklyProvider>();
    final success = await runPaperAction(
      context,
      () => provider.moveGoalToWeek(goal, targetWeekKey),
    );
    if (success && context.mounted) Navigator.pop(context);
  }

  Future<void> _pickWeek(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(goal.weekKey),
      firstDate: DateTime(2020, 1, 6), // 期号锚点周一，往前的周没有 VOL 号
      lastDate: DateTime(DateTime.now().year + 10, 12, 31),
      builder: (BuildContext context, Widget? child) {
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
    if (picked == null) return;
    final String key = weekKeyOf(picked);
    // 选中目标所在周本身：视作无操作，留在面板里等用户重选
    if (key == goal.weekKey) return;
    if (context.mounted) _move(context, key);
  }
}
