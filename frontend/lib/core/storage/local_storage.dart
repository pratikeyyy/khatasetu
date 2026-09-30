import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static const String _keyToken = "auth_token";
  static const String _keyUserId = "user_id";
  static const String _keyShopId = "shop_id";
  static const String _keyOwnerName = "owner_name";
  static const String _keyShopName = "shop_name";
  static const String _keyEmail = "user_email";
  static const String _keyOnboarding = "has_seen_onboarding";

  static Future<void> saveAuthSession({
    required String token,
    required int userId,
    required int shopId,
    required String ownerName,
    required String shopName,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_keyToken, token);
    await prefs.setInt(_keyUserId, userId);
    await prefs.setInt(_keyShopId, shopId);
    await prefs.setString(_keyOwnerName, ownerName);
    await prefs.setString(_keyShopName, shopName);
    await prefs.setString(_keyEmail, email);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  static Future<Map<String, dynamic>?> getUserSession() async {
    final prefs = await SharedPreferences.getInstance();

    final token = prefs.getString(_keyToken);

    if (token == null) {
      return null;
    }

    return {
      "token": token,
      "user_id": prefs.getInt(_keyUserId) ?? 0,
      "shop_id": prefs.getInt(_keyShopId) ?? 0,
      "owner_name": prefs.getString(_keyOwnerName) ?? "Shopkeeper",
      "shop_name": prefs.getString(_keyShopName) ?? "My Khata",
      "email": prefs.getString(_keyEmail) ?? "",
      "phone": prefs.getString("user_phone") ?? "",
    };
  }

  static Future<void> saveLocalCredentials({
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString("local_email", email);
    await prefs.setString("local_password", password);
  }

  static Future<Map<String, String>?> getLocalCredentials() async {
    final prefs = await SharedPreferences.getInstance();

    final email = prefs.getString("local_email");
    final password = prefs.getString("local_password");

    if (email == null || password == null) {
      return null;
    }

    return {
      "email": email,
      "password": password,
    };
  }

  static Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOnboarding) ?? false;
  }

  static Future<void> setOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboarding, true);
  }

  static Future<void> saveProfileUpdate({
    String? ownerName,
    String? shopName,
    String? phone,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (ownerName != null) {
      await prefs.setString(_keyOwnerName, ownerName);
    }

    if (shopName != null) {
      await prefs.setString(_keyShopName, shopName);
    }

    if (phone != null) {
      await prefs.setString("user_phone", phone);
    }
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_keyToken);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyShopId);
    await prefs.remove(_keyOwnerName);
    await prefs.remove(_keyShopName);
    await prefs.remove(_keyEmail);
    await prefs.remove("user_phone");
  }
}