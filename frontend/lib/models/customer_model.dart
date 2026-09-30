class CustomerModel {
  final int id;
  final int shopId;
  final String name;
  final String normalizedName;
  final String? phone;
  final String? address;
  final String? notes;
  final double creditBalance;
  final double totalCredit;
  final double totalPayment;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int transactionCount;

  CustomerModel({
    required this.id,
    required this.shopId,
    required this.name,
    required this.normalizedName,
    this.phone,
    this.address,
    this.notes,
    required this.creditBalance,
    required this.totalCredit,
    required this.totalPayment,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
    this.transactionCount = 0,
  });

  double get balance => creditBalance;

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json["id"] ?? 0,
      shopId: json["shop_id"] ?? 0,
      name: json["name"] ?? "",
      normalizedName: json["normalized_name"] ?? "",
      phone: json["phone"],
      address: json["address"],
      notes: json["notes"],
      creditBalance: (json["credit_balance"] as num?)?.toDouble() ?? 0.0,
      totalCredit: (json["total_credit"] as num?)?.toDouble() ?? 0.0,
      totalPayment: (json["total_payment"] as num?)?.toDouble() ?? 0.0,
      isActive: json["is_active"] ?? true,
      createdAt: json["created_at"] != null ? DateTime.tryParse(json["created_at"]) : null,
      updatedAt: json["updated_at"] != null ? DateTime.tryParse(json["updated_at"]) : null,
      transactionCount: json["transaction_count"] ?? 0,
    );
  }
}

class FuzzyMatchCandidateModel {
  final int customerId;
  final String customerName;
  final String? phone;
  final double similarityScore;
  final double currentBalance;
  final String matchReason;

  FuzzyMatchCandidateModel({
    required this.customerId,
    required this.customerName,
    this.phone,
    required this.similarityScore,
    required this.currentBalance,
    required this.matchReason,
  });

  factory FuzzyMatchCandidateModel.fromJson(Map<String, dynamic> json) {
    return FuzzyMatchCandidateModel(
      customerId: json["customer_id"] ?? 0,
      customerName: json["customer_name"] ?? "",
      phone: json["phone"],
      similarityScore: (json["similarity_score"] as num?)?.toDouble() ?? 0.0,
      currentBalance: (json["current_balance"] as num?)?.toDouble() ?? 0.0,
      matchReason: json["match_reason"] ?? "",
    );
  }
}
