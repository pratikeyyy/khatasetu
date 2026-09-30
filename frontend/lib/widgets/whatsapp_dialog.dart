import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../providers/reminder_provider.dart';

class WhatsAppDialog extends ConsumerStatefulWidget {
  final int customerId;
  final String customerName;
  final String phone;
  final double balance;
  final String shopName;

  const WhatsAppDialog({
    super.key,
    required this.customerId,
    required this.customerName,
    required this.phone,
    required this.balance,
    required this.shopName,
  });

  @override
  ConsumerState<WhatsAppDialog> createState() => _WhatsAppDialogState();
}

class _WhatsAppDialogState extends ConsumerState<WhatsAppDialog> {
  String _selectedLanguage = "hinglish";
  final TextEditingController _customNoteController = TextEditingController();
  bool _isSending = false;

  String _getPreviewText() {
    final amt = widget.balance.toStringAsFixed(2);
    final note = _customNoteController.text.trim();
    String base;

    if (_selectedLanguage == "hindi") {
      base = "नमस्ते ${widget.customerName} जी,\nआपके खाते में ₹$amt का बकाया (उधार) शेष है।\nकृपया सुविधानुसार भुगतान कर दें।\nधन्यवाद — ${widget.shopName}";
    } else if (_selectedLanguage == "english") {
      base = "Hello ${widget.customerName},\nYou have a pending outstanding balance of ₹$amt at ${widget.shopName}.\nKindly clear at your convenience.\nThank you — ${widget.shopName}";
    } else {
      base = "Namaste ${widget.customerName} ji,\naapke khate mein ₹$amt ka baki hai.\nKripya suvidha anusar payment kar dein.\nDhanyavaad — ${widget.shopName}";
    }

    if (note.isNotEmpty) {
      base += "\n\nNote: $note";
    }
    return base;
  }

  @override
  void dispose() {
    _customNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chat_rounded, color: Color(0xFF16A34A), size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "WhatsApp पेमेंट रिमाइंडर",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${widget.customerName} • बकाया ₹${widget.balance.toStringAsFixed(2)}",
                        style: const TextStyle(fontSize: 13, color: AppColors.creditRed, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Language Selector
            const Text(
              "संदेश की भाषा चुनें (Message Template):",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildLanguageChip("hinglish", "हिंग्लिश (Hinglish)"),
                const SizedBox(width: 8),
                _buildLanguageChip("hindi", "हिंदी (Hindi)"),
                const SizedBox(width: 8),
                _buildLanguageChip("english", "English"),
              ],
            ),
            const SizedBox(height: 16),

            // Message Preview Box
            const Text(
              "संदेश पूर्वावलोकन (Review before sending):",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Text(
                _getPreviewText(),
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Custom note input
            TextField(
              controller: _customNoteController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: "अतिरिक्त नोट (उदा. इस नंबर पर UPI करें)",
                isDense: true,
              ),
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                    child: const Text("रद्द करें (Cancel)"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isSending
                        ? null
                        : () async {
                            setState(() => _isSending = true);
                            final success = await ref
                                .read(reminderProvider.notifier)
                                .sendWhatsAppReminder(
                                  customerId: widget.customerId,
                                  language: _selectedLanguage,
                                  customNote: _customNoteController.text.trim(),
                                );
                            setState(() => _isSending = false);
                            if (mounted) {
                              Navigator.of(context).pop();
                              if (success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("WhatsApp खोला जा रहा है..."),
                                    backgroundColor: Color(0xFF16A34A),
                                  ),
                                );
                              }
                            }
                          },
                    icon: _isSending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      _isSending ? "खोला जा रहा है..." : "WhatsApp पर भेजें",
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageChip(String langCode, String label) {
    final isSelected = _selectedLanguage == langCode;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary.withOpacity(0.15),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.textMuted,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
        fontSize: 12,
      ),
      onSelected: (val) {
        if (val) setState(() => _selectedLanguage = langCode);
      },
    );
  }
}
