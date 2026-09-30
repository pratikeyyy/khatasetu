import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../providers/customer_provider.dart';
import '../widgets/empty_state_view.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _searchCtrl = TextEditingController();
  String _sort = "name";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(customerProvider.notifier).fetchCustomers();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customerState = ref.watch(customerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final totalOutstanding = customerState.customers.fold<double>(
      0.0,
      (sum, c) => sum + (c.balance > 0 ? c.balance : 0.0),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("ग्राहक सूची", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text("Customer Management & Khata", style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            tooltip: "ग्राहक जोड़ें (Add Customer)",
            onPressed: () => _showAddCustomerSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: "रिफ्रेश (Refresh)",
            onPressed: () => ref.read(customerProvider.notifier).fetchCustomers(),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search Bar ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (q) => ref.read(customerProvider.notifier).searchCustomers(q),
              decoration: InputDecoration(
                hintText: "ग्राहक का नाम या मोबाइल नंबर खोजें...",
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchCtrl.clear();
                          ref.read(customerProvider.notifier).fetchCustomers();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),

          // ── Sorting and Filters ─────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
            child: Row(
              children: [
                _sortChip("नाम (A-Z)", "name"),
                const SizedBox(width: 8),
                _sortChip("अधिक बकाया (High Udhaar)", "balance_desc"),
                const SizedBox(width: 8),
                _sortChip("कम बकाया (Low Udhaar)", "balance_asc"),
                const SizedBox(width: 8),
                _sortChip("हाल ही में सक्रिय (Recent)", "recent"),
              ],
            ),
          ),

          // ── Summary Strip ───────────────────────────────────────────────
          if (customerState.customers.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.people_alt_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    "कुल ग्राहक: ${customerState.customers.length}",
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  const Text("कुल बकाया: ", style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  Text(
                    "₹${NumberFormat('#,##,###.00').format(totalOutstanding)}",
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.creditRed),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 6),

          // ── Customer List ───────────────────────────────────────────────
          Expanded(
            child: customerState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : customerState.customers.isEmpty
                    ? EmptyStateView(
                        icon: Icons.people_outline_rounded,
                        titleHindi: "अभी कोई ग्राहक नहीं है",
                        titleEnglish: "No Customers Found",
                        messageHindi: "ग्राहक जोड़ें और अपना डिजिटल खाता शुरू करें।",
                        messageEnglish: "Add your first customer to start recording udhaar & jama.",
                        buttonText: "+ नया ग्राहक जोड़ें",
                        onButtonPressed: () => _showAddCustomerSheet(context),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                        itemCount: customerState.customers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final c = customerState.customers[idx];
                          final isOwed = c.balance > 0;
                          return InkWell(
                            onTap: () => context.push("/customer/${c.id}"),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  // Avatar
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: isOwed ? AppColors.creditRed.withOpacity(0.12) : AppColors.paymentGreen.withOpacity(0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        c.name.isNotEmpty ? c.name[0].toUpperCase() : "?",
                                        style: TextStyle(
                                          fontSize: 19,
                                          fontWeight: FontWeight.w900,
                                          color: isOwed ? AppColors.creditRed : AppColors.paymentGreen,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // Name & Phone
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        if (c.phone != null && c.phone!.isNotEmpty)
                                          Row(
                                            children: [
                                              const Icon(Icons.phone_outlined, size: 12, color: AppColors.textMuted),
                                              const SizedBox(width: 4),
                                              Text(c.phone!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                            ],
                                          )
                                        else
                                          const Text("फोन नंबर नहीं है", style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontStyle: FontStyle.italic)),
                                      ],
                                    ),
                                  ),

                                  // Balance & Clear Status Badge
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        "₹${NumberFormat('#,##,###.00').format(c.balance.abs())}",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                          color: isOwed ? AppColors.creditRed : AppColors.paymentGreen,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: (isOwed ? AppColors.creditRed : AppColors.paymentGreen).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          isOwed ? "उधार / बकाया" : c.balance < 0 ? "अग्रिम / Advance" : "खाता साफ़ / Clear",
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: isOwed ? AppColors.creditRed : AppColors.paymentGreen,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCustomerSheet(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text(
          "+ नया ग्राहक जोड़ें",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _sortChip(String label, String value) {
    final isSelected = _sort == value;
    return InkWell(
      onTap: () {
        setState(() => _sort = value);
        ref.read(customerProvider.notifier).sortCustomers(value);
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.divider.withOpacity(0.6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  void _showAddCustomerSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("नया ग्राहक जोड़ें", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    Text("Add New Customer to Khata", style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: "ग्राहक का नाम * (Customer Name)",
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "मोबाइल नंबर (Mobile Phone)",
                prefixIcon: Icon(Icons.phone_outlined),
                hintText: "उदा. 9811223344",
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressCtrl,
              decoration: const InputDecoration(
                labelText: "दुकान / घर का पता (Address - Optional)",
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("कृपया ग्राहक का नाम दर्ज करें"), backgroundColor: AppColors.creditRed),
                  );
                  return;
                }
                final res = await ref.read(customerProvider.notifier).addCustomer(
                  name: name,
                  phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                  address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                );
                if (res != null && mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("ग्राहक '${res.name}' सफलतापूर्वक जोड़ा गया!"),
                      backgroundColor: AppColors.paymentGreen,
                    ),
                  );
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("ग्राहक जोड़ने में समस्या हुई। कृपया दोबारा जाँचें।"),
                      backgroundColor: AppColors.creditRed,
                    ),
                  );
                }
              },
              child: const Text("ग्राहक सेव करें / Save Customer"),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
