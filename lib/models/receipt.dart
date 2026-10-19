// ponytail: Simple flat model; add nested line items when multi-item split billing is required.

class Receipt {
  final int? id;
  final String merchant;
  final double amount;
  final DateTime date;
  final String category;
  final String? imagePath;
  final String? rawOcrText;
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
      'sync_status': syncStatus,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Receipt.fromMap(Map<String, dynamic> map) {
    return Receipt(
      id: map['id'] as int?,
      merchant: (map['merchant'] as String?) ?? 'Unknown Merchant',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      category: (map['category'] as String?) ?? 'Other',
      imagePath: map['image_path'] as String?,
      rawOcrText: map['raw_ocr_text'] as String?,
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
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
