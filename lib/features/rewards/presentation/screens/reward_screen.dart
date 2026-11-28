import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/ui/paper.dart';
import '../../data/models/reward_product.dart';
import '../../providers/reward_provider.dart';

class RewardScreen extends StatefulWidget {
  const RewardScreen({super.key});

  @override
  State<RewardScreen> createState() => _RewardScreenState();
}

class _RewardScreenState extends State<RewardScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) context.read<RewardProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PaperScaffold(
      body: Consumer<RewardProvider>(
        builder:
            (BuildContext context, RewardProvider provider, Widget? child) {
              return Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenH,
                      AppSpacing.xs,
                      AppSpacing.screenH,
                      AppSpacing.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Masthead(
                                kicker: 'REWARD EXCHANGE',
                                title: '奖励商店',
                                meta: const Text('把坚持，换成生活里的小确幸'),
                              ),
                            ),
                            Container(
                              key: const Key('reward_balance'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                              decoration: BoxDecoration(
                                color: context.colors.primarySubtle,
                                borderRadius: AppRadius.brMd,
                                border: Border.all(
                                  color: context.colors.divider,
                                ),
                              ),
                              child: Row(
                                children: <Widget>[
                                  Icon(
                                    Icons.monetization_on_rounded,
                                    size: 18,
                                    color: context.colors.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${provider.balance}',
                                    style: context.text.serifNum.copyWith(
                                      fontSize: 22,
                                      color: context.colors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        SegmentedControl<int>(
                          segments: const <Segment<int>>[
                            Segment<int>(0, '商店'),
                            Segment<int>(1, '仓库'),
                            Segment<int>(2, '明细'),
                          ],
                          value: _tab,
                          onChanged: (int value) =>
                              setState(() => _tab = value),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: provider.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _buildContent(provider),
                  ),
                ],
              );
            },
      ),
      floatingActionButton: _tab == 0
          ? PaperFab(
              heroTag: 'reward_fab',
              label: '添加奖励',
              onPressed: () => showPaperSheet(
                context,
                builder: (BuildContext context) => const _ProductSheet(),
              ),
            )
          : null,
    );
  }

  Widget _buildContent(RewardProvider provider) {
    if (_tab == 0) return _buildShop(provider);
    if (_tab == 1) return _buildInventory(provider);
    return _buildHistory(provider);
  }

  Widget _buildShop(RewardProvider provider) {
    final List<RewardProduct> products = provider.products;
    if (products.isEmpty) {
      return _empty(Icons.storefront_outlined, '商店还是空的', '添加一件想用金币兑换的奖励吧');
    }
    return StaggerScope(
      slotIndex: 7,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          0,
          AppSpacing.screenH,
          AppSpacing.navInset,
        ),
        children: <Widget>[
          SectionHeader(
            index: 0,
            title: '可兑换',
            trailing: '${products.length} 件',
          ),
          for (int i = 0; i < products.length; i++)
            StaggeredEntrance(
              index: i + 1,
              child: _buildProductCard(products[i], provider),
            ),
        ],
      ),
    );
  }

  Widget _buildProductCard(RewardProduct product, RewardProvider provider) {
    final int purchased = provider.purchasedCount(product.id);
    final bool soldOut = product.stock != null && product.stock! < 1;
    final bool limitReached =
        product.purchaseLimit != null && purchased >= product.purchaseLimit!;
    final bool unavailable =
        soldOut || limitReached || provider.balance < product.price;
    final String status = soldOut
        ? '已兑完'
        : limitReached
        ? '已达限购'
        : product.stock == null
        ? '不限量'
        : '剩余 ${product.stock} 件';
    return PaperCard(
      tone: PaperTone.row,
      margin: const EdgeInsets.only(bottom: AppSpacing.cardGap),
      onTap: () => showPaperSheet(
        context,
        builder: (BuildContext context) => _ProductSheet(product: product),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              _icon(product.icon),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(product.title, style: context.text.bodySerif),
                    if (product.description != null &&
                        product.description!.isNotEmpty)
                      Text(
                        product.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption.copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '${product.price}',
                style: context.text.serifNum.copyWith(
                  color: context.colors.primary,
                  fontSize: 22,
                ),
              ),
              const Icon(
                Icons.monetization_on_outlined,
                size: 16,
                color: Colors.amber,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  product.purchaseLimit == null
                      ? status
                      : '$status · 已兑 $purchased/${product.purchaseLimit}',
                  style: AppText.caption.copyWith(
                    color: context.colors.textHint,
                  ),
                ),
              ),
              PaperButton(
                key: Key('buy_${product.id}'),
                label: soldOut
                    ? '已兑完'
                    : limitReached
                    ? '已达限购'
                    : '兑换',
                compact: true,
                onPressed: unavailable ? null : () => _confirmPurchase(product),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInventory(RewardProvider provider) {
    if (provider.inventory.isEmpty) {
      return _empty(Icons.inventory_2_outlined, '仓库空着', '去商店兑换第一件奖励吧');
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        0,
        AppSpacing.screenH,
        AppSpacing.navInset,
      ),
      children: <Widget>[
        SectionHeader(
          index: 0,
          title: '我的奖励',
          trailing: '${provider.inventoryCount} 件待兑现',
        ),
        for (final InventoryItem item in provider.inventory)
          PaperCard(
            key: Key('inventory_${item.productId}'),
            tone: PaperTone.row,
            margin: const EdgeInsets.only(bottom: AppSpacing.cardGap),
            child: Row(
              children: <Widget>[
                _icon(item.icon),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(item.title, style: context.text.bodySerif),
                      Text(
                        '剩余 ${item.quantity} 件 · 已兑现 ${item.usedCount} 件',
                        style: AppText.caption.copyWith(
                          color: context.colors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
                PaperOutlinedButton(
                  key: Key('fulfill_${item.productId}'),
                  label: '去兑现',
                  compact: true,
                  onPressed: item.quantity < 1
                      ? null
                      : () => _confirmFulfill(item),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          '兑现表示已经在现实生活中享受了这个奖励；这里只做记录，不会退回金币。',
          style: AppText.caption,
        ),
      ],
    );
  }

  Widget _buildHistory(RewardProvider provider) {
    if (provider.transactions.isEmpty) {
      return _empty(
        Icons.receipt_long_outlined,
        '还没有金币明细',
        '完成带金币奖励的每周目标后，这里会记录每一笔',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        0,
        AppSpacing.screenH,
        AppSpacing.navInset,
      ),
      children: <Widget>[
        SectionHeader(
          index: 0,
          title: '金币流水',
          trailing: '${provider.transactions.length} 笔',
        ),
        for (final CoinTransaction item in provider.transactions)
          PaperCard(
            tone: PaperTone.row,
            margin: const EdgeInsets.only(bottom: AppSpacing.cardGap),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                item.amount > 0
                    ? Icons.add_circle_outline
                    : item.amount < 0
                    ? Icons.remove_circle_outline
                    : Icons.check_circle_outline,
                color: item.amount >= 0
                    ? context.colors.success
                    : context.colors.primary,
              ),
              title: Text(item.title),
              subtitle: Text(
                '${item.createdAt.year}-${_two(item.createdAt.month)}-${_two(item.createdAt.day)} '
                '${_two(item.createdAt.hour)}:${_two(item.createdAt.minute)}',
              ),
              trailing: item.amount == 0
                  ? const Text('已兑现')
                  : Text(
                      '${item.amount > 0 ? '+' : ''}${item.amount}',
                      style: context.text.serifNum.copyWith(
                        color: item.amount > 0
                            ? context.colors.success
                            : context.colors.textPrimary,
                      ),
                    ),
            ),
          ),
      ],
    );
  }

  Widget _empty(IconData icon, String title, String subtitle) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(icon, size: 46, color: context.colors.textHint),
        const SizedBox(height: AppSpacing.md),
        Text(title, style: context.text.titleSerif),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: AppText.caption.copyWith(color: context.colors.textHint),
        ),
      ],
    ),
  );

  String _two(int value) => value.toString().padLeft(2, '0');

  Widget _icon(String name) {
    final IconData icon = switch (name) {
      'movie' => Icons.movie_outlined,
      'coffee' => Icons.local_cafe_outlined,
      'game' => Icons.sports_esports_outlined,
      'rest' => Icons.weekend_outlined,
      'food' => Icons.restaurant_outlined,
      'travel' => Icons.card_travel_outlined,
      'book' => Icons.menu_book_outlined,
      _ => Icons.card_giftcard_outlined,
    };
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.colors.primarySubtle,
        borderRadius: AppRadius.brMd,
      ),
      child: Icon(icon, color: context.colors.primary),
    );
  }

  Future<void> _confirmPurchase(RewardProduct product) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('兑换「${product.title}」？'),
        content: Text('将花费 ${product.price} 金币。兑换后可随时在仓库记录兑现。'),
        actions: <Widget>[
          PaperTextButton(
            onPressed: () => Navigator.pop(context, false),
            label: '再想想',
          ),
          PaperTextButton(
            onPressed: () => Navigator.pop(context, true),
            label: '确认兑换',
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await runPaperAction(
      context,
      () => context.read<RewardProvider>().purchase(product.id),
    );
  }

  Future<void> _confirmFulfill(InventoryItem item) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('已经享受这个奖励了吗？'),
        content: Text('确认后消耗一件「${item.title}」，金币不会退回。'),
        actions: <Widget>[
          PaperTextButton(
            onPressed: () => Navigator.pop(context, false),
            label: '取消',
          ),
          PaperTextButton(
            onPressed: () => Navigator.pop(context, true),
            label: '确认兑现',
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await runPaperAction(
      context,
      () => context.read<RewardProvider>().fulfill(item.productId),
    );
  }
}

class _ProductSheet extends StatefulWidget {
  const _ProductSheet({this.product});

  final RewardProduct? product;

  @override
  State<_ProductSheet> createState() => _ProductSheetState();
}

class _ProductSheetState extends State<_ProductSheet> {
  final Uuid _uuid = const Uuid();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _stock;
  late final TextEditingController _limit;
  late String _icon;
  bool _saving = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    final RewardProduct? product = widget.product;
    _title = TextEditingController(text: product?.title);
    _description = TextEditingController(text: product?.description);
    _price = TextEditingController(text: '${product?.price ?? 30}');
    _stock = TextEditingController(text: product?.stock?.toString());
    _limit = TextEditingController(text: product?.purchaseLimit?.toString());
    _icon = product?.icon ?? 'gift';
  }

  @override
  void dispose() {
    for (final TextEditingController controller in <TextEditingController>[
      _title,
      _description,
      _price,
      _stock,
      _limit,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          widget.product == null ? '添加奖励' : '编辑奖励',
          style: context.text.titleSerif,
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          key: const Key('product_title'),
          controller: _title,
          decoration: const InputDecoration(
            labelText: '奖励名称',
            hintText: '如：看一场电影',
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _description,
          decoration: const InputDecoration(labelText: '描述（可选）'),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                key: const Key('product_price'),
                controller: _price,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: const InputDecoration(
                  labelText: '价格',
                  suffixText: '金币',
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextField(
                controller: _stock,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: const InputDecoration(
                  labelText: '库存',
                  hintText: '留空不限量',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _limit,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: const InputDecoration(
            labelText: '每人限兑次数',
            hintText: '留空不限购',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.xs,
          children: <Widget>[
            for (final MapEntry<String, IconData> entry
                in const <String, IconData>{
                  'gift': Icons.card_giftcard,
                  'movie': Icons.movie,
                  'coffee': Icons.local_cafe,
                  'game': Icons.sports_esports,
                  'rest': Icons.weekend,
                  'food': Icons.restaurant,
                  'travel': Icons.card_travel,
                  'book': Icons.menu_book,
                }.entries)
              IconButton(
                tooltip: entry.key,
                onPressed: () => setState(() => _icon = entry.key),
                isSelected: _icon == entry.key,
                icon: Icon(entry.value),
                style: IconButton.styleFrom(
                  backgroundColor: _icon == entry.key
                      ? context.colors.primarySubtle
                      : null,
                  foregroundColor: context.colors.primary,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (widget.product != null)
          PaperTextButton(
            key: const Key('product_delete'),
            label: _deleting ? '正在删除…' : '删除此奖励（保留仓库记录）',
            color: context.colors.error,
            onPressed: _saving || _deleting ? null : _confirmDelete,
          ),
        SizedBox(
          width: double.infinity,
          child: PaperButton(
            key: const Key('product_save'),
            label: '保存奖励',
            loading: _saving,
            onPressed: _saving || _deleting ? null : _save,
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final String title = _title.text.trim();
    final int? price = int.tryParse(_price.text.trim());
    final int? stock = int.tryParse(_stock.text.trim());
    final int? limit = int.tryParse(_limit.text.trim());
    if (title.isEmpty || price == null || price < 1) {
      await runPaperAction(
        context,
        () async => throw ArgumentError('请填写名称和有效价格'),
      );
      return;
    }
    setState(() => _saving = true);
    final bool success = await runPaperAction(context, () async {
      final RewardProvider provider = context.read<RewardProvider>();
      final RewardProduct product =
          (widget.product ??
                  RewardProduct(
                    id: _uuid.v4(),
                    title: title,
                    price: price,
                    createdAt: DateTime.now(),
                    sortOrder: provider.products.length,
                  ))
              .copyWith(
                title: title,
                description: _description.text.trim().isEmpty
                    ? null
                    : _description.text.trim(),
                icon: _icon,
                price: price,
                stock: stock,
                purchaseLimit: limit,
              );
      await provider.saveProduct(product);
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (success) Navigator.pop(context);
  }

  Future<void> _confirmDelete() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('删除这个奖励？'),
        content: const Text('删除后不可恢复；已经兑换的仓库奖励和金币明细会保留。'),
        actions: <Widget>[
          PaperTextButton(
            label: '取消',
            onPressed: () => Navigator.pop(context, false),
          ),
          PaperTextButton(
            label: '确认删除',
            color: context.colors.error,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    final bool success = await runPaperAction(
      context,
      () => context.read<RewardProvider>().deleteProduct(widget.product!.id),
    );
    if (!mounted) return;
    setState(() => _deleting = false);
    if (success) Navigator.pop(context);
  }
}
