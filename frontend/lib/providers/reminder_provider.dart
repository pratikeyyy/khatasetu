import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/database/local_database.dart';
import '../models/reminder_model.dart';

class ReminderNotifier
    extends StateNotifier<AsyncValue<WhatsAppReminderModel?>> {
  ReminderNotifier() : super(const AsyncValue.data(null));

  Future<bool> sendWhatsAppReminder({
    required int customerId,
    String language = "hinglish",
    String? customNote,
  }) async {
    state = const AsyncValue.loading();

    try {
      final db = await LocalDatabase.database;

      final customers = await db.query(
        "customers",
        where: "id = ? AND is_active = 1",
        whereArgs: [customerId],
        limit: 1,
      );

      if (customers.isEmpty) {
        state = AsyncValue.error(
          "Customer not found.",
          StackTrace.current,
        );
        return false;
      }

      final customer = customers.first;

      final customerName =
          customer["name"]?.toString() ?? "Customer";

      final phone =
          customer["phone"]?.toString() ?? "";

      final outstandingAmount =
          (customer["credit_balance"] as num?)?.toDouble() ?? 0.0;

      if (phone.trim().isEmpty) {
        state = AsyncValue.error(
          "Customer phone number is not available.",
          StackTrace.current,
        );
        return false;
      }

      String message;

      if (customNote != null &&
          customNote.trim().isNotEmpty) {
        message = customNote.trim();
      } else if (language.toLowerCase() == "hindi") {
        message =
            "Namaste $customerName ji,\n\n"
            "Aapke khate mein ₹${outstandingAmount.toStringAsFixed(2)} baki hai.\n"
            "Kripya payment kar dein.\n\n"
            "Dhanyavaad.";
      } else {
        message =
            "Namaste $customerName ji,\n\n"
            "Aapke khate mein ₹${outstandingAmount.toStringAsFixed(2)} baki hai.\n"
            "Please payment kar dein.\n\n"
            "Dhanyavaad.";
      }

      final cleanPhone =
          phone.replaceAll(RegExp(r'[^0-9]'), '');

      final whatsappUrl =
          "https://wa.me/$cleanPhone"
          "?text=${Uri.encodeComponent(message)}";

      final model = WhatsAppReminderModel(
        customerId: customerId,
        customerName: customerName,
        phone: phone,
        outstandingAmount: outstandingAmount,
        messageText: message,
        whatsappUrl: whatsappUrl,
      );

      state = AsyncValue.data(model);

      final uri = Uri.parse(whatsappUrl);

      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        return true;
      }

      state = AsyncValue.error(
        "WhatsApp could not be opened.",
        StackTrace.current,
      );

      return false;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final reminderProvider = StateNotifierProvider<
    ReminderNotifier,
    AsyncValue<WhatsAppReminderModel?>>(
  (ref) => ReminderNotifier(),
);