class TransactionModel {
  final int id;
  final int shopId;
  final int customerId;
  final String customerName;
  final int? scanEntryId;
  final double amount;
  final String transactionType; // CREDIT, PAYMENT, ADJUSTMENT
  final DateTime date;
  final String? notes;
  final String? paymentMode;
  final String source; // MANUAL, AI_SCAN
  final DateTime? createdAt;

  TransactionModel({
    required this.id,
    required this.shopId,
    required this.customerId,
    required this.customerName,
    this.scanEntryId,
    required this.amount,
    required this.transactionType,
    required this.date,
    this.notes,
    this.paymentMode,
    required this.source,
    this.createdAt,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json["id"] ?? 0,
      shopId: json["shop_id"] ?? 0,
      customerId: json["customer_id"] ?? 0,
      customerName: json["customer_name"] ?? "Customer",
      scanEntryId: json["scan_entry_id"],
      amount: (json["amount"] as num?)?.toDouble() ?? 0.0,
      transactionType: (json["transaction_type"] ?? "CREDIT").toString().toUpperCase(),
      date: json["date"] != null ? DateTime.parse(json["date"]) : DateTime.now(),
      notes: json["notes"],
      paymentMode: json["payment_mode"],
      source: json["source"] ?? "MANUAL",
      createdAt: json["created_at"] != null ? DateTime.tryParse(json["created_at"]) : null,
    );
  }
}
