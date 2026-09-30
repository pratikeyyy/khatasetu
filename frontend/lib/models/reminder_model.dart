class WhatsAppReminderModel {
  final int customerId;
  final String customerName;
  final String phone;
  final double outstandingAmount;
  final String messageText;
  final String whatsappUrl;

  WhatsAppReminderModel({
    required this.customerId,
    required this.customerName,
    required this.phone,
    required this.outstandingAmount,
    required this.messageText,
    required this.whatsappUrl,
  });

  factory WhatsAppReminderModel.fromJson(Map<String, dynamic> json) {
    return WhatsAppReminderModel(
      customerId: json["customer_id"] ?? 0,
      customerName: json["customer_name"] ?? "",
      phone: json["phone"] ?? "",
      outstandingAmount: (json["outstanding_amount"] as num?)?.toDouble() ?? 0.0,
      messageText: json["message_text"] ?? "",
      whatsappUrl: json["whatsapp_url"] ?? "",
    );
  }
}
