import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/ui/paper.dart';
import '../../data/models/plan.dart';
import '../../providers/plan_provider.dart';

class PlanningScreen extends StatefulWidget {
  const PlanningScreen({super.key});

  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends State<PlanningScreen> {
  @override
  Widget build(BuildContext context) {
    return PaperScaffold(
      body: Consumer<PlanProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final rootPlans = provider.rootPlans;

          if (rootPlans.isEmpty) {
            return _buildEmptyState();
          }

          // 遍历整棵树拿总数与平均进度（规划页数据量小，直接走）
          int total = 0;
          double progressSum = 0;
          void walk(Plan plan) {
            total++;
            progressSum += plan.progress;
            for (final child in provider.getChildPlans(plan.id)) {
              walk(child);
            }
          }

          for (final root in rootPlans) {
            walk(root);
          }
          final int avgProgress = total > 0
              ? (progressSum / total * 100).round()
              : 0;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.xs,
              AppSpacing.screenH,
              AppSpacing.navInset,
            ),
            children: [
              Masthead(
                kicker: 'LIFE PLAN',
                title: '人生规划',
                meta: Text.rich(
                  TextSpan(
                    style: AppText.caption.copyWith(
                      color: context.colors.textSecondary,
                      letterSpacing: 0.4,
                    ),
                    children: <InlineSpan>[
                      const TextSpan(text: '共 '),
                      TextSpan(
                        text: '$total',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: context.colors.primary,
                        ),
                      ),
                      TextSpan(text: ' 个目标 · 平均进度 $avgProgress%'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              SectionHeader(
                index: 1,
                title: '目标树',
                trailing: '$total 项',
                topGap: false,
              ),
              const SizedBox(height: AppSpacing.sm),
              ...rootPlans.map((plan) => _buildPlanTree(plan, provider, 0)),
            ],
          );
        },
      ),
      floatingActionButton: PaperFab(
        heroTag: 'plan_fab',
        onPressed: () => _addPlan(context, null),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_tree_outlined,
            size: 64,
            color: context.colors.textHint.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无规划',
            style: TextStyle(fontSize: 18, color: context.colors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右下角 + 创建你的第一个目标',
            style: TextStyle(fontSize: 14, color: context.colors.textHint),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanTree(Plan plan, PlanProvider provider, int depth) {
    final children = provider.getChildPlans(plan.id);
    final hasChildren = children.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPlanCard(plan, provider, depth, hasChildren),
        if (hasChildren)
          Padding(
            padding: EdgeInsets.only(left: 24.0 * (depth + 1)),
            child: Column(
              children: children
                  .map((child) => _buildPlanTree(child, provider, depth + 1))
                  .toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildPlanCard(
    Plan plan,
    PlanProvider provider,
    int depth,
    bool hasChildren,
  ) {
    // 递归树的每个节点都包一层 RepaintBoundary——规划页是 eager build
    // 的深层树，任一节点变化都会波及整棵子树
    return RepaintBoundary(
      child: PaperCard(
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        padding: const EdgeInsets.all(AppSpacing.md),
        onTap: () => _showPlanDetail(plan, provider),
        onLongPress: () => _showOptions(plan, provider),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 层级指示器
                if (depth > 0)
                  Container(
                    width: 3,
                    height: 20,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color:
                          context.colors.chartColors[depth %
                              context.colors.chartColors.length],
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                  ),

                // 图标
                Icon(
                  hasChildren ? Icons.folder_outlined : Icons.flag_outlined,
                  size: 20,
                  color: context.colors.primary,
                ),
                const SizedBox(width: 10),

                // 标题
                Expanded(
                  child: Text(
                    plan.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ),

                // 进度
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getProgressColor(
                      plan.progress,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text(
                    plan.progressText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _getProgressColor(plan.progress),
                    ),
                  ),
                ),
              ],
            ),

            // 进度条
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xs),
              child: LinearProgressIndicator(
                value: plan.progress,
                backgroundColor: context.colors.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getProgressColor(plan.progress),
                ),
                minHeight: 6,
              ),
            ),

            // 描述
            if (plan.description != null && plan.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                plan.description!,
                style: TextStyle(
                  fontSize: 13,
                  color: context.colors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getProgressColor(double progress) {
    if (progress < 0.3) return context.colors.error;
    if (progress < 0.7) return context.colors.warning;
    return context.colors.success;
  }

  void _showPlanDetail(Plan plan, PlanProvider provider) {
    showPaperSheet(
      context,
      builder: (context) => _PlanDetailSheet(
        plan: plan,
        onUpdate: (updatedPlan) async {
          final success = await runPaperAction(
            context,
            () => provider.updatePlan(updatedPlan),
          );
          if (success && context.mounted) Navigator.pop(context);
        },
        onAddChild: () {
          Navigator.pop(context);
          _addPlan(context, plan.id);
        },
      ),
    );
  }

  void _showOptions(Plan plan, PlanProvider provider) {
    showPaperSheet(
      context,
      // SafeArea 与拖拽把手由 PaperSheet 统一提供
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              plan.title,
              style: context.text.titleSerif.copyWith(
                color: context.colors.textPrimary,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('添加子目标'),
            onTap: () {
              Navigator.pop(context);
              _addPlan(context, plan.id);
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('编辑'),
            onTap: () {
              Navigator.pop(context);
              _showPlanDetail(plan, provider);
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: context.colors.error),
            title: Text('删除', style: TextStyle(color: context.colors.error)),
            onTap: () {
              Navigator.pop(context);
              _deletePlan(plan, provider);
            },
          ),
        ],
      ),
    );
  }

  void _addPlan(BuildContext context, String? parentId) {
    showPaperSheet(
      context,
      builder: (context) => _AddPlanSheet(
        parentId: parentId,
        onAdd: (plan) async {
          final success = await runPaperAction(
            context,
            () => context.read<PlanProvider>().addPlan(plan),
          );
          if (success && context.mounted) Navigator.pop(context);
        },
      ),
    );
  }

  void _deletePlan(Plan plan, PlanProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除目标'),
        content: Text('确定要删除「${plan.title}」吗？子目标也会被删除。'),
        actions: [
          PaperTextButton(onPressed: () => Navigator.pop(context), label: '取消'),
          PaperTextButton(
            onPressed: () async {
              AppHaptics.confirm();
              Navigator.pop(context);
              await runPaperAction(
                this.context,
                () => provider.deletePlan(plan.id),
              );
            },
            color: context.colors.error,
            label: '删除',
          ),
        ],
      ),
    );
  }
}

class _PlanDetailSheet extends StatefulWidget {
  final Plan plan;
  final Future<void> Function(Plan) onUpdate;
  final VoidCallback onAddChild;

  const _PlanDetailSheet({
    required this.plan,
    required this.onUpdate,
    required this.onAddChild,
  });

  @override
  State<_PlanDetailSheet> createState() => _PlanDetailSheetState();
}

class _PlanDetailSheetState extends State<_PlanDetailSheet> {
  late double _progress;
  late TextEditingController _titleController;
  late TextEditingController _descController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _progress = widget.plan.progress;
    _titleController = TextEditingController(text: widget.plan.title);
    _descController = TextEditingController(
      text: widget.plan.description ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 外层键盘避让 / SafeArea / 滚动 / 拖拽把手由 PaperSheet 统一提供
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '目标详情',
          style: context.text.titleSerif.copyWith(
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 20),

        // 标题
        Text(
          '标题',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.colors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(hintText: '输入目标标题'),
        ),
        const SizedBox(height: 16),

        // 描述
        Text(
          '描述（可选）',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.colors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _descController,
          maxLines: 3,
          decoration: const InputDecoration(hintText: '输入目标描述'),
        ),
        const SizedBox(height: 20),

        // 进度
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '进度',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colors.textSecondary,
              ),
            ),
            Text(
              '${(_progress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.colors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 样式由全局 sliderTheme 提供，与原内联值逐项一致
        Slider(
          value: _progress,
          onChanged: (v) => setState(() => _progress = v),
          min: 0,
          max: 1,
          divisions: 20,
        ),
        const SizedBox(height: 24),

        // 按钮
        Row(
          children: [
            Expanded(
              child: PaperOutlinedButton(
                onPressed: widget.onAddChild,
                icon: Icons.add,
                label: '添加子目标',
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PaperButton(
                onPressed: _saving ? null : _save,
                loading: _saving,
                loadingLabel: '正在保存',
                label: '保存',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_saving || _titleController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    await runPaperAction(
      context,
      () => widget.onUpdate(
        widget.plan.copyWith(
          title: _titleController.text.trim(),
          description: _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
          progress: _progress,
        ),
      ),
    );
    if (mounted) setState(() => _saving = false);
  }
}

class _AddPlanSheet extends StatefulWidget {
  final String? parentId;
  final Future<void> Function(Plan) onAdd;

  const _AddPlanSheet({required this.parentId, required this.onAdd});

  @override
  State<_AddPlanSheet> createState() => _AddPlanSheetState();
}

class _AddPlanSheetState extends State<_AddPlanSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 外层键盘避让 / SafeArea / 滚动 / 拖拽把手由 PaperSheet 统一提供
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.parentId != null ? '添加子目标' : '创建新目标',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 20),

        Text(
          '目标名称',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.colors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _titleController,
          autofocus: true,
          decoration: const InputDecoration(hintText: '输入目标名称'),
        ),
        const SizedBox(height: 16),

        Text(
          '描述（可选）',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.colors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _descController,
          maxLines: 3,
          decoration: const InputDecoration(hintText: '输入目标描述'),
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: PaperButton(
            onPressed: _saving ? null : _save,
            loading: _saving,
            loadingLabel: '正在创建',
            label: '创建',
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_saving || _titleController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    await runPaperAction(
      context,
      () => widget.onAdd(
        Plan(
          id: const Uuid().v4(),
          title: _titleController.text.trim(),
          description: _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
          parentId: widget.parentId,
          createdAt: now,
          updatedAt: now,
        ),
      ),
    );
    if (mounted) setState(() => _saving = false);
  }
}
