import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../storage/local_storage.dart';

class ApiClient {
  static Dio? _dioInstance;

  static Dio get client {
    if (_dioInstance != null) return _dioInstance!;

    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          "Accept": "application/json",
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await LocalStorage.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers["Authorization"] = "Bearer $token";
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) {
          String userFriendlyMessage = "Network error. Please check your internet connection.";

          if (error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout) {
            userFriendlyMessage = "Request timed out. Please try again.";
          } else if (error.response != null) {
            final data = error.response?.data;
            if (data is Map<String, dynamic> && data.containsKey("detail")) {
              final detail = data["detail"];
              if (detail is String) {
                userFriendlyMessage = detail;
              } else if (detail is Map && detail.containsKey("message")) {
                userFriendlyMessage = detail["message"];
              }
            } else if (error.response?.statusCode == 401) {
              userFriendlyMessage = "Session expired. Please log in again.";
            } else if (error.response?.statusCode == 404) {
              userFriendlyMessage = "The requested resource was not found.";
            } else if (error.response?.statusCode == 500) {
              userFriendlyMessage = "Server encountered an error. Please try again shortly.";
            }
          }

          final customError = DioException(
            requestOptions: error.requestOptions,
            response: error.response,
            type: error.type,
            error: userFriendlyMessage,
          );
          return handler.next(customError);
        },
      ),
    );

    _dioInstance = dio;
    return dio;
  }
}
