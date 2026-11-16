import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
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

  Future<void> fetchSummary({String? filter, int? days}) async {
    final effectiveDays = days ??
        (filter == "today"
            ? 1
            : filter == "30_days"
                ? 30
                : 7);

    final filterRange = effectiveDays == 1
        ? "today"
        : effectiveDays == 30
            ? "30_days"
            : "7_days";

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      dateFilter: "${effectiveDays}_days",
    );

    try {
      final response = await ApiClient.client.get(
        ApiConstants.dashboardSummary,
        queryParameters: {"filter_range": filterRange},
      );

      if (response.data is! Map) {
        throw Exception("Invalid server response.");
      }

      final summary = DashboardSummaryModel.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );

      state = state.copyWith(
        isLoading: false,
        summary: summary,
      );
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage:
            _friendlyError(e, "Failed to load dashboard."),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst("Exception: ", ""),
      );
    }
  }
}

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>(
  (ref) => DashboardNotifier(),
);
