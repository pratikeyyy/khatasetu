import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
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

  String _friendlyError(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map) {
      final detail = data["detail"];
      if (detail is String && detail.isNotEmpty) {
        return detail;
      }
      if (detail is Map && detail["message"] is String) {
        return detail["message"] as String;
      }
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first["msg"] is String) {
          return first["msg"] as String;
        }
      }
    }

    // ApiClient's interceptor already puts a friendly message in e.error.
    final friendly = e.error?.toString();
    if (friendly != null &&
        friendly.isNotEmpty &&
        friendly !=
            "Network error. Please check your internet connection.") {
      return friendly;
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return "Request timed out. Please try again.";
    }

    if (e.type == DioExceptionType.connectionError) {
      return "Cannot connect to the server. Please check your internet.";
    }

    return e.message ?? fallback;
  }

  Future<void> fetchCustomers({String? search, String? sortBy}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final effectiveSearch = search ?? state.searchQuery;
      final effectiveSort = sortBy ?? state.sortBy;

      final response = await ApiClient.client.get(
        ApiConstants.customers,
        queryParameters: {
          if (effectiveSearch.trim().isNotEmpty)
            "search": effectiveSearch.trim(),
          "sort_by": effectiveSort,
        },
      );

      final customers = <CustomerModel>[];
      final data = response.data;
      if (data is List) {
        for (final item in data) {
          if (item is Map) {
            customers.add(
              CustomerModel.fromJson(
                Map<String, dynamic>.from(item),
              ),
            );
          }
        }
      }

      state = state.copyWith(
        isLoading: false,
        customers: customers,
        searchQuery: effectiveSearch,
        sortBy: effectiveSort,
      );
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyError(e, "Failed to load customers."),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst("Exception: ", ""),
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
      final response = await ApiClient.client.post(
        ApiConstants.customers,
        data: {
          "name": name.trim(),
          "phone": phone?.trim(),
          "address": address?.trim(),
          "notes": notes?.trim(),
        },
      );

      if (response.data is! Map) {
        throw Exception("Invalid server response.");
      }

      final customer = CustomerModel.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );

      await fetchCustomers(
        search: state.searchQuery,
        sortBy: state.sortBy,
      );

      return customer;
    } on DioException catch (e) {
      state = state.copyWith(
        errorMessage: _friendlyError(e, "Failed to add customer."),
      );
      return null;
    } catch (e) {
      state = state.copyWith(
        errorMessage: e.toString().replaceFirst("Exception: ", ""),
      );
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
      await ApiClient.client.put(
        "${ApiConstants.customers}$customerId",
        data: {
          "name": name.trim(),
          "phone": phone?.trim(),
          "address": address?.trim(),
          "notes": notes?.trim(),
        },
      );

      await fetchCustomers(
        search: state.searchQuery,
        sortBy: state.sortBy,
      );

      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        errorMessage: _friendlyError(e, "Failed to update customer."),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        errorMessage: e.toString().replaceFirst("Exception: ", ""),
      );
      return false;
    }
  }

  Future<void> deleteCustomer(int customerId) async {
    try {
      await ApiClient.client.delete(
        "${ApiConstants.customers}$customerId",
      );

      await fetchCustomers(
        search: state.searchQuery,
        sortBy: state.sortBy,
      );
    } on DioException catch (e) {
      state = state.copyWith(
        errorMessage: _friendlyError(e, "Failed to delete customer."),
      );
    } catch (e) {
      state = state.copyWith(
        errorMessage: e.toString().replaceFirst("Exception: ", ""),
      );
    }
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

  String _friendlyError(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map) {
      final detail = data["detail"];
      if (detail is String && detail.isNotEmpty) {
        return detail;
      }
      if (detail is Map && detail["message"] is String) {
        return detail["message"] as String;
      }
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first["msg"] is String) {
          return first["msg"] as String;
        }
      }
    }

    final friendly = e.error?.toString();
    if (friendly != null &&
        friendly.isNotEmpty &&
        friendly !=
            "Network error. Please check your internet connection.") {
      return friendly;
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return "Request timed out. Please try again.";
    }

    if (e.type == DioExceptionType.connectionError) {
      return "Cannot connect to the server. Please check your internet.";
    }

    return e.message ?? fallback;
  }

  Future<void> fetchDetail(int id) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
    );

    try {
      final response = await ApiClient.client.get(
        "${ApiConstants.customers}$id",
      );

      if (response.data is! Map) {
        throw Exception("Invalid server response.");
      }

      final customer = CustomerModel.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );

      state = state.copyWith(
        isLoading: false,
        customer: customer,
        totalCredit: customer.totalCredit,
        totalPayment: customer.totalPayment,
      );
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage:
            _friendlyError(e, "Failed to load customer details."),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst("Exception: ", ""),
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
