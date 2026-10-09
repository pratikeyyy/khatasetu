import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../core/network/api_client.dart';
import '../core/storage/local_storage.dart';
import '../core/constants/api_constants.dart';

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final Map<String, dynamic>? user;
  final Map<String, dynamic>? shop;
  final String upiId;
  final String? errorMessage;

  const AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.user,
    this.shop,
    this.upiId = "",
    this.errorMessage,
  });

  String get ownerName =>
      user?["full_name"]?.toString() ?? "Shopkeeper";

  String get email =>
      user?["email"]?.toString() ?? "";

  String get phone =>
      user?["phone"]?.toString() ?? "";

  String get shopName =>
      shop?["name"]?.toString() ?? "My Khata";

  String get shopPhone =>
      shop?["phone"]?.toString() ?? "";

  String get address =>
      shop?["address"]?.toString() ?? "";

  String get gstin =>
      shop?["gstin"]?.toString() ?? "";

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    Map<String, dynamic>? user,
    Map<String, dynamic>? shop,
    String? upiId,
    String? errorMessage,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      shop: shop ?? this.shop,
      upiId: upiId ?? this.upiId,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  // ============================================================
  // SERVER DATA
  // ============================================================

  void _applyServerData(Map<String, dynamic> data) {
    final userData = data["user"];
    final shopData = data["shop"];

    final user = userData is Map
        ? Map<String, dynamic>.from(userData)
        : <String, dynamic>{};

    final shop = shopData is Map
        ? Map<String, dynamic>.from(shopData)
        : <String, dynamic>{};

    final upi = shop["upi_id"]?.toString() ?? "";

    state = state.copyWith(
      isLoading: false,
      isAuthenticated: true,
      user: user,
      shop: shop,
      upiId: upi,
      errorMessage: null,
    );
  }

  // ============================================================
  // ERROR MESSAGE
  // ============================================================

  String _getErrorMessage(DioException e, String fallback) {
    final data = e.response?.data;

    if (data is Map && data["detail"] != null) {
      return data["detail"].toString();
    }

    if (e.response?.statusCode == 401) {
      return "Invalid email or password.";
    }

    if (e.response?.statusCode == 422) {
      return "Please check the entered details.";
    }

    if (e.response?.statusCode == 500) {
      return "Server error. Please try again.";
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return "Server connection timed out. Please check your internet.";
    }

    if (e.type == DioExceptionType.connectionError) {
      return "Cannot connect to KhataSetu server. Check your internet.";
    }

    return e.message ?? fallback;
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<bool> login(
    String email,
    String password, {
    bool rememberMe = true,
  }) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
    );

    try {
      // Clear only the previous session. The new remember-me choice is saved below.
      await LocalStorage.clearSession();

      final cleanEmail = email.trim().toLowerCase();

      final response = await ApiClient.client.post(
        ApiConstants.login,
        data: {
          "email": cleanEmail,
          "password": password,
        },
      );

      final responseData = response.data;

      if (responseData is! Map) {
        throw Exception("Invalid server response.");
      }

      final data = Map<String, dynamic>.from(responseData);

      final token = data["access_token"]?.toString();

      if (token == null || token.isEmpty) {
        throw Exception("Server did not return an access token.");
      }

      // Save REAL JWT.
      await LocalStorage.saveAuthSession(
        token: token,
        userId: int.tryParse(
              data["user_id"]?.toString() ?? "",
            ) ??
            0,
        shopId: int.tryParse(
              data["shop_id"]?.toString() ?? "",
            ) ??
            0,
        ownerName: data["owner_name"]?.toString() ?? "Shopkeeper",
        shopName: data["shop_name"]?.toString() ?? "My Khata",
        email: data["email"]?.toString() ?? cleanEmail,
        rememberMe: rememberMe,
      );

      // Verify token with backend.
      final meResponse = await ApiClient.client.get(
        ApiConstants.me,
        options: Options(
          headers: {
            "Authorization": "Bearer $token",
          },
        ),
      );

      if (meResponse.data is! Map) {
        throw Exception("Invalid profile response from server.");
      }

      final meData =
          Map<String, dynamic>.from(meResponse.data as Map);

      _applyServerData(meData);

      return true;
    } on DioException catch (e) {
      await LocalStorage.clearSession();

      state = AuthState(
        isLoading: false,
        isAuthenticated: false,
        errorMessage: _getErrorMessage(e, "Login failed."),
      );

      return false;
    } catch (e) {
      await LocalStorage.clearSession();

      state = AuthState(
        isLoading: false,
        isAuthenticated: false,
        errorMessage: e.toString().replaceFirst("Exception: ", ""),
      );

      return false;
    }
  }

  // ============================================================
  // REGISTER
  // ============================================================

  Future<bool> register({
    required String email,
    required String password,
    required String ownerName,
    required String shopName,
    String? phone,
    String? shopAddress,
    String? gstin,
  }) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
    );

    try {
      await LocalStorage.clearSession();

      final cleanEmail = email.trim().toLowerCase();

      final response = await ApiClient.client.post(
        ApiConstants.register,
        data: {
          "email": cleanEmail,
          "password": password,
          "owner_name": ownerName.trim(),
          "shop_name": shopName.trim(),
          "phone": phone?.trim() ?? "",
          "shop_address": shopAddress?.trim() ?? "",
          "gstin": gstin?.trim() ?? "",
        },
      );

      if (response.data is! Map) {
        throw Exception("Invalid server response.");
      }

      final data =
          Map<String, dynamic>.from(response.data as Map);

      final token = data["access_token"]?.toString();

      if (token == null || token.isEmpty) {
        throw Exception("Server did not return an access token.");
      }

      await LocalStorage.saveAuthSession(
        token: token,
        userId: int.tryParse(
              data["user_id"]?.toString() ?? "",
            ) ??
            0,
        shopId: int.tryParse(
              data["shop_id"]?.toString() ?? "",
            ) ??
            0,
        ownerName: data["owner_name"]?.toString() ?? ownerName,
        shopName: data["shop_name"]?.toString() ?? shopName,
        email: data["email"]?.toString() ?? cleanEmail,
      );

      final meResponse = await ApiClient.client.get(
        ApiConstants.me,
        options: Options(
          headers: {
            "Authorization": "Bearer $token",
          },
        ),
      );

      if (meResponse.data is! Map) {
        throw Exception("Invalid profile response from server.");
      }

      final meData =
          Map<String, dynamic>.from(meResponse.data as Map);

      _applyServerData(meData);

      return true;
    } on DioException catch (e) {
      await LocalStorage.clearSession();

      state = AuthState(
        isLoading: false,
        isAuthenticated: false,
        errorMessage:
            _getErrorMessage(e, "Registration failed."),
      );

      return false;
    } catch (e) {
      await LocalStorage.clearSession();

      state = AuthState(
        isLoading: false,
        isAuthenticated: false,
        errorMessage:
            e.toString().replaceFirst("Exception: ", ""),
      );

      return false;
    }
  }

  // ============================================================
  // CHECK SAVED SESSION
  // ============================================================

  Future<bool> checkSavedSession() async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
    );

    try {
      // Only restore a session when the user explicitly selected Remember Me.
      final rememberMe = await LocalStorage.getRememberMe();
      if (!rememberMe) {
        await LocalStorage.clearSession();
        state = const AuthState(
          isLoading: false,
          isAuthenticated: false,
        );
        return false;
      }

      final token = await LocalStorage.getToken();

      if (token == null ||
          token.isEmpty ||
          token.startsWith("offline_")) {
        await LocalStorage.clearSession();

        state = const AuthState(
          isLoading: false,
          isAuthenticated: false,
        );

        return false;
      }

      final response = await ApiClient.client.get(
        ApiConstants.me,
        options: Options(
          headers: {
            "Authorization": "Bearer $token",
          },
        ),
      );

      if (response.data is! Map) {
        throw Exception("Invalid session response.");
      }

      final data =
          Map<String, dynamic>.from(response.data as Map);

      _applyServerData(data);

      return true;
    } on DioException {
      await LocalStorage.clearSession();

      state = const AuthState(
        isLoading: false,
        isAuthenticated: false,
      );

      return false;
    } catch (_) {
      await LocalStorage.clearSession();

      state = const AuthState(
        isLoading: false,
        isAuthenticated: false,
      );

      return false;
    }
  }

  // ============================================================
  // FETCH CURRENT USER / SHOP
  // ============================================================

  Future<bool> fetchMe() async {
    try {
      final token = await LocalStorage.getToken();

      if (token == null ||
          token.isEmpty ||
          token.startsWith("offline_")) {
        return false;
      }

      final response = await ApiClient.client.get(
        ApiConstants.me,
        options: Options(
          headers: {
            "Authorization": "Bearer $token",
          },
        ),
      );

      if (response.data is! Map) {
        return false;
      }

      final data =
          Map<String, dynamic>.from(response.data as Map);

      _applyServerData(data);

      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await LocalStorage.clearSession();

        state = const AuthState(
          isLoading: false,
          isAuthenticated: false,
        );
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // UPDATE PROFILE
  // ============================================================

  Future<bool> updateProfile({
    String? fullName,
    String? phone,
    String? shopName,
    String? shopPhone,
    String? address,

    // Compatibility with current ProfileScreen.
    String? shopAddress,

    String? gstin,
    String? upiId,
  }) async {
    try {
      final token = await LocalStorage.getToken();

      if (token == null ||
          token.isEmpty ||
          token.startsWith("offline_")) {
        state = state.copyWith(
          errorMessage: "Please login again.",
        );
        return false;
      }

      final finalAddress = shopAddress ?? address;

      final response = await ApiClient.client.put(
        ApiConstants.profile,
        data: {
          if (fullName != null && fullName.trim().isNotEmpty)
            "full_name": fullName.trim(),

          if (phone != null)
            "phone": phone.trim(),

          if (shopName != null && shopName.trim().isNotEmpty)
            "shop_name": shopName.trim(),

          if (shopPhone != null)
            "shop_phone": shopPhone.trim(),

          if (finalAddress != null)
            "address": finalAddress.trim(),

          if (gstin != null)
            "gstin": gstin.trim(),

          if (upiId != null)
            "upi_id": upiId.trim(),
        },
        options: Options(
          headers: {
            "Authorization": "Bearer $token",
          },
        ),
      );

      if (response.data is Map) {
        final data =
            Map<String, dynamic>.from(response.data as Map);

        // Backend may return updated profile directly.
        if (data.containsKey("user") &&
            data.containsKey("shop")) {
          _applyServerData(data);
          return true;
        }
      }

      // Otherwise fetch the authoritative profile.
      return await fetchMe();
    } on DioException catch (e) {
      state = state.copyWith(
        errorMessage:
            _getErrorMessage(e, "Profile update failed."),
      );

      return false;
    } catch (e) {
      state = state.copyWith(
        errorMessage:
            e.toString().replaceFirst("Exception: ", ""),
      );

      return false;
    }
  }

  // ============================================================
  // CHANGE PASSWORD
  // ============================================================

  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final token = await LocalStorage.getToken();

      if (token == null ||
          token.isEmpty ||
          token.startsWith("offline_")) {
        state = state.copyWith(
          errorMessage: "Please login again.",
        );
        return false;
      }

      await ApiClient.client.post(
        ApiConstants.changePassword,
        data: {
          "old_password": oldPassword,
          "new_password": newPassword,
        },
        options: Options(
          headers: {
            "Authorization": "Bearer $token",
          },
        ),
      );

      state = state.copyWith(
        errorMessage: null,
      );

      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        errorMessage:
            _getErrorMessage(e, "Password change failed."),
      );

      return false;
    } catch (e) {
      state = state.copyWith(
        errorMessage:
            e.toString().replaceFirst("Exception: ", ""),
      );

      return false;
    }
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> logout() async {
    await LocalStorage.clearSession();

    state = const AuthState(
      isLoading: false,
      isAuthenticated: false,
      user: null,
      shop: null,
      upiId: "",
      errorMessage: null,
    );
  }
}

// ============================================================
// PROVIDER
// ============================================================

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);
