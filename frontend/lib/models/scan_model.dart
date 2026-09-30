import 'customer_model.dart';

class ScanEntryModel {
  final int id;
  final int scanId;
  final String extractedCustomerName;
  final double extractedAmount;
  final DateTime? extractedDate;
  final String extractedType;
  final String? rawText;
  final double confidenceCustomerName;
  final double confidenceAmount;
  final double confidenceDate;
  final double confidenceType;
  final double confidenceOverall;
  final String confidenceBand; // HIGH, NEEDS_REVIEW, MANUAL_VERIFICATION
  final bool isDateInferred;
  final String status; // PENDING, CONFIRMED, EDITED_CONFIRMED, REJECTED
  final int? matchedCustomerId;
  final String? matchedCustomerName;
  final List<FuzzyMatchCandidateModel> fuzzySuggestions;
  final String? correctedCustomerName;
  final double? correctedAmount;
  final DateTime? correctedDate;
  final String? correctedType;
  final DateTime? confirmedAt;
  final String? rejectionReason;

  ScanEntryModel({
    required this.id,
    required this.scanId,
    required this.extractedCustomerName,
    required this.extractedAmount,
    this.extractedDate,
    required this.extractedType,
    this.rawText,
    required this.confidenceCustomerName,
    required this.confidenceAmount,
    required this.confidenceDate,
    required this.confidenceType,
    required this.confidenceOverall,
    required this.confidenceBand,
    required this.isDateInferred,
    required this.status,
    this.matchedCustomerId,
    this.matchedCustomerName,
    this.fuzzySuggestions = const [],
    this.correctedCustomerName,
    this.correctedAmount,
    this.correctedDate,
    this.correctedType,
    this.confirmedAt,
    this.rejectionReason,
  });

  bool get isHighConfidence => confidenceBand == "HIGH";
  bool get isPending => status == "PENDING";
  bool get isConfirmed => status == "CONFIRMED" || status == "EDITED_CONFIRMED";

  // Convenience aliases for screens
  String? get customerName => correctedCustomerName ?? (extractedCustomerName.isNotEmpty ? extractedCustomerName : null);
  double? get amount => correctedAmount ?? extractedAmount;
  DateTime? get date => correctedDate ?? extractedDate;
  String? get transactionType => correctedType ?? extractedType;
  double get overallConfidence => confidenceOverall;
  String? get notes => rawText;

  factory ScanEntryModel.fromJson(Map<String, dynamic> json) {
    var fuzzies = <FuzzyMatchCandidateModel>[];
    if (json["fuzzy_suggestions"] != null) {
      for (var f in json["fuzzy_suggestions"]) {
        fuzzies.add(FuzzyMatchCandidateModel.fromJson(f));
      }
    }

    return ScanEntryModel(
      id: json["id"] ?? 0,
      scanId: json["scan_id"] ?? 0,
      extractedCustomerName: json["extracted_customer_name"] ?? "",
      extractedAmount: (json["extracted_amount"] as num?)?.toDouble() ?? 0.0,
      extractedDate: json["extracted_date"] != null ? DateTime.tryParse(json["extracted_date"]) : null,
      extractedType: json["extracted_type"] ?? "CREDIT",
      rawText: json["raw_text"],
      confidenceCustomerName: (json["confidence_customer_name"] as num?)?.toDouble() ?? 0.0,
      confidenceAmount: (json["confidence_amount"] as num?)?.toDouble() ?? 0.0,
      confidenceDate: (json["confidence_date"] as num?)?.toDouble() ?? 0.0,
      confidenceType: (json["confidence_type"] as num?)?.toDouble() ?? 0.0,
      confidenceOverall: (json["confidence_overall"] as num?)?.toDouble() ?? 0.0,
      confidenceBand: json["confidence_band"] ?? "NEEDS_REVIEW",
      isDateInferred: json["is_date_inferred"] ?? false,
      status: json["status"] ?? "PENDING",
      matchedCustomerId: json["matched_customer_id"],
      matchedCustomerName: json["matched_customer_name"],
      fuzzySuggestions: fuzzies,
      correctedCustomerName: json["corrected_customer_name"],
      correctedAmount: (json["corrected_amount"] as num?)?.toDouble(),
      correctedDate: json["corrected_date"] != null ? DateTime.tryParse(json["corrected_date"]) : null,
      correctedType: json["corrected_type"],
      confirmedAt: json["confirmed_at"] != null ? DateTime.tryParse(json["confirmed_at"]) : null,
      rejectionReason: json["rejection_reason"],
    );
  }
}

class ScanModel {
  final int id;
  final int shopId;
  final String originalImageUrl;
  final String? processedImageUrl;
  final String? thumbnailUrl;
  final String status;
  final String? errorMessage;
  final int totalEntries;
  final int confirmedEntries;
  final int highConfidenceEntries;
  final String modelName;
  final int processingTimeMs;
  final DateTime createdAt;
  final List<ScanEntryModel> entries;

  ScanModel({
    required this.id,
    required this.shopId,
    required this.originalImageUrl,
    this.processedImageUrl,
    this.thumbnailUrl,
    required this.status,
    this.errorMessage,
    required this.totalEntries,
    required this.confirmedEntries,
    required this.highConfidenceEntries,
    required this.modelName,
    required this.processingTimeMs,
    required this.createdAt,
    required this.entries,
  });

  String? get imageUrl => processedImageUrl ?? originalImageUrl;

  factory ScanModel.fromJson(Map<String, dynamic> json) {
    var entriesList = <ScanEntryModel>[];
    if (json["entries"] != null) {
      for (var e in json["entries"]) {
        entriesList.add(ScanEntryModel.fromJson(e));
      }
    }

    return ScanModel(
      id: json["id"] ?? 0,
      shopId: json["shop_id"] ?? 0,
      originalImageUrl: json["original_image_url"] ?? "",
      processedImageUrl: json["processed_image_url"],
      thumbnailUrl: json["thumbnail_url"],
      status: json["status"] ?? "PROCESSING",
      errorMessage: json["error_message"],
      totalEntries: json["total_entries"] ?? 0,
      confirmedEntries: json["confirmed_entries"] ?? 0,
      highConfidenceEntries: json["high_confidence_entries"] ?? 0,
      modelName: json["model_name"] ?? "gemini-1.5-flash",
      processingTimeMs: json["processing_time_ms"] ?? 0,
      createdAt: json["created_at"] != null ? DateTime.parse(json["created_at"]) : DateTime.now(),
      entries: entriesList,
    );
  }
}
