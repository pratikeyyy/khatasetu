import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/storage/local_storage.dart';

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final String? token;
  final int userId;
  final int shopId;
  final String ownerName;
  final String shopName;
  final String email;
  final String phone;
  final String upiId;
  final String? errorMessage;

  AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.token,
    this.userId = 0,
    this.shopId = 0,
    this.ownerName = "",
    this.shopName = "",
    this.email = "",
    this.phone = "",
    this.upiId = "",
    this.errorMessage,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    String? token,
    int? userId,
    int? shopId,
    String? ownerName,
    String? shopName,
    String? email,
    String? phone,
    String? upiId,
    String? errorMessage,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      token: token ?? this.token,
      userId: userId ?? this.userId,
      shopId: shopId ?? this.shopId,
      ownerName: ownerName ?? this.ownerName,
      shopName: shopName ?? this.shopName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      upiId: upiId ?? this.upiId,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState()) {
    checkSavedSession();
  }

  Future<void> fetchMe() async {
    // Offline mode.
    // User and shop information is already stored locally.
  }

  Future<void> checkSavedSession() async {
    state = state.copyWith(isLoading: true);

    try {
      final session = await LocalStorage.getUserSession();

      if (session != null) {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          token: session["token"]?.toString(),
          userId: session["user_id"] ?? 0,
          shopId: session["shop_id"] ?? 0,
          ownerName: session["owner_name"] ?? "Shopkeeper",
          shopName: session["shop_name"] ?? "My Khata",
          email: session["email"] ?? "",
          phone: session["phone"] ?? "",
        );

        await fetchMe();
      } else {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: false,
        errorMessage: e.toString(),
      );
    }
  }

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
      final credentials = await LocalStorage.getLocalCredentials();

      if (credentials == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: "No account found. Please register first.",
        );
        return false;
      }

      final savedEmail = credentials["email"] ?? "";
      final savedPassword = credentials["password"] ?? "";

      if (email.trim().toLowerCase() != savedEmail.toLowerCase() ||
          password != savedPassword) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: "Invalid email or password.",
        );
        return false;
      }

      final session = await LocalStorage.getUserSession();

      if (session == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: "Local session not found.",
        );
        return false;
      }

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        token: session["token"]?.toString(),
        userId: session["user_id"] ?? 0,
        shopId: session["shop_id"] ?? 0,
        ownerName: session["owner_name"] ?? "Shopkeeper",
        shopName: session["shop_name"] ?? "My Khata",
        email: savedEmail,
        phone: session["phone"] ?? "",
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

  Future<bool> register({
    required String email,
    required String password,
    required String ownerName,
    required String shopName,
    required String phone,
    String? shopAddress,
    String? gstin,
  }) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
    );

    try {
      final existing = await LocalStorage.getLocalCredentials();

      if (existing != null &&
          existing["email"]!.toLowerCase() == email.trim().toLowerCase()) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: "An account with this email already exists.",
        );
        return false;
      }

      final userId = DateTime.now().microsecondsSinceEpoch;

      final shopId = userId + 1;

      final token = "offline_${DateTime.now().millisecondsSinceEpoch}";

      await LocalStorage.saveAuthSession(
        token: token,
        userId: userId,
        shopId: shopId,
        ownerName: ownerName.trim(),
        shopName: shopName.trim(),
        email: email.trim(),
      );

      await LocalStorage.saveProfileUpdate(
        ownerName: ownerName.trim(),
        shopName: shopName.trim(),
        phone: phone.trim(),
      );

      await LocalStorage.saveLocalCredentials(
        email: email.trim(),
        password: password,
      );

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        token: token,
        userId: userId,
        shopId: shopId,
        ownerName: ownerName.trim(),
        shopName: shopName.trim(),
        email: email.trim(),
        phone: phone.trim(),
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

  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
    );

    try {
      final credentials = await LocalStorage.getLocalCredentials();

      if (credentials == null || credentials["password"] != oldPassword) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: "Old password is incorrect.",
        );
        return false;
      }

      await LocalStorage.saveLocalCredentials(
        email: credentials["email"]!,
        password: newPassword,
      );

      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<bool> updateProfile({
    String? fullName,
    String? shopName,
    String? phone,
    String? shopAddress,
    String? gstin,
    String? upiId,
  }) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
    );

    try {
      final newOwnerName = fullName != null && fullName.trim().isNotEmpty
          ? fullName.trim()
          : state.ownerName;

      final newShopName = shopName != null && shopName.trim().isNotEmpty
          ? shopName.trim()
          : state.shopName;

      final newPhone =
          phone != null && phone.trim().isNotEmpty ? phone.trim() : state.phone;

      final newUpiId = upiId != null ? upiId.trim() : state.upiId;

      await LocalStorage.saveProfileUpdate(
        ownerName: newOwnerName,
        shopName: newShopName,
        phone: newPhone,
      );

      state = state.copyWith(
        isLoading: false,
        ownerName: newOwnerName,
        shopName: newShopName,
        phone: newPhone,
        upiId: newUpiId,
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

  Future<void> logout() async {
    await LocalStorage.clearSession();

    state = AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);
