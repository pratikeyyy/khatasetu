import 'package:flutter/foundation.dart';

class ApiConstants {
  // Configurable base URL
  // Uses 10.0.2.2 for Android emulator, localhost for web/desktop, or custom LAN IP
  static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:8000/api/v1";
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return "http://10.174.30.241:8000/api/v1";
    } else {
      return "http://localhost:8000/api/v1";
    }
  }

  // Auth endpoints
  static const String login = "/auth/login";
  static const String register = "/auth/register";
  static const String me = "/auth/me";
  static const String profile = "/auth/profile";
  static const String changePassword = "/auth/change-password";

  // Shop endpoints
  static const String currentShop = "/shops/current";

  // Customer endpoints
  static const String customers = "/customers/";

  // Transaction endpoints
  static const String transactions = "/transactions/";
  static const String checkDuplicate = "/transactions/check-duplicate";

  // AI Scan & Verification endpoints
  static const String uploadScan = "/scans/upload";
  static const String scans = "/scans/";
  static const String batchConfirmHigh = "/scans/batch-confirm-high";

  // Dashboard endpoints
  static const String dashboardSummary = "/dashboard/summary";

  // Reminders
  static const String whatsappReminder = "/reminders/whatsapp";
  static const String reminderHistory = "/reminders/history";

  // Reports
  static const String transactionsCsv = "/reports/transactions/csv";
  static const String customersCsv = "/reports/customers/csv";

  // Debug Diagnostics
  static const String debugStatus = "/debug/status";
}
