import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _oldPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();

  final _nameCtrl = TextEditingController();
  final _shopNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();

  String _selectedLanguage = "Hinglish";

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(authProvider.notifier).fetchMe();
    });
  }

  @override
  void dispose() {
    _oldPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _nameCtrl.dispose();
    _shopNameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _upiCtrl.dispose();
    super.dispose();
  }

  void _showEditProfileDialog() {
    final auth = ref.read(authProvider);
    _nameCtrl.text = auth.ownerName;
    _shopNameCtrl.text = auth.shopName;
    _phoneCtrl.text = auth.phone;
    _upiCtrl.text = auth.upiId;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("प्रोफ़ाइल संपादित करें", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text("Edit Shop & Owner Details", style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: "दुकानदार का नाम * (Owner Name)"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _shopNameCtrl,
                decoration: const InputDecoration(labelText: "दुकान का नाम * (Shop Name)"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: "मोबाइल नंबर (Phone Number)"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _addressCtrl,
                decoration: const InputDecoration(labelText: "दुकान का पता (Shop Address)"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _upiCtrl,
                decoration: const InputDecoration(
                  labelText: "दुकान का UPI ID (QR & Payment Requests)",
                  hintText: "उदा. shopkeeper@upi / 9876543210@paytm",
                  prefixIcon: Icon(Icons.qr_code, size: 20, color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("रद्द करें (Cancel)"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_nameCtrl.text.trim().isEmpty || _shopNameCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("नाम और दुकान का नाम आवश्यक है।")),
                );
                return;
              }
              final ok = await ref.read(authProvider.notifier).updateProfile(
                    fullName: _nameCtrl.text.trim(),
                    shopName: _shopNameCtrl.text.trim(),
                    phone: _phoneCtrl.text.trim(),
                    shopAddress: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
                    upiId: _upiCtrl.text.trim(),
                  );
              if (ok && mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Profile updated successfully! प्रोफ़ाइल सफलतापूर्वक अपडेट हो गई।"),
                    backgroundColor: AppColors.paymentGreen,
                  ),
                );
              }
            },
            child: const Text("सेव करें (Save)"),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("पासवर्ड बदलें", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text("Change Account Password", style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _oldPasswordCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: "वर्तमान पासवर्ड (Current Password)"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newPasswordCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: "नया पासवर्ड (New Password - Min 6 chars)"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("रद्द करें (Cancel)"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_newPasswordCtrl.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("नया पासवर्ड कम से कम 6 अक्षरों का होना चाहिए")),
                );
                return;
              }
              final success = await ref.read(authProvider.notifier).changePassword(
                    oldPassword: _oldPasswordCtrl.text,
                    newPassword: _newPasswordCtrl.text,
                  );
              if (success && mounted) {
                Navigator.pop(ctx);
                _oldPasswordCtrl.clear();
                _newPasswordCtrl.clear();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("पासवर्ड सफलतापूर्वक बदल दिया गया! Password changed successfully."),
                    backgroundColor: AppColors.paymentGreen,
                  ),
                );
              }
            },
            child: const Text("पासवर्ड सेव करें"),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("भाषा चुनें / Select Language", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text("हिंदी + English (Hinglish / मिश्रित)"),
              subtitle: const Text("अनुशंसित - भारतीय दुकानदारों के लिए"),
              value: "Hinglish",
              groupValue: _selectedLanguage,
              onChanged: (val) {
                setState(() => _selectedLanguage = val!);
                Navigator.pop(ctx);
              },
            ),
            RadioListTile<String>(
              title: const Text("English"),
              subtitle: const Text("Complete English Interface"),
              value: "English",
              groupValue: _selectedLanguage,
              onChanged: (val) {
                setState(() => _selectedLanguage = val!);
                Navigator.pop(ctx);
              },
            ),
            RadioListTile<String>(
              title: const Text("हिंदी (Pure Hindi)"),
              subtitle: const Text("संपूर्ण हिंदी इंटरफ़ेस"),
              value: "Hindi",
              groupValue: _selectedLanguage,
              onChanged: (val) {
                setState(() => _selectedLanguage = val!);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("प्रोफ़ाइल और सेटिंग्स", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text("Shopkeeper Profile & Settings", style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          // ─── Owner Profile Card ───────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [const Color(0xFFF0FDFA), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withOpacity(0.25), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        auth.ownerName.isNotEmpty ? auth.ownerName[0].toUpperCase() : "K",
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            auth.ownerName.isNotEmpty ? auth.ownerName : "दुकानदार (Shopkeeper)",
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            auth.shopName.isNotEmpty ? auth.shopName : "मेरी किराना दुकान",
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          if (auth.phone.isNotEmpty)
                            Text(
                              auth.phone,
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                            ),
                          Text(
                            auth.email,
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: auth.upiId.isNotEmpty
                                  ? AppColors.primary.withOpacity(0.08)
                                  : Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  auth.upiId.isNotEmpty ? Icons.qr_code : Icons.warning_amber_rounded,
                                  size: 13,
                                  color: auth.upiId.isNotEmpty ? AppColors.primary : Colors.orange[800],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  auth.upiId.isNotEmpty ? "UPI: ${auth.upiId}" : "UPI ID सेट करें (QR भुगतान हेतु)",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: auth.upiId.isNotEmpty ? AppColors.primary : Colors.orange[800],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showEditProfileDialog,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text("प्रोफ़ाइल संपादित करें (Edit)"),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ─── Settings Section ─────────────────────────────────────────
          const Text(
            "खाता सेटिंग्स / Account Settings",
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_outline_rounded, color: AppColors.primary),
                  title: const Text("पासवर्ड बदलें (Change Password)", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _showChangePasswordDialog,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.language_rounded, color: AppColors.primary),
                  title: const Text("भाषा प्राथमिकता (Language Preference)", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(_selectedLanguage, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _showLanguageDialog,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.verified_outlined, color: AppColors.primary),
                  title: const Text("ऐप संस्करण (App Version)", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text("KhataSetu v1.0.0 (Production Release)"),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.security_rounded, color: AppColors.primary),
                  title: const Text("सुरक्षा और गोपनीयता (Data Privacy)", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text("सभी बहीखाता डेटा 100% सुरक्षित और गोपनीय है"),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ─── Logout Button ────────────────────────────────────────────
          ElevatedButton.icon(
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              context.go("/login");
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.creditRed,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            label: const Text(
              "लॉग आउट (Logout from KhataSetu)",
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white),
            ),
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }
}
