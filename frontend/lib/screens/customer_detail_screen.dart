import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../models/customer_model.dart';
import '../providers/auth_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/transaction_provider.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/whatsapp_dialog.dart';
import '../widgets/payment_request_dialog.dart';
import '../widgets/empty_state_view.dart';

class CustomerDetailScreen extends ConsumerStatefulWidget {
  final int customerId;
  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  ConsumerState<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(customerDetailProvider(widget.customerId).notifier).fetchDetail(widget.customerId);
      ref.read(transactionProvider.notifier).fetchTransactions(customerId: widget.customerId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final detailState = ref.watch(customerDetailProvider(widget.customerId));
    final txState = ref.watch(transactionProvider);
    final auth = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final customer = detailState.customer;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(customer?.name ?? "ग्राहक खाता (Customer Ledger)", style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            if (customer?.phone != null && customer!.phone!.isNotEmpty)
              Text(customer.phone!, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
        actions: [
          if (customer != null) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: "संपादित करें (Edit Customer)",
              onPressed: () => _showEditSheet(context, customer),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: "रिफ्रेश (Refresh)",
              onPressed: () {
                ref.read(customerDetailProvider(widget.customerId).notifier).fetchDetail(widget.customerId);
                ref.read(transactionProvider.notifier).fetchTransactions(customerId: widget.customerId);
              },
            ),
          ],
        ],
      ),
      body: customer == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await ref.read(customerDetailProvider(widget.customerId).notifier).fetchDetail(widget.customerId);
                await ref.read(transactionProvider.notifier).fetchTransactions(customerId: widget.customerId);
              },
              child: CustomScrollView(
                slivers: [
                  // ─── Customer Ledger Header Card ────────────────────────
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: customer.balance > 0 ? AppColors.creditRed.withOpacity(0.3) : AppColors.paymentGreen.withOpacity(0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (customer.balance > 0 ? AppColors.creditRed : AppColors.paymentGreen).withOpacity(0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              // Avatar
                              Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  color: (customer.balance > 0 ? AppColors.creditRed : AppColors.paymentGreen).withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    customer.name.isNotEmpty ? customer.name[0].toUpperCase() : "?",
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: customer.balance > 0 ? AppColors.creditRed : AppColors.paymentGreen,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      customer.name,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    if (customer.phone != null && customer.phone!.isNotEmpty)
                                      Text(customer.phone!, style: const TextStyle(fontSize: 13, color: AppColors.textMuted))
                                    else
                                      const Text("फोन नंबर नहीं है", style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontStyle: FontStyle.italic)),
                                    if (customer.address != null && customer.address!.isNotEmpty)
                                      Text(customer.address!, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 10),

                          // Current Balance Box
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "वर्तमान बकाया (Net Balance)",
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "₹${NumberFormat('#,##,###.00').format(customer.balance.abs())}",
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: customer.balance > 0 ? AppColors.creditRed : AppColors.paymentGreen,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: (customer.balance > 0 ? AppColors.creditRed : AppColors.paymentGreen).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  customer.balance > 0
                                      ? "उधार बाकी (Customer Owes)"
                                      : customer.balance < 0
                                          ? "अग्रिम जमा (Advance)"
                                          : "खाता साफ़ (Clear)",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: customer.balance > 0 ? AppColors.creditRed : AppColors.paymentGreen,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // Quick Action Buttons (+ उधार, + जमा, WhatsApp)
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => context.push("/add-transaction", extra: customer.id),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.creditRed,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: const Icon(Icons.arrow_outward_rounded, size: 18, color: Colors.white),
                                  label: const Text("+ उधार दिया", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => context.push("/add-transaction", extra: customer.id),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.paymentGreen,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: const Icon(Icons.arrow_downward_rounded, size: 18, color: Colors.white),
                                  label: const Text("+ जमा प्राप्त", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () {
                                  if (customer.balance <= 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("इस ग्राहक पर कोई बकाया नहीं है।"),
                                      ),
                                    );
                                    return;
                                  }
                                  showDialog(
                                    context: context,
                                    builder: (_) => WhatsAppDialog(
                                      customerId: customer.id,
                                      customerName: customer.name,
                                      phone: customer.phone ?? "",
                                      balance: customer.balance,
                                      shopName: auth.shopName.isNotEmpty ? auth.shopName : "किराना स्टोर",
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFF86EFAC)),
                                  ),
                                  child: const Icon(Icons.chat_rounded, color: Color(0xFF16A34A), size: 22),
                                ),
                              ),
                            ],
                          ),
                          if (customer.balance > 0) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => PaymentRequestDialog(
                                      customerId: customer.id,
                                      customerName: customer.name,
                                      phone: customer.phone ?? "",
                                      exactAmount: customer.balance,
                                      shopName: auth.shopName,
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F172A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 2,
                                ),
                                icon: const Text("💰", style: TextStyle(fontSize: 16)),
                                label: Text(
                                  "Request ₹${NumberFormat('#,##,###.00').format(customer.balance)} (UPI / QR)",
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // ─── Transaction Timeline Header ──────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "खाता विवरण / Transaction History",
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                              ),
                              Text(
                                "Timeline of udhaar & payments",
                                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                          Text(
                            "${txState.transactions.length} entries",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ─── Transaction List ────────────────────────────────────
                  if (txState.isLoading)
                    const SliverToBoxAdapter(
                      child: Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
                    )
                  else if (txState.transactions.isEmpty)
                    SliverToBoxAdapter(
                      child: EmptyStateView(
                        icon: Icons.receipt_long_outlined,
                        titleHindi: "कोई लेन-देन नहीं मिला",
                        titleEnglish: "No Transactions Found",
                        messageHindi: "इस ग्राहक के लिए अभी कोई लेन-देन दर्ज नहीं है।",
                        messageEnglish: "Use the buttons above to record udhaar or jama.",
                        buttonText: "+ उधार जोड़ें",
                        onButtonPressed: () => context.push("/add-transaction", extra: customer.id),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, idx) {
                          return TransactionTile(transaction: txState.transactions[idx]);
                        },
                        childCount: txState.transactions.length,
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),
    );
  }

  void _showEditSheet(BuildContext context, CustomerModel customer) {
    final nameCtrl = TextEditingController(text: customer.name);
    final phoneCtrl = TextEditingController(text: customer.phone ?? "");
    final addressCtrl = TextEditingController(text: customer.address ?? "");

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
                const Text("ग्राहक विवरण बदलें / Edit", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 16),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "ग्राहक का नाम * (Name)")),
            const SizedBox(height: 12),
            TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "मोबाइल नंबर (Phone)")),
            const SizedBox(height: 12),
            TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: "पता (Address)")),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                final ok = await ref.read(customerProvider.notifier).updateCustomer(
                  customerId: customer.id,
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                  address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                );
                if (ok && mounted) {
                  Navigator.pop(ctx);
                  ref.read(customerDetailProvider(customer.id).notifier).fetchDetail(customer.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("ग्राहक विवरण सफलतापूर्वक अपडेट हो गया!"), backgroundColor: AppColors.paymentGreen),
                  );
                }
              },
              child: const Text("बदलाव सेव करें / Save Changes"),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
