import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/local_database.dart';
import '../core/storage/local_storage.dart';
import '../models/dashboard_model.dart';

class DashboardState {
  final bool isLoading;
  final DashboardSummaryModel? summary;
  final String dateFilter;
  final String? errorMessage;

  DashboardState({
    this.isLoading = false,
    this.summary,
    this.dateFilter = "7_days",
    this.errorMessage,
  });

  DashboardState copyWith({
    bool? isLoading,
    DashboardSummaryModel? summary,
    String? dateFilter,
    String? errorMessage,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      summary: summary ?? this.summary,
      dateFilter: dateFilter ?? this.dateFilter,
      errorMessage: errorMessage,
    );
  }
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  DashboardNotifier() : super(DashboardState()) {
    fetchSummary();
  }

  Future<void> fetchSummary({String? filter, int? days}) async {
    final effectiveDays = days ??
        (filter == "today"
            ? 1
            : filter == "30_days"
                ? 30
                : 7);

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      dateFilter: "${effectiveDays}_days",
    );

    try {
      final db = await LocalDatabase.database;
      final session = await LocalStorage.getUserSession();
      final shopId = session?["shop_id"] ?? 0;

      final customers = await db.query(
        "customers",
        where: "shop_id = ? AND is_active = 1",
        whereArgs: [shopId],
      );

      final transactions = await db.query(
        "transactions",
        where: "shop_id = ?",
        whereArgs: [shopId],
        orderBy: "date DESC",
      );

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final rangeStart =
          todayStart.subtract(Duration(days: effectiveDays - 1));

      double totalOutstanding = 0;
      double todayCredit = 0;
      double todayPayment = 0;

      for (final customer in customers) {
        totalOutstanding +=
            (customer["credit_balance"] as num?)?.toDouble() ?? 0;
      }

      final recent = <RecentTransactionItemModel>[];

      final daily = <String, Map<String, double>>{};

      for (final tx in transactions) {
        final date = DateTime.parse(tx["date"] as String);

        final amount = (tx["amount"] as num?)?.toDouble() ?? 0;
        final type = tx["transaction_type"] as String;
        final customerName = tx["customer_name"] as String;

        if (date.year == now.year &&
            date.month == now.month &&
            date.day == now.day) {
          if (type == "CREDIT") {
            todayCredit += amount;
          } else if (type == "PAYMENT") {
            todayPayment += amount;
          }
        }

        if (!date.isBefore(rangeStart)) {
          final key =
              "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

          daily.putIfAbsent(
            key,
            () => {
              "credit": 0,
              "payment": 0,
            },
          );

          if (type == "CREDIT") {
            daily[key]!["credit"] =
                daily[key]!["credit"]! + amount;
          } else if (type == "PAYMENT") {
            daily[key]!["payment"] =
                daily[key]!["payment"]! + amount;
          }
        }

        if (recent.length < 10) {
          recent.add(
            RecentTransactionItemModel(
              id: tx["id"] as int,
              customerId: tx["customer_id"] as int,
              customerName: customerName,
              amount: amount,
              transactionType: type,
              date: date,
              source: tx["source"] as String,
            ),
          );
        }
      }

      final chart = daily.entries.map((entry) {
        final credit = entry.value["credit"] ?? 0;
        final payment = entry.value["payment"] ?? 0;

        return ChartDataPointModel(
          label: entry.key.substring(5),
          credit: credit,
          payment: payment,
          net: credit - payment,
        );
      }).toList();

      final summary = DashboardSummaryModel(
        totalOutstanding: totalOutstanding,
        todayCredit: todayCredit,
        todayPayment: todayPayment,
        totalCustomers: customers.length,
        totalScans: 0,
        pendingReviewsCount: 0,
        recentTransactions: recent,
        pendingReviews: const [],
        trendChart: chart,
      );

      state = state.copyWith(
        isLoading: false,
        summary: summary,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }
}

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>(
  (ref) => DashboardNotifier(),
);