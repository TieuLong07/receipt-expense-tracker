// ponytail: Domain model for Receipt and line items; add barcode/SKU fields when POS inventory sync is needed.

import 'dart:convert';

class ReceiptItem {
  final String name;
  final double quantity;
  final double unitPrice;
  final double totalPrice;

  const ReceiptItem({
    required this.name,
    this.quantity = 1.0,
    this.unitPrice = 0.0,
    required this.totalPrice,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
    };
  }

  factory ReceiptItem.fromMap(Map<String, dynamic> map) {
    return ReceiptItem(
      name: (map['name'] as String?) ?? 'Unknown Item',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (map['total_price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  ReceiptItem copyWith({
    String? name,
    double? quantity,
    double? unitPrice,
    double? totalPrice,
  }) {
    return ReceiptItem(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
    );
  }
}

class Receipt {
  final int? id;
  final String merchant;
  final double amount;
  final DateTime date;
  final String category;
  final String? imagePath;
  final String? rawOcrText;
  final List<ReceiptItem> items;
  final String syncStatus; // 'pending_sync' | 'synced'
  final DateTime createdAt;

  const Receipt({
    this.id,
    required this.merchant,
    required this.amount,
    required this.date,
    required this.category,
    this.imagePath,
    this.rawOcrText,
    this.items = const [],
    this.syncStatus = 'pending_sync',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? date;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'merchant': merchant,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category,
      'image_path': imagePath,
      'raw_ocr_text': rawOcrText,
      'items_json': jsonEncode(items.map((i) => i.toMap()).toList()),
      'sync_status': syncStatus,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Receipt.fromMap(Map<String, dynamic> map) {
    List<ReceiptItem> parsedItems = [];
    final itemsRaw = map['items_json'];
    if (itemsRaw is String && itemsRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(itemsRaw);
        if (decoded is List) {
          parsedItems = decoded.map((e) => ReceiptItem.fromMap(e as Map<String, dynamic>)).toList();
        }
      } catch (_) {}
    }

    return Receipt(
      id: map['id'] as int?,
      merchant: (map['merchant'] as String?) ?? 'Unknown Merchant',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      category: (map['category'] as String?) ?? 'Other',
      imagePath: map['image_path'] as String?,
      rawOcrText: map['raw_ocr_text'] as String?,
      items: parsedItems,
      syncStatus: (map['sync_status'] as String?) ?? 'pending_sync',
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Receipt copyWith({
    int? id,
    String? merchant,
    double? amount,
    DateTime? date,
    String? category,
    String? imagePath,
    String? rawOcrText,
    List<ReceiptItem>? items,
    String? syncStatus,
    DateTime? createdAt,
  }) {
    return Receipt(
      id: id ?? this.id,
      merchant: merchant ?? this.merchant,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      category: category ?? this.category,
      imagePath: imagePath ?? this.imagePath,
      rawOcrText: rawOcrText ?? this.rawOcrText,
      items: items ?? this.items,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
