import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/reminder_provider.dart';

class PaymentRequestDialog extends ConsumerStatefulWidget {
  final int customerId;
  final String customerName;
  final String phone;
  final double exactAmount;
  final String shopName;

  const PaymentRequestDialog({
    super.key,
    required this.customerId,
    required this.customerName,
    required this.phone,
    required this.exactAmount,
    required this.shopName,
  });

  @override
  ConsumerState<PaymentRequestDialog> createState() => _PaymentRequestDialogState();
}

class _PaymentRequestDialogState extends ConsumerState<PaymentRequestDialog> {
  final _upiInputCtrl = TextEditingController();
  bool _isSavingUpi = false;
  bool _isSendingWhatsApp = false;

  @override
  void dispose() {
    _upiInputCtrl.dispose();
    super.dispose();
  }

  String _cleanPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return '91$digits';
    if (digits.length == 12 && digits.startsWith('91')) return digits;
    if (digits.length == 11 && digits.startsWith('0')) return '91${digits.substring(1)}';
    return digits;
  }

  String _buildUpiUri(String upiId) {
    final cleanUpi = upiId.trim();
    final shopNameEnc = Uri.encodeComponent(widget.shopName.isNotEmpty ? widget.shopName : "KhataSetu Shop");
    final amtStr = widget.exactAmount.toStringAsFixed(2);
    final noteEnc = Uri.encodeComponent("Khata Payment");
    return "upi://pay?pa=$cleanUpi&pn=$shopNameEnc&am=$amtStr&cu=INR&tn=$noteEnc";
  }

  Future<void> _shareOnWhatsApp(String upiUri) async {
    setState(() => _isSendingWhatsApp = true);
    try {
      final amtStr = NumberFormat('#,##,###.00').format(widget.exactAmount);
      final shop = widget.shopName.isNotEmpty ? widget.shopName : "दुकान";
      final msg = "Namaste ${widget.customerName} ji,\n"
          "Aapke khate mein baki rashi ₹$amtStr hai.\n"
          "Kripya niche diye gaye UPI link se payment karein:\n"
          "$upiUri\n\n"
          "Dhanyavaad — $shop";

      final cleanPh = _cleanPhone(widget.phone);
      final waUrl = cleanPh.isNotEmpty
          ? "https://wa.me/$cleanPh?text=${Uri.encodeComponent(msg)}"
          : "https://wa.me/?text=${Uri.encodeComponent(msg)}";

      final uri = Uri.parse(waUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }

      // Also track in backend reminder history
      ref.read(reminderProvider.notifier).sendWhatsAppReminder(
            customerId: widget.customerId,
            language: "hinglish",
            customNote: "UPI Request: $upiUri",
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("WhatsApp खोला जा रहा है..."),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("WhatsApp खोलने में त्रुटि: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingWhatsApp = false);
    }
  }

  Future<void> _saveQuickUpi() async {
    final upi = _upiInputCtrl.text.trim();
    if (upi.isEmpty || !upi.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("कृपया मान्य UPI ID दर्ज करें (उदा. shop@upi)"),
          backgroundColor: AppColors.creditRed,
        ),
      );
      return;
    }

    setState(() => _isSavingUpi = true);
    final ok = await ref.read(authProvider.notifier).updateProfile(upiId: upi);
    setState(() => _isSavingUpi = false);

    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("UPI ID सफलतापूर्वक सेव हो गया!"),
          backgroundColor: AppColors.paymentGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final upiId = auth.upiId.trim();
    final hasUpi = upiId.isNotEmpty;
    final exactAmtFormatted = NumberFormat('#,##,###.00').format(widget.exactAmount);
    final upiUri = hasUpi ? _buildUpiUri(upiId) : "";
    final qrApiUrl = hasUpi
        ? "https://api.qrserver.com/v1/create-qr-code/?size=240x240&data=${Uri.encodeComponent(upiUri)}"
        : "";

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.qr_code_2_rounded, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "भुगतान अनुरोध (Payment Request)",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            "${widget.customerName} से वसूली",
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Exact Amount Due Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                        : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                ),
                child: Column(
                  children: [
                    const Text(
                      "सटीक बकाया रकम (Exact Outstanding)",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "₹$exactAmtFormatted",
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: AppColors.creditRed,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // If UPI ID not configured -> Configuration prompt
              if (!hasUpi) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber.withOpacity(0.4)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 36, color: Colors.amber),
                      const SizedBox(height: 8),
                      const Text(
                        "दुकान का UPI ID सेट नहीं है",
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "QR कोड और डिजिटल पेमेंट लिंक के लिए कृपया अपना UPI ID दर्ज करें।",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _upiInputCtrl,
                        decoration: const InputDecoration(
                          hintText: "उदा. 9876543210@upi या shop@sbi",
                          prefixIcon: Icon(Icons.payment, size: 18),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSavingUpi ? null : _saveQuickUpi,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: _isSavingUpi
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.save_rounded, size: 16),
                          label: const Text("UPI ID सेव करें और QR बनाएं"),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // QR Code Display
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          qrApiUrl,
                          width: 200,
                          height: 200,
                          fit: BoxFit.contain,
                          loadingBuilder: (ctx, child, progress) {
                            if (progress == null) return child;
                            return const SizedBox(
                              width: 200,
                              height: 200,
                              child: Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          },
                          errorBuilder: (ctx, err, stack) {
                            return Container(
                              width: 200,
                              height: 200,
                              color: const Color(0xFFF1F5F9),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.qr_code, size: 48, color: AppColors.textMuted),
                                  SizedBox(height: 6),
                                  Text("UPI Intent Link Active", style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.verified_user_rounded, size: 14, color: AppColors.paymentGreen),
                          const SizedBox(width: 4),
                          Text(
                            "UPI ID: $upiId",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        "GPay • PhonePe • Paytm • Any UPI App",
                        style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Action Buttons: Copy Link & WhatsApp Share
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: upiUri));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("UPI लिंक क्लिपबोर्ड पर कॉपी हो गया!"),
                              backgroundColor: AppColors.primary,
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text("लिंक कॉपी (Copy)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isSendingWhatsApp ? null : () => _shareOnWhatsApp(upiUri),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: _isSendingWhatsApp
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.chat_rounded, size: 16),
                        label: const Text("WhatsApp भेजें", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),

              // Non-accounting safety notice (Rule: does NOT automatically record transaction)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textMuted),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "नोट: केवल पेमेंट रिक्वेस्ट भेजने या QR दिखाने से खाता नहीं कटेगा। ग्राहक से पैसे प्राप्त होने पर '+ जमा प्राप्त' दबाकर एंट्री दर्ज करें।",
                        style: TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
