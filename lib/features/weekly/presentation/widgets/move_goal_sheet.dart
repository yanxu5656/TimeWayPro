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
          style: AppText.h3.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '「${goal.title}」',
          style: AppText.caption.copyWith(color: AppColors.textSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final int offset in _quickOffsets) ...<Widget>[
          _buildWeekOption(
            context,
            monday: thisMonday.add(Duration(days: 7 * offset)),
          ),
          const SizedBox(height: AppSpacing.cardGap),
        ],
        _buildCustomOption(context),
      ],
    );
  }

  Widget _buildWeekOption(BuildContext context, {required DateTime monday}) {
    final String key = weekKeyOf(monday);
    final bool isCurrent = key == goal.weekKey;
    final String? short = weekShortLabel(monday);

    return PaperCard(
      tone: PaperTone.flat,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      // 当前所在周不可点：挪到原地没有意义，亮着反而让人怀疑没生效
      onTap: isCurrent ? null : () => _move(context, key),
      child: Row(
        children: <Widget>[
          Text(
            short ?? weekRangeLabel(monday),
            style: AppText.body.copyWith(
              fontWeight: FontWeight.w600,
              color: isCurrent ? AppColors.textHint : AppColors.textPrimary,
            ),
          ),
          if (short != null) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            Text(
              weekRangeLabel(monday),
              style: AppText.caption.copyWith(
                color: isCurrent ? AppColors.textHint : AppColors.textSecondary,
              ),
            ),
          ],
          const Spacer(),
          if (isCurrent)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: AppColors.primarySubtle,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                '当前',
                style: AppText.labelSm.copyWith(color: AppColors.primary),
              ),
            )
          else
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.textHint,
            ),
        ],
      ),
    );
  }

  Widget _buildCustomOption(BuildContext context) {
    return PaperCard(
      tone: PaperTone.flat,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      onTap: () => _pickWeek(context),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.calendar_month_rounded,
            size: 18,
            color: AppColors.primary,
          ),
          SizedBox(width: AppSpacing.sm),
          Text(
            '选其他周…',
            style: AppText.body.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  void _move(BuildContext context, String targetWeekKey) {
    context.read<WeeklyProvider>().moveGoalToWeek(goal, targetWeekKey);
    Navigator.pop(context);
  }

  Future<void> _pickWeek(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(goal.weekKey),
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
    if (picked == null) return;
    final String key = weekKeyOf(picked);
    // 选中目标所在周本身：视作无操作，留在面板里等用户重选
    if (key == goal.weekKey) return;
    if (context.mounted) _move(context, key);
  }
}
