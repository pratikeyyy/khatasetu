import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/local_database.dart';
import '../core/storage/local_storage.dart';
import '../models/transaction_model.dart';

class TransactionState {
  final bool isLoading;
  final List<TransactionModel> transactions;
  final String? errorMessage;
  final String? typeFilter;
  final String? sourceFilter;

  TransactionState({
    this.isLoading = false,
    this.transactions = const [],
    this.errorMessage,
    this.typeFilter,
    this.sourceFilter,
  });

  TransactionState copyWith({
    bool? isLoading,
    List<TransactionModel>? transactions,
    String? errorMessage,
    String? typeFilter,
    String? sourceFilter,
  }) {
    return TransactionState(
      isLoading: isLoading ?? this.isLoading,
      transactions: transactions ?? this.transactions,
      errorMessage: errorMessage,
      typeFilter: typeFilter ?? this.typeFilter,
      sourceFilter: sourceFilter ?? this.sourceFilter,
    );
  }
}

class TransactionNotifier extends StateNotifier<TransactionState> {
  TransactionNotifier() : super(TransactionState()) {
    fetchTransactions();
  }

  Future<void> fetchTransactions({
    int? customerId,
    String? transactionType,
    String? source,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final db = await LocalDatabase.database;
      final session = await LocalStorage.getUserSession();
      final shopId = session?["shop_id"] ?? 0;

      String where = "shop_id = ?";
      final List<Object?> args = [shopId];

      if (customerId != null) {
        where += " AND customer_id = ?";
        args.add(customerId);
      }

      if (transactionType != null && transactionType.isNotEmpty) {
        where += " AND transaction_type = ?";
        args.add(transactionType.toUpperCase());
      }

      if (source != null && source.isNotEmpty) {
        where += " AND source = ?";
        args.add(source.toUpperCase());
      }

      final rows = await db.query(
        "transactions",
        where: where,
        whereArgs: args,
        orderBy: "date DESC, id DESC",
      );

      final list = rows.map(_transactionFromRow).toList();

      state = state.copyWith(
        isLoading: false,
        transactions: list,
        typeFilter: transactionType,
        sourceFilter: source,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<bool> checkDuplicate({
    required int customerId,
    required double amount,
    required String transactionType,
    DateTime? date,
  }) async {
    try {
      final db = await LocalDatabase.database;
      final session = await LocalStorage.getUserSession();
      final shopId = session?["shop_id"] ?? 0;

      String where =
          "shop_id = ? AND customer_id = ? AND amount = ? AND transaction_type = ?";
      final List<Object?> args = [
        shopId,
        customerId,
        amount,
        transactionType.toUpperCase(),
      ];

      if (date != null) {
        final start = DateTime(date.year, date.month, date.day);
        final end = start.add(const Duration(days: 1));

        where += " AND date >= ? AND date < ?";
        args.add(start.toIso8601String());
        args.add(end.toIso8601String());
      }

      final rows = await db.query(
        "transactions",
        where: where,
        whereArgs: args,
        limit: 1,
      );

      return rows.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> addTransaction({
    required int customerId,
    required double amount,
    required String transactionType,
    String? notes,
    String? paymentMode,
    DateTime? date,
    bool force = false,
  }) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
    );

    try {
      final db = await LocalDatabase.database;
      final session = await LocalStorage.getUserSession();
      final shopId = session?["shop_id"] ?? 0;

      final txDate = date ?? DateTime.now();
      final normalizedType = transactionType.toUpperCase();

      if (!force) {
        final duplicate = await checkDuplicate(
          customerId: customerId,
          amount: amount,
          transactionType: normalizedType,
          date: txDate,
        );

        if (duplicate) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: "Possible duplicate transaction detected.",
          );
          return false;
        }
      }

      final customerRows = await db.query(
        "customers",
        where: "id = ? AND shop_id = ?",
        whereArgs: [customerId, shopId],
        limit: 1,
      );

      if (customerRows.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: "Customer not found.",
        );
        return false;
      }

      final customer = customerRows.first;
      final customerName = customer["name"] as String;

      final currentBalance =
          (customer["credit_balance"] as num?)?.toDouble() ?? 0.0;

      final currentCredit =
          (customer["total_credit"] as num?)?.toDouble() ?? 0.0;

      final currentPayment =
          (customer["total_payment"] as num?)?.toDouble() ?? 0.0;

      double newBalance = currentBalance;
      double newCredit = currentCredit;
      double newPayment = currentPayment;

      if (normalizedType == "CREDIT") {
        newBalance += amount;
        newCredit += amount;
      } else if (normalizedType == "PAYMENT") {
        newBalance -= amount;
        newPayment += amount;
      }

      final id = DateTime.now().microsecondsSinceEpoch;

      await db.transaction((txn) async {
        await txn.insert("transactions", {
          "id": id,
          "shop_id": shopId,
          "customer_id": customerId,
          "customer_name": customerName,
          "scan_entry_id": null,
          "amount": amount,
          "transaction_type": normalizedType,
          "date": txDate.toIso8601String(),
          "notes": notes,
          "payment_mode": paymentMode,
          "source": "MANUAL",
          "created_at": DateTime.now().toIso8601String(),
        });

        await txn.update(
          "customers",
          {
            "credit_balance": newBalance,
            "total_credit": newCredit,
            "total_payment": newPayment,
            "transaction_count":
                (customer["transaction_count"] as int? ?? 0) + 1,
            "updated_at": DateTime.now().toIso8601String(),
          },
          where: "id = ?",
          whereArgs: [customerId],
        );
      });

      final newTx = TransactionModel(
        id: id,
        shopId: shopId,
        customerId: customerId,
        customerName: customerName,
        scanEntryId: null,
        amount: amount,
        transactionType: normalizedType,
        date: txDate,
        notes: notes,
        paymentMode: paymentMode,
        source: "MANUAL",
        createdAt: DateTime.now(),
      );

      state = state.copyWith(
        isLoading: false,
        transactions: [newTx, ...state.transactions],
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  TransactionModel _transactionFromRow(Map<String, Object?> row) {
    return TransactionModel(
      id: row["id"] as int,
      shopId: row["shop_id"] as int,
      customerId: row["customer_id"] as int,
      customerName: row["customer_name"] as String,
      scanEntryId: row["scan_entry_id"] as int?,
      amount: (row["amount"] as num).toDouble(),
      transactionType: row["transaction_type"] as String,
      date: DateTime.parse(row["date"] as String),
      notes: row["notes"] as String?,
      paymentMode: row["payment_mode"] as String?,
      source: row["source"] as String,
      createdAt: row["created_at"] != null
          ? DateTime.tryParse(row["created_at"] as String)
          : null,
    );
  }
}

final transactionProvider =
    StateNotifierProvider<TransactionNotifier, TransactionState>(
  (ref) => TransactionNotifier(),
);