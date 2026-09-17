import 'package:flutter/material.dart';

import '../../../../core/ui/glass.dart';
import '../../data/models/weekly_goal.dart';
import '../../providers/daily_provider.dart';

/// 待办页顶部的「本周目标」卡。
///
/// 只显示本周（`DailyProvider.currentWeekKey`），旧周的数据留在 JSON 文件
/// 里不删。勾选进度即完成度，不做额外的自动统计。
///
/// 直接接收 [provider] 而不是自己包一层 `Consumer`：父层已经有一个
/// `Consumer<DailyProvider>`，再套一层只会让这棵子树重复重建。
class WeeklyGoalsCard extends StatelessWidget {
  const WeeklyGoalsCard({super.key, required this.provider});

  final DailyProvider provider;

  @override
  Widget build(BuildContext context) {
    final List<WeeklyGoal> goals = provider.weeklyGoals;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildTitleRow(),
          if (goals.isEmpty)
            _buildEmptyHint(context)
          else ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _buildProgressBar(),
            const SizedBox(height: AppSpacing.xxs),
            for (final WeeklyGoal goal in goals) _buildGoalRow(context, goal),
            _buildAddRow(context),
          ],
        ],
      ),
    );
  }

  Widget _buildTitleRow() {
    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(AppSpacing.xs - 2),
          decoration: BoxDecoration(
            color: AppColors.glassTintPrimary,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: const Icon(
            Icons.flag_outlined,
            size: 16,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          '本周目标',
          style: AppText.taskTitle.copyWith(color: AppColors.textPrimary),
        ),
        const Spacer(),
        if (provider.weeklyTotal > 0)
          CountUpText(
            value: provider.weeklyCompleted,
            format: (int v) => '$v/${provider.weeklyTotal}',
            duration: const Duration(milliseconds: 450),
            style: AppText.title.copyWith(color: AppColors.primary),
          ),
      ],
    );
  }

  Widget _buildProgressBar() {
    return ClipRRect(
      borderRadius: AppRadius.brXs,
      child: LinearProgressIndicator(
        value: provider.weeklyProgress,
        backgroundColor: AppColors.surfaceVariant,
        valueColor: AlwaysStoppedAnimation<Color>(
          provider.weeklyProgress >= 1.0
              ? AppColors.success
              : AppColors.primary,
        ),
        minHeight: 6,
      ),
    );
  }

  Widget _buildEmptyHint(BuildContext context) {
    return GestureDetector(
      onTap: () => _showEditSheet(context, null),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Row(
          children: <Widget>[
            const Icon(
              Icons.add_circle_outline_rounded,
              size: 18,
              color: AppColors.textHint,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '记一下这周想完成什么',
              style: AppText.caption.copyWith(color: AppColors.textHint),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalRow(BuildContext context, WeeklyGoal goal) {
    return Dismissible(
      key: Key(goal.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: AppRadius.brMd,
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.textOnPrimary),
      ),
      confirmDismiss: (_) => _confirmDelete(context, goal),
      onDismissed: (_) => provider.deleteWeeklyGoal(goal.id),
      child: GestureDetector(
        // 用 GestureDetector 而不是 InkWell：GlassCard 在没有 onTap 时
        // 不会包 Material，InkWell 会因此报 "No Material widget found"。
        // 点击反馈由左侧的 GlassCheckCircle 提供。
        onTap: () => _showEditSheet(context, goal),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs - 2),
          child: Row(
            children: <Widget>[
              GlassCheckCircle(
                isChecked: goal.isCompleted,
                onTap: () => provider.toggleWeeklyGoal(goal.id),
                size: 22,
                semanticLabel: goal.title,
              ),
              const SizedBox(width: AppSpacing.sm),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddRow(BuildContext context) {
    return GestureDetector(
      onTap: () => _showEditSheet(context, null),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Row(
          children: <Widget>[
            const Icon(Icons.add_rounded, size: 18, color: AppColors.textHint),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '添加一条',
              style: AppText.caption.copyWith(color: AppColors.textHint),
            ),
          ],
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

  /// [goal] 为 null 时是新增
  void _showEditSheet(BuildContext context, WeeklyGoal? goal) {
    showGlassSheet(
      context,
      showHandle: false,
      builder: (BuildContext sheetContext) => _WeeklyGoalSheet(
        initial: goal,
        onSubmit: (String title) {
          if (goal == null) {
            provider.addWeeklyGoal(title);
          } else {
            provider.updateWeeklyGoal(goal.copyWith(title: title));
          }
          Navigator.pop(sheetContext);
        },
      ),
    );
  }
}

/// 新增 / 编辑本周目标的表单。只有一个输入框，所以不带拖拽把手。
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          isEditing ? '编辑本周目标' : '添加本周目标',
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

  void _submit() {
    final String title = _controller.text.trim();
    if (title.isEmpty) return;
    widget.onSubmit(title);
  }
}
