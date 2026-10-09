import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_theme.dart';
import '../providers/customer_provider.dart';
import '../providers/transaction_provider.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/whatsapp_dialog.dart';
import '../widgets/empty_state_view.dart';

class CustomerDetailScreen extends ConsumerStatefulWidget {
  final int customerId;

  const CustomerDetailScreen({
    super.key,
    required this.customerId,
  });

  @override
  ConsumerState<CustomerDetailScreen> createState() =>
      _CustomerDetailScreenState();
}

class _CustomerDetailScreenState
    extends ConsumerState<CustomerDetailScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(customerDetailProvider(widget.customerId).notifier)
          .fetchDetail(widget.customerId);

      ref
          .read(transactionProvider.notifier)
          .fetchTransactions(customerId: widget.customerId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final detailState =
        ref.watch(customerDetailProvider(widget.customerId));
    final txState = ref.watch(transactionProvider);
    final customer = detailState.customer;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          customer?.name ?? "Customer Detail",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (customer != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _showEditSheet(context, customer),
            ),
        ],
      ),
      body: customer == null
          ? detailState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : Center(
                  child: Text(
                    detailState.errorMessage ??
                        "Customer details not available.",
                  ),
                )
          : RefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  ref
                      .read(
                          customerDetailProvider(widget.customerId).notifier)
                      .fetchDetail(widget.customerId),
                  ref
                      .read(transactionProvider.notifier)
                      .fetchTransactions(
                        customerId: widget.customerId,
                      ),
                ]);
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: customer.balance > 0
                              ? const [
                                  Color(0xFFFEF2F2),
                                  Color(0xFFFEE2E2),
                                ]
                              : const [
                                  Color(0xFFF0FDF4),
                                  Color(0xFFDCFCE7),
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: customer.balance > 0
                                      ? AppColors.creditRed.withOpacity(0.15)
                                      : AppColors.paymentGreen
                                          .withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    customer.name.isNotEmpty
                                        ? customer.name[0].toUpperCase()
                                        : "?",
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: customer.balance > 0
                                          ? AppColors.creditRed
                                          : AppColors.paymentGreen,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      customer.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    if (customer.phone != null &&
                                        customer.phone!.isNotEmpty)
                                      Text(
                                        customer.phone!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 13,
                                        ),
                                      ),
                                    if (customer.address != null &&
                                        customer.address!.isNotEmpty)
                                      Text(
                                        customer.address!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Balance / totals
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _statItem(
                                    "Balance",
                                    "₹${NumberFormat('#,##,###.00').format(customer.balance.abs())}",
                                    customer.balance > 0
                                        ? AppColors.creditRed
                                        : AppColors.paymentGreen,
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 36,
                                  color: AppColors.divider,
                                ),
                                Expanded(
                                  child: _statItem(
                                    "Total Credit",
                                    "₹${NumberFormat('#,##,###.00').format(detailState.totalCredit)}",
                                    AppColors.creditRed,
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 36,
                                  color: AppColors.divider,
                                ),
                                Expanded(
                                  child: _statItem(
                                    "Total Paid",
                                    "₹${NumberFormat('#,##,###.00').format(detailState.totalPayment)}",
                                    AppColors.paymentGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Action buttons
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final columns =
                                  constraints.maxWidth >= 460 ? 3 : 2;
                              const gap = 10.0;

                              final width =
                                  (constraints.maxWidth -
                                          gap * (columns - 1)) /
                                      columns;

                              final buttons = <Widget>[
                                if (customer.phone != null &&
                                    customer.phone!.isNotEmpty)
                                  _responsiveActionBtn(
                                    Icons.call_rounded,
                                    "Call",
                                    AppColors.paymentGreen,
                                    () => _call(customer.phone!),
                                  ),
                                _responsiveActionBtn(
                                  Icons.chat_rounded,
                                  "WhatsApp",
                                  const Color(0xFF25D366),
                                  () => _sendWhatsApp(
                                    context,
                                    customer.id,
                                  ),
                                ),
                                _responsiveActionBtn(
                                  Icons.add_circle_rounded,
                                  "Add Entry",
                                  AppColors.primary,
                                  () => context.push(
                                    "/add-transaction?customerId=${customer.id}",
                                  ),
                                ),
                              ];

                              return Wrap(
                                spacing: gap,
                                runSpacing: gap,
                                children: buttons
                                    .map(
                                      (button) => SizedBox(
                                        width: width,
                                        child: button,
                                      ),
                                    )
                                    .toList(),
                              );
                            },
                          ),

                          const SizedBox(height: 4),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Text(
                        "Transaction History",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),

                  if (txState.isLoading)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    )
                  else if (txState.transactions.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: EmptyStateView(
                          icon: Icons.receipt_long_outlined,
                          titleHindi: "अभी कोई लेन-देन नहीं है",
                          titleEnglish: "No Transactions Yet",
                          messageHindi:
                              "इस ग्राहक के लिए अभी कोई लेन-देन नहीं है।",
                          messageEnglish:
                              "No transactions found for this customer.",
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, idx) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            child: TransactionTile(
                              transaction:
                                  txState.transactions[idx],
                            ),
                          );
                        },
                        childCount: txState.transactions.length,
                      ),
                    ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: 80),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _statItem(
    String label,
    String value,
    Color color,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _responsiveActionBtn(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return _actionBtn(
      icon,
      label,
      color,
      onTap,
    );
  }

  Widget _actionBtn(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _call(String phone) async {
    final cleaned = phone.replaceAll(
      RegExp(r'[^0-9+]'),
      '',
    );

    final uri = Uri.parse('tel:$cleaned');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _sendWhatsApp(
    BuildContext context,
    int customerId,
  ) {
    final detailState =
        ref.read(customerDetailProvider(widget.customerId));

    final customer = detailState.customer;

    if (customer == null) return;

    showDialog(
      context: context,
      builder: (_) => WhatsAppDialog(
        customerId: customerId,
        customerName: customer.name,
        balance: customer.balance,
        shopName: "KhataSetu",
        phone: customer.phone ?? "",
      ),
    );
  }

  void _showEditSheet(
    BuildContext context,
    dynamic customer,
  ) {
    final nameCtrl =
        TextEditingController(text: customer.name);

    final phoneCtrl =
        TextEditingController(text: customer.phone ?? "");

    final addressCtrl =
        TextEditingController(text: customer.address ?? "");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Edit Customer",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: "Name",
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "Phone",
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: addressCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: "Address",
                ),
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: () async {
                  final ok = await ref
                      .read(customerProvider.notifier)
                      .updateCustomer(
                        customerId: customer.id,
                        name: nameCtrl.text.trim(),
                        phone: phoneCtrl.text.trim().isEmpty
                            ? null
                            : phoneCtrl.text.trim(),
                        address:
                            addressCtrl.text.trim().isEmpty
                                ? null
                                : addressCtrl.text.trim(),
                      );

                  if (ok && mounted) {
                    Navigator.pop(ctx);

                    await ref
                        .read(
                          customerDetailProvider(
                            widget.customerId,
                          ).notifier,
                        )
                        .fetchDetail(widget.customerId);

                    await ref
                        .read(transactionProvider.notifier)
                        .fetchTransactions(
                          customerId: widget.customerId,
                        );
                  }
                },
                child: const Text("Save Changes"),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}