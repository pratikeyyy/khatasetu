import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _shopNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _gstinController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _ownerNameController.dispose();
    _shopNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _gstinController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authProvider.notifier).register(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          ownerName: _ownerNameController.text.trim(),
          shopName: _shopNameController.text.trim(),
          phone: _phoneController.text.trim(),
          shopAddress: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
          gstin: _gstinController.text.trim().isEmpty ? null : _gstinController.text.trim(),
        );

    if (success && mounted) {
      context.go("/home");
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Register Your Shop"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go("/login"),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.store_rounded, color: AppColors.primary),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Set up your Kirana shop profile. This will appear on reminders and reports.",
                      style: TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Error
            if (auth.errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(auth.errorMessage!, style: const TextStyle(color: AppColors.creditRed, fontSize: 13)),
              ),
              const SizedBox(height: 16),
            ],

            // Section: Shop Identity
            const Text("OWNER & SHOP DETAILS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1.2)),
            const SizedBox(height: 12),

            TextFormField(
              controller: _ownerNameController,
              decoration: const InputDecoration(labelText: "Owner Name *", prefixIcon: Icon(Icons.person_outline)),
              validator: (v) => v == null || v.trim().isEmpty ? "Owner name is required" : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _shopNameController,
              decoration: const InputDecoration(labelText: "Shop Name *", prefixIcon: Icon(Icons.store_outlined)),
              validator: (v) => v == null || v.trim().isEmpty ? "Shop name is required" : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: "Mobile Number *", prefixIcon: Icon(Icons.phone_outlined)),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return "Mobile number is required";
                if (v.trim().replaceAll(RegExp(r'[^0-9]'), '').length < 10) return "Enter a valid 10-digit mobile number";
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _addressController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: "Shop Address (Optional)", prefixIcon: Icon(Icons.location_on_outlined)),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _gstinController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: "GSTIN (Optional)",
                prefixIcon: Icon(Icons.assignment_outlined),
                hintText: "e.g. 22AAAAA0000A1Z5",
              ),
            ),
            const SizedBox(height: 24),

            // Section: Account
            const Text("ACCOUNT DETAILS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1.2)),
            const SizedBox(height: 12),

            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: "Email Address *", prefixIcon: Icon(Icons.email_outlined)),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return "Email is required";
                if (!v.contains('@') || !v.contains('.')) return "Enter a valid email address";
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: "Password *",
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return "Password is required";
                if (v.length < 6) return "Password must be at least 6 characters";
                return null;
              },
            ),
            const SizedBox(height: 28),

            // Register button
            ElevatedButton(
              onPressed: auth.isLoading ? null : _handleRegister,
              child: auth.isLoading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Create My Khata Account"),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Already have an account? ", style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                GestureDetector(
                  onTap: () => context.go("/login"),
                  child: const Text("Log In", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
