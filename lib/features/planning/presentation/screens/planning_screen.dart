import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/ui/glass.dart';
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
    return GlassScaffold(
      title: '人生规划',
      // 与底部导航「规划」项的图标一致
      titleIcon: Icons.account_tree_rounded,
      body: Consumer<PlanProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final rootPlans = provider.rootPlans;

          if (rootPlans.isEmpty) {
            return _buildEmptyState();
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.navInset,
            ),
            children: rootPlans
                .map((plan) => _buildPlanTree(plan, provider, 0))
                .toList(),
          );
        },
      ),
      floatingActionButton: GlassFab(
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
            color: AppColors.textHint.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            '暂无规划',
            style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          const Text(
            '点击右下角 + 创建你的第一个目标',
            style: TextStyle(fontSize: 14, color: AppColors.textHint),
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
      child: GlassCard(
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        radius: AppRadius.lg,
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
                      color: AppColors
                          .chartColors[depth % AppColors.chartColors.length],
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                  ),

                // 图标
                Icon(
                  hasChildren ? Icons.folder_outlined : Icons.flag_outlined,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),

                // 标题
                Expanded(
                  child: Text(
                    plan.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
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
                backgroundColor: AppColors.background,
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
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
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
    if (progress < 0.3) return AppColors.error;
    if (progress < 0.7) return AppColors.warning;
    return AppColors.success;
  }

  void _showPlanDetail(Plan plan, PlanProvider provider) {
    showGlassSheet(
      context,
      builder: (context) => _PlanDetailSheet(
        plan: plan,
        onUpdate: (updatedPlan) {
          provider.updatePlan(updatedPlan);
          Navigator.pop(context);
        },
        onAddChild: () {
          Navigator.pop(context);
          _addPlan(context, plan.id);
        },
      ),
    );
  }

  void _showOptions(Plan plan, PlanProvider provider) {
    showGlassSheet(
      context,
      // SafeArea 与拖拽把手由 GlassSheet 统一提供
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              plan.title,
              style: AppText.title.copyWith(color: AppColors.textPrimary),
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
            leading: const Icon(Icons.delete_outline, color: AppColors.error),
            title: const Text('删除', style: TextStyle(color: AppColors.error)),
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
    showGlassSheet(
      context,
      builder: (context) => _AddPlanSheet(
        parentId: parentId,
        onAdd: (plan) {
          context.read<PlanProvider>().addPlan(plan);
          Navigator.pop(context);
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              provider.deletePlan(plan.id);
            },
            child: const Text('删除', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _PlanDetailSheet extends StatefulWidget {
  final Plan plan;
  final Function(Plan) onUpdate;
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
    // 外层键盘避让 / SafeArea / 滚动 / 拖拽把手由 GlassSheet 统一提供
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '目标详情',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 20),

        // 标题
        const Text(
          '标题',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(hintText: '输入目标标题'),
        ),
        const SizedBox(height: 16),

        // 描述
        const Text(
          '描述（可选）',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
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
            const Text(
              '进度',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              '${(_progress * 100).toInt()}%',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
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
              child: OutlinedButton.icon(
                onPressed: widget.onAddChild,
                icon: const Icon(Icons.add),
                label: const Text('添加子目标'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  widget.onUpdate(
                    widget.plan.copyWith(
                      title: _titleController.text.trim(),
                      description: _descController.text.trim().isEmpty
                          ? null
                          : _descController.text.trim(),
                      progress: _progress,
                    ),
                  );
                },
                child: const Text('保存'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AddPlanSheet extends StatefulWidget {
  final String? parentId;
  final Function(Plan) onAdd;

  const _AddPlanSheet({required this.parentId, required this.onAdd});

  @override
  State<_AddPlanSheet> createState() => _AddPlanSheetState();
}

class _AddPlanSheetState extends State<_AddPlanSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 外层键盘避让 / SafeArea / 滚动 / 拖拽把手由 GlassSheet 统一提供
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.parentId != null ? '添加子目标' : '创建新目标',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 20),

        const Text(
          '目标名称',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _titleController,
          autofocus: true,
          decoration: const InputDecoration(hintText: '输入目标名称'),
        ),
        const SizedBox(height: 16),

        const Text(
          '描述（可选）',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
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
          child: ElevatedButton(
            onPressed: () {
              if (_titleController.text.trim().isEmpty) return;
              final now = DateTime.now();
              widget.onAdd(
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
              );
            },
            child: const Text('创建'),
          ),
        ),
      ],
    );
  }
}
