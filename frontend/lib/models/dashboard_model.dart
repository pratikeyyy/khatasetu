class ChartDataPointModel {
  final String label;
  final double credit;
  final double payment;
  final double net;

  ChartDataPointModel({
    required this.label,
    required this.credit,
    required this.payment,
    required this.net,
  });

  factory ChartDataPointModel.fromJson(Map<String, dynamic> json) {
    return ChartDataPointModel(
      label: json["label"] ?? "",
      credit: (json["credit"] as num?)?.toDouble() ?? 0.0,
      payment: (json["payment"] as num?)?.toDouble() ?? 0.0,
      net: (json["net"] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class RecentTransactionItemModel {
  final int id;
  final int customerId;
  final String customerName;
  final double amount;
  final String transactionType;
  final DateTime date;
  final String source;

  RecentTransactionItemModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.amount,
    required this.transactionType,
    required this.date,
    required this.source,
  });

  factory RecentTransactionItemModel.fromJson(Map<String, dynamic> json) {
    return RecentTransactionItemModel(
      id: json["id"] ?? 0,
      customerId: json["customer_id"] ?? 0,
      customerName: json["customer_name"] ?? "Customer",
      amount: (json["amount"] as num?)?.toDouble() ?? 0.0,
      transactionType: json["transaction_type"] ?? "CREDIT",
      date: json["date"] != null ? DateTime.parse(json["date"]) : DateTime.now(),
      source: json["source"] ?? "MANUAL",
    );
  }
}

class PendingReviewItemModel {
  final int entryId;
  final int scanId;
  final String customerName;
  final double amount;
  final double confidenceOverall;
  final String confidenceBand;
  final DateTime? date;

  PendingReviewItemModel({
    required this.entryId,
    required this.scanId,
    required this.customerName,
    required this.amount,
    required this.confidenceOverall,
    required this.confidenceBand,
    this.date,
  });

  factory PendingReviewItemModel.fromJson(Map<String, dynamic> json) {
    return PendingReviewItemModel(
      entryId: json["entry_id"] ?? 0,
      scanId: json["scan_id"] ?? 0,
      customerName: json["customer_name"] ?? "",
      amount: (json["amount"] as num?)?.toDouble() ?? 0.0,
      confidenceOverall: (json["confidence_overall"] as num?)?.toDouble() ?? 0.0,
      confidenceBand: json["confidence_band"] ?? "NEEDS_REVIEW",
      date: json["date"] != null ? DateTime.tryParse(json["date"]) : null,
    );
  }
}

class DashboardSummaryModel {
  final double totalOutstanding;
  final double todayCredit;
  final double todayPayment;
  final int totalCustomers;
  final int totalScans;
  final int pendingReviewsCount;
  final List<RecentTransactionItemModel> recentTransactions;
  final List<PendingReviewItemModel> pendingReviews;
  final List<ChartDataPointModel> trendChart;

  DashboardSummaryModel({
    required this.totalOutstanding,
    required this.todayCredit,
    required this.todayPayment,
    required this.totalCustomers,
    required this.totalScans,
    required this.pendingReviewsCount,
    required this.recentTransactions,
    required this.pendingReviews,
    required this.trendChart,
  });

  factory DashboardSummaryModel.fromJson(Map<String, dynamic> json) {
    var recents = <RecentTransactionItemModel>[];
    if (json["recent_transactions"] != null) {
      for (var r in json["recent_transactions"]) {
        recents.add(RecentTransactionItemModel.fromJson(r));
      }
    }

    var pendings = <PendingReviewItemModel>[];
    if (json["pending_reviews"] != null) {
      for (var p in json["pending_reviews"]) {
        pendings.add(PendingReviewItemModel.fromJson(p));
      }
    }

    var charts = <ChartDataPointModel>[];
    if (json["trend_chart"] != null) {
      for (var c in json["trend_chart"]) {
        charts.add(ChartDataPointModel.fromJson(c));
      }
    }

    return DashboardSummaryModel(
      totalOutstanding: (json["total_outstanding"] as num?)?.toDouble() ?? 0.0,
      todayCredit: (json["today_credit"] as num?)?.toDouble() ?? 0.0,
      todayPayment: (json["today_payment"] as num?)?.toDouble() ?? 0.0,
      totalCustomers: json["total_customers"] ?? 0,
      totalScans: json["total_scans"] ?? 0,
      pendingReviewsCount: json["pending_reviews_count"] ?? 0,
      recentTransactions: recents,
      pendingReviews: pendings,
      trendChart: charts,
    );
  }
}
