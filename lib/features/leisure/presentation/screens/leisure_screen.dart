import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/ui/paper.dart';
import '../../data/models/leisure_item.dart';
import '../../providers/leisure_provider.dart';

/// 闲时清单：不紧急但想做的事。与待办的区别是**没有日期压力**——
/// 不分组到时间段、不排进今天，只是一个慢慢挑的候选池。
class LeisureScreen extends StatefulWidget {
  const LeisureScreen({super.key});

  @override
  State<LeisureScreen> createState() => _LeisureScreenState();
}

class _LeisureScreenState extends State<LeisureScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<LeisureProvider>().loadItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PaperScaffold(
      body: Consumer<LeisureProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.xs,
                  AppSpacing.screenH,
                  AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Masthead(
                      kicker: 'IDLE HOURS',
                      title: '闲时清单',
                      meta: Text.rich(
                        TextSpan(
                          style: AppText.caption.copyWith(
                            color: context.colors.textSecondary,
                            letterSpacing: 0.4,
                          ),
                          children: <InlineSpan>[
                            const TextSpan(text: '共 '),
                            TextSpan(
                              text: '${provider.totalCount}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: context.colors.primary,
                              ),
                            ),
                            const TextSpan(text: ' 件 · 还没试 '),
                            TextSpan(
                              text:
                                  '${provider.totalCount - provider.doneCount}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: context.colors.primary,
                              ),
                            ),
                            const TextSpan(text: ' 件'),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        PaperChip(
                          label: '全部',
                          selected: provider.filter == LeisureFilter.all,
                          onTap: () => provider.setFilter(LeisureFilter.all),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        PaperChip(
                          label: '还没试',
                          icon: Icons.schedule_rounded,
                          selected: provider.filter == LeisureFilter.pending,
                          onTap: () =>
                              provider.setFilter(LeisureFilter.pending),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        PaperChip(
                          label: '试过了',
                          icon: Icons.check_circle_outline_rounded,
                          selected: provider.filter == LeisureFilter.done,
                          onTap: () => provider.setFilter(LeisureFilter.done),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildList(provider),
              ),
            ],
          );
        },
      ),
      floatingActionButton: PaperFab(
        heroTag: 'leisure_fab',
        label: '记一件',
        onPressed: () => showPaperSheet(
          context,
          builder: (context) => const _LeisureSheet(),
        ),
      ),
    );
  }

  Widget _buildList(LeisureProvider provider) {
    final items = provider.filteredItems;
    if (items.isEmpty) {
      if (provider.totalCount == 0) return _buildEmptyState();
      return Center(
        child: Text(
          '这个筛选下还没有内容',
          style: AppText.caption.copyWith(color: context.colors.textHint),
        ),
      );
    }

    var slot = 0;
    Widget staged(Widget child) =>
        StaggeredEntrance(index: slot++, child: child);

    return StaggerScope(
      // 闲时清单是 MainScreen 里的第 5 个 Tab
      slotIndex: 5,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          0,
          AppSpacing.screenH,
          AppSpacing.navInset,
        ),
        children: [
          for (final item in items) staged(_buildCard(item, provider)),
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
              Icons.sports_esports_rounded,
              size: 48,
              color: context.colors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '闲时清单空着',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '不紧急但想做的事，记在这里慢慢挑',
            style: TextStyle(fontSize: 14, color: context.colors.textHint),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(LeisureItem item, LeisureProvider provider) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
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
            title: const Text('删除闲时条目'),
            content: Text('确定要删除「${item.title}」吗？'),
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
        runPaperAction(context, () => provider.deleteItem(item.id));
      },
      child: PaperCard(
        tone: PaperTone.row,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.cardPad,
          vertical: 15,
        ),
        margin: const EdgeInsets.only(bottom: AppSpacing.cardGap),
        tint: item.isDone ? context.colors.success : null,
        onTap: () => showPaperSheet(
          context,
          builder: (context) => _LeisureSheet(item: item),
        ),
        child: Row(
          children: [
            InkCheckCircle(
              isChecked: item.isDone,
              onTap: () {
                runPaperAction(context, () => provider.toggleDone(item.id));
              },
              semanticLabel: item.title,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: context.text.bodySerif.copyWith(
                      color: item.isDone
                          ? context.colors.textHint
                          : context.colors.textPrimary,
                      decoration: item.isDone
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  if (item.note != null && item.note!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.note!,
                      style: AppText.caption.copyWith(
                        color: context.colors.textHint,
                        decoration: item.isDone
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
            if (item.isDone)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xs),
                child: Text(
                  '试过了',
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
}

class _LeisureSheet extends StatefulWidget {
  const _LeisureSheet({this.item});

  final LeisureItem? item;

  @override
  State<_LeisureSheet> createState() => _LeisureSheetState();
}

class _LeisureSheetState extends State<_LeisureSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  bool _saving = false;

  bool get _isEditing => widget.item != null;
  bool get _valid => _titleController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item?.title ?? '');
    _noteController = TextEditingController(text: widget.item?.note ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _isEditing ? '编辑闲时条目' : '记一件闲时想做的事',
          style: context.text.titleSerif.copyWith(
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '想做的事',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.colors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _titleController,
          autofocus: !_isEditing,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(hintText: '如：打一款新游戏'),
        ),
        const SizedBox(height: 20),
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
          controller: _noteController,
          maxLines: 2,
          decoration: const InputDecoration(hintText: '为什么想做 / 在哪玩…'),
        ),
        const SizedBox(height: 24),
        if (_isEditing) ...[
          PaperTextButton(
            onPressed: _confirmDelete,
            color: context.colors.error,
            icon: Icons.delete_outline_rounded,
            label: '删除这条',
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          child: PaperButton(
            onPressed: _valid && !_saving ? _save : null,
            loading: _saving,
            loadingLabel: '正在保存',
            label: _isEditing ? '保存' : '添加',
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除闲时条目'),
        content: Text('确定要删除「${widget.item!.title}」吗？'),
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
    if (ok == true && mounted) {
      final success = await runPaperAction(
        context,
        () => context.read<LeisureProvider>().deleteItem(widget.item!.id),
      );
      if (success && mounted) Navigator.pop(context);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final provider = context.read<LeisureProvider>();
    final title = _titleController.text.trim();
    final note = _noteController.text.trim().isEmpty
        ? null
        : _noteController.text.trim();
    setState(() => _saving = true);
    final success = await runPaperAction(context, () async {
      if (_isEditing) {
        await provider.updateItem(
          widget.item!.copyWith(title: title, note: note),
        );
      } else {
        await provider.addItem(title: title, note: note);
      }
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (success) Navigator.pop(context);
  }
}
