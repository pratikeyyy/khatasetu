import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/local_database.dart';
import '../core/storage/local_storage.dart';
import '../models/customer_model.dart';

class CustomerState {
  final bool isLoading;
  final List<CustomerModel> customers;
  final String? errorMessage;
  final String searchQuery;
  final String sortBy;

  CustomerState({
    this.isLoading = false,
    this.customers = const [],
    this.errorMessage,
    this.searchQuery = "",
    this.sortBy = "name",
  });

  CustomerState copyWith({
    bool? isLoading,
    List<CustomerModel>? customers,
    String? errorMessage,
    String? searchQuery,
    String? sortBy,
  }) {
    return CustomerState(
      isLoading: isLoading ?? this.isLoading,
      customers: customers ?? this.customers,
      errorMessage: errorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
      sortBy: sortBy ?? this.sortBy,
    );
  }
}

class CustomerNotifier extends StateNotifier<CustomerState> {
  CustomerNotifier() : super(CustomerState()) {
    fetchCustomers();
  }

  Future<void> fetchCustomers({String? search, String? sortBy}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final db = await LocalDatabase.database;
      final session = await LocalStorage.getUserSession();
      final shopId = session?["shop_id"] ?? 0;

      final effectiveSearch = search ?? state.searchQuery;
      final effectiveSort = sortBy ?? state.sortBy;

      String where = "shop_id = ?";
      List<Object?> whereArgs = [shopId];

      if (effectiveSearch.trim().isNotEmpty) {
        where +=
            " AND (name LIKE ? OR normalized_name LIKE ? OR phone LIKE ?)";
        final q = "%${effectiveSearch.trim().toLowerCase()}%";
        whereArgs.addAll([q, q, q]);
      }

      String orderBy;

      switch (effectiveSort) {
        case "balance_desc":
          orderBy = "credit_balance DESC";
          break;
        case "balance_asc":
          orderBy = "credit_balance ASC";
          break;
        case "recent":
          orderBy = "updated_at DESC";
          break;
        default:
          orderBy = "name COLLATE NOCASE ASC";
      }

      final rows = await db.query(
        "customers",
        where: where,
        whereArgs: whereArgs,
        orderBy: orderBy,
      );

      final customers =
          rows.map((row) => _customerFromRow(row)).toList();

      state = state.copyWith(
        isLoading: false,
        customers: customers,
        searchQuery: effectiveSearch,
        sortBy: effectiveSort,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> searchCustomers(String query) async {
    await fetchCustomers(search: query);
  }

  Future<void> sortCustomers(String sort) async {
    await fetchCustomers(sortBy: sort);
  }

  Future<CustomerModel?> addCustomer({
    required String name,
    String? phone,
    String? address,
    String? notes,
  }) async {
    try {
      final db = await LocalDatabase.database;
      final session = await LocalStorage.getUserSession();
      final shopId = session?["shop_id"] ?? 0;

      final now = DateTime.now();
      final cleanName = name.trim();
      final normalizedName = cleanName.toLowerCase();

      final existing = await db.query(
        "customers",
        where: "shop_id = ? AND normalized_name = ? AND is_active = 1",
        whereArgs: [shopId, normalizedName],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        return _customerFromRow(existing.first);
      }

      final id = DateTime.now().microsecondsSinceEpoch;

      await db.insert("customers", {
        "id": id,
        "shop_id": shopId,
        "name": cleanName,
        "normalized_name": normalizedName,
        "phone": phone?.trim(),
        "address": address?.trim(),
        "notes": notes?.trim(),
        "credit_balance": 0.0,
        "total_credit": 0.0,
        "total_payment": 0.0,
        "is_active": 1,
        "created_at": now.toIso8601String(),
        "updated_at": now.toIso8601String(),
        "transaction_count": 0,
      });

      final customer = await _getCustomerById(id);

      if (customer != null) {
        await fetchCustomers(
          search: state.searchQuery,
          sortBy: state.sortBy,
        );
      }

      return customer;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return null;
    }
  }

  Future<bool> updateCustomer({
    required int customerId,
    required String name,
    String? phone,
    String? address,
    String? notes,
  }) async {
    try {
      final db = await LocalDatabase.database;

      await db.update(
        "customers",
        {
          "name": name.trim(),
          "normalized_name": name.trim().toLowerCase(),
          "phone": phone?.trim(),
          "address": address?.trim(),
          "notes": notes?.trim(),
          "updated_at": DateTime.now().toIso8601String(),
        },
        where: "id = ?",
        whereArgs: [customerId],
      );

      await fetchCustomers(
        search: state.searchQuery,
        sortBy: state.sortBy,
      );

      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<void> deleteCustomer(int customerId) async {
    final db = await LocalDatabase.database;

    await db.update(
      "customers",
      {
        "is_active": 0,
        "updated_at": DateTime.now().toIso8601String(),
      },
      where: "id = ?",
      whereArgs: [customerId],
    );

    await fetchCustomers(
      search: state.searchQuery,
      sortBy: state.sortBy,
    );
  }

  Future<CustomerModel?> _getCustomerById(int id) async {
    final db = await LocalDatabase.database;

    final rows = await db.query(
      "customers",
      where: "id = ?",
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    return _customerFromRow(rows.first);
  }

  CustomerModel _customerFromRow(Map<String, Object?> row) {
    return CustomerModel(
      id: row["id"] as int,
      shopId: row["shop_id"] as int,
      name: row["name"] as String,
      normalizedName: row["normalized_name"] as String,
      phone: row["phone"] as String?,
      address: row["address"] as String?,
      notes: row["notes"] as String?,
      creditBalance: (row["credit_balance"] as num).toDouble(),
      totalCredit: (row["total_credit"] as num).toDouble(),
      totalPayment: (row["total_payment"] as num).toDouble(),
      isActive: (row["is_active"] as int) == 1,
      createdAt: row["created_at"] != null
          ? DateTime.tryParse(row["created_at"] as String)
          : null,
      updatedAt: row["updated_at"] != null
          ? DateTime.tryParse(row["updated_at"] as String)
          : null,
      transactionCount: row["transaction_count"] as int? ?? 0,
    );
  }
}

class CustomerDetailState {
  final bool isLoading;
  final CustomerModel? customer;
  final double totalCredit;
  final double totalPayment;
  final String? errorMessage;

  CustomerDetailState({
    this.isLoading = false,
    this.customer,
    this.totalCredit = 0.0,
    this.totalPayment = 0.0,
    this.errorMessage,
  });

  CustomerDetailState copyWith({
    bool? isLoading,
    CustomerModel? customer,
    double? totalCredit,
    double? totalPayment,
    String? errorMessage,
  }) {
    return CustomerDetailState(
      isLoading: isLoading ?? this.isLoading,
      customer: customer ?? this.customer,
      totalCredit: totalCredit ?? this.totalCredit,
      totalPayment: totalPayment ?? this.totalPayment,
      errorMessage: errorMessage,
    );
  }
}

class CustomerDetailNotifier
    extends StateNotifier<CustomerDetailState> {
  final int customerId;

  CustomerDetailNotifier(this.customerId)
      : super(CustomerDetailState()) {
    fetchDetail(customerId);
  }

  Future<void> fetchDetail(int id) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
    );

    try {
      final db = await LocalDatabase.database;

      final rows = await db.query(
        "customers",
        where: "id = ?",
        whereArgs: [id],
        limit: 1,
      );

      if (rows.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: "Customer not found",
        );
        return;
      }

      final row = rows.first;

      final customer = CustomerModel(
        id: row["id"] as int,
        shopId: row["shop_id"] as int,
        name: row["name"] as String,
        normalizedName: row["normalized_name"] as String,
        phone: row["phone"] as String?,
        address: row["address"] as String?,
        notes: row["notes"] as String?,
        creditBalance: (row["credit_balance"] as num).toDouble(),
        totalCredit: (row["total_credit"] as num).toDouble(),
        totalPayment: (row["total_payment"] as num).toDouble(),
        isActive: (row["is_active"] as int) == 1,
        createdAt: row["created_at"] != null
            ? DateTime.tryParse(row["created_at"] as String)
            : null,
        updatedAt: row["updated_at"] != null
            ? DateTime.tryParse(row["updated_at"] as String)
            : null,
        transactionCount: row["transaction_count"] as int? ?? 0,
      );

      state = state.copyWith(
        isLoading: false,
        customer: customer,
        totalCredit: customer.totalCredit,
        totalPayment: customer.totalPayment,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }
}

final customerProvider =
    StateNotifierProvider<CustomerNotifier, CustomerState>(
  (ref) => CustomerNotifier(),
);

final customerDetailProvider =
    StateNotifierProvider.family<
        CustomerDetailNotifier,
        CustomerDetailState,
        int>(
  (ref, customerId) => CustomerDetailNotifier(customerId),
);