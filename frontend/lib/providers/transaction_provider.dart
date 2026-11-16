import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/customer_model.dart';
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

  Future<void> fetchTransactions({
    int? customerId,
    String? transactionType,
    String? source,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final response = await ApiClient.client.get(
        ApiConstants.transactions,
        queryParameters: {
          if (customerId != null) "customer_id": customerId,
          if (transactionType != null && transactionType.isNotEmpty)
            "transaction_type": transactionType.toUpperCase(),
          if (source != null && source.isNotEmpty)
            "source": source.toUpperCase(),
          "limit": 100,
        },
      );

      final list = <TransactionModel>[];
      final data = response.data;
      if (data is List) {
        for (final item in data) {
          if (item is Map) {
            list.add(
              TransactionModel.fromJson(
                Map<String, dynamic>.from(item),
              ),
            );
          }
        }
      }

      state = state.copyWith(
        isLoading: false,
        transactions: list,
        typeFilter: transactionType,
        sourceFilter: source,
      );
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage:
            _friendlyError(e, "Failed to load transactions."),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst("Exception: ", ""),
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
      final response = await ApiClient.client.post(
        ApiConstants.checkDuplicate,
        data: {
          "customer_id": customerId,
          "amount": amount,
          "transaction_type": transactionType.toUpperCase(),
          if (date != null) "date": date.toIso8601String(),
        },
      );

      final data = response.data;
      if (data is Map) {
        return data["is_possible_duplicate"] == true;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> addTransaction({
    int? customerId,
    String? manualCustomerName,
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
      // Manual transactions may arrive with a name but no selected customer.
      // Reuse an existing customer by exact name; otherwise create it
      // through the API first, then post the transaction with that id.
      int? resolvedCustomerId = customerId;
      if (resolvedCustomerId == null) {
        final cleanName = manualCustomerName?.trim() ?? "";
        if (cleanName.isEmpty) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: "Please enter a customer name.",
          );
          return false;
        }

        final searchResponse = await ApiClient.client.get(
          ApiConstants.customers,
          queryParameters: {"search": cleanName},
        );

        final searchData = searchResponse.data;
        if (searchData is List) {
          for (final item in searchData) {
            if (item is Map) {
              final found = CustomerModel.fromJson(
                Map<String, dynamic>.from(item),
              );
              if (found.name.trim().toLowerCase() ==
                  cleanName.toLowerCase()) {
                resolvedCustomerId = found.id;
                break;
              }
            }
          }
        }

        if (resolvedCustomerId == null) {
          final createResponse = await ApiClient.client.post(
            ApiConstants.customers,
            data: {"name": cleanName},
          );

          if (createResponse.data is! Map) {
            throw Exception("Customer could not be created.");
          }

          final created = CustomerModel.fromJson(
            Map<String, dynamic>.from(createResponse.data as Map),
          );
          resolvedCustomerId = created.id;
        }
      }

      final txDate = date ?? DateTime.now();
      final normalizedType = transactionType.toUpperCase();

      // The backend checks for duplicates itself and returns 409 unless
      // force is true, so no separate pre-check is needed here.
      final response = await ApiClient.client.post(
        ApiConstants.transactions,
        queryParameters: {"force": force},
        data: {
          "customer_id": resolvedCustomerId,
          "amount": amount,
          "transaction_type": normalizedType,
          "date": txDate.toIso8601String(),
          "notes": notes?.trim(),
          "payment_mode": paymentMode,
        },
      );

      if (response.data is! Map) {
        throw Exception("Invalid server response.");
      }

      final newTx = TransactionModel.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );

      state = state.copyWith(
        isLoading: false,
        transactions: [newTx, ...state.transactions],
      );

      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage:
            _friendlyError(e, "Failed to add transaction."),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst("Exception: ", ""),
      );
      return false;
    }
  }
}

final transactionProvider =
    StateNotifierProvider<TransactionNotifier, TransactionState>(
  (ref) => TransactionNotifier(),
);
