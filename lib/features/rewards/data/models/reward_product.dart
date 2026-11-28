const Object _unset = Object();

class RewardProduct {
  final String id;
  final String title;
  final String? description;
  final String icon;
  final int price;
  final int? stock;
  final int? purchaseLimit;
  final bool isActive;
  final int sortOrder;
  final DateTime createdAt;

  const RewardProduct({
    required this.id,
    required this.title,
    this.description,
    this.icon = 'gift',
    required this.price,
    this.stock,
    this.purchaseLimit,
    this.isActive = true,
    this.sortOrder = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'title': title,
    'description': description,
    'icon': icon,
    'price': price,
    'stock': stock,
    'purchase_limit': purchaseLimit,
    'is_active': isActive ? 1 : 0,
    'sort_order': sortOrder,
    'created_at': createdAt.toIso8601String(),
  };

  factory RewardProduct.fromMap(Map<String, dynamic> map) => RewardProduct(
    id: map['id'] as String,
    title: map['title'] as String,
    description: map['description'] as String?,
    icon: map['icon'] as String? ?? 'gift',
    price: (map['price'] as num?)?.toInt() ?? 0,
    stock: (map['stock'] as num?)?.toInt(),
    purchaseLimit: (map['purchase_limit'] as num?)?.toInt(),
    isActive: map['is_active'] != 0,
    sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    createdAt: DateTime.parse(map['created_at'] as String),
  );

  RewardProduct copyWith({
    String? title,
    String? description,
    String? icon,
    int? price,
    Object? stock = _unset,
    Object? purchaseLimit = _unset,
    bool? isActive,
    int? sortOrder,
  }) => RewardProduct(
    id: id,
    title: title ?? this.title,
    description: description ?? this.description,
    icon: icon ?? this.icon,
    price: price ?? this.price,
    stock: identical(stock, _unset) ? this.stock : stock as int?,
    purchaseLimit: identical(purchaseLimit, _unset)
        ? this.purchaseLimit
        : purchaseLimit as int?,
    isActive: isActive ?? this.isActive,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt,
  );
}

class InventoryItem {
  final String productId;
  final String title;
  final String icon;
  final int quantity;
  final int acquiredCount;
  final int usedCount;
  final DateTime updatedAt;

  const InventoryItem({
    required this.productId,
    required this.title,
    required this.icon,
    required this.quantity,
    required this.acquiredCount,
    required this.usedCount,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
    'product_id': productId,
    'title': title,
    'icon': icon,
    'quantity': quantity,
    'acquired_count': acquiredCount,
    'used_count': usedCount,
    'updated_at': updatedAt.toIso8601String(),
  };

  factory InventoryItem.fromMap(Map<String, dynamic> map) => InventoryItem(
    productId: map['product_id'] as String,
    title: map['title'] as String,
    icon: map['icon'] as String? ?? 'gift',
    quantity: (map['quantity'] as num).toInt(),
    acquiredCount: (map['acquired_count'] as num?)?.toInt() ?? 0,
    usedCount: (map['used_count'] as num?)?.toInt() ?? 0,
    updatedAt: DateTime.parse(map['updated_at'] as String),
  );
}

class CoinTransaction {
  final String id;
  final int amount;
  final String type;
  final String title;
  final String? referenceId;
  final DateTime createdAt;

  const CoinTransaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.title,
    this.referenceId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'amount': amount,
    'type': type,
    'title': title,
    'reference_id': referenceId,
    'created_at': createdAt.toIso8601String(),
  };

  factory CoinTransaction.fromMap(Map<String, dynamic> map) => CoinTransaction(
    id: map['id'] as String,
    amount: (map['amount'] as num).toInt(),
    type: map['type'] as String,
    title: map['title'] as String,
    referenceId: map['reference_id'] as String?,
    createdAt: DateTime.parse(map['created_at'] as String),
  );
}
