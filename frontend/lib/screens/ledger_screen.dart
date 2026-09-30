import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../providers/transaction_provider.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/empty_state_view.dart';

class LedgerScreen extends ConsumerStatefulWidget {
  const LedgerScreen({super.key});

  @override
  ConsumerState<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends ConsumerState<LedgerScreen> {
  String? _selectedType;
  String? _selectedSource;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(transactionProvider.notifier).fetchTransactions();
    });
  }

  void _filter() {
    ref.read(transactionProvider.notifier).fetchTransactions(
      transactionType: _selectedType,
      source: _selectedSource,
    );
  }

  @override
  Widget build(BuildContext context) {
    final txState = ref.watch(transactionProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final totalCredit = txState.transactions
        .where((t) => t.transactionType.toUpperCase() == "CREDIT")
        .fold<double>(0.0, (sum, t) => sum + t.amount);

    final totalPayment = txState.transactions
        .where((t) => t.transactionType.toUpperCase() == "PAYMENT")
        .fold<double>(0.0, (sum, t) => sum + t.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("खाता लेजर", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text("Complete Transaction Ledger", style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: "रिफ्रेश (Refresh)",
            onPressed: _filter,
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: "नया लेन-देन (+ Entry)",
            onPressed: () => context.push("/add-transaction"),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter Bar ──────────────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _filterChip("सभी (All)", _selectedType == null, () {
                  setState(() => _selectedType = null);
                  _filter();
                }),
                const SizedBox(width: 8),
                _filterChip("उधार दिया (Credit)", _selectedType == "CREDIT", () {
                  setState(() => _selectedType = "CREDIT");
                  _filter();
                }, activeColor: AppColors.creditRed),
                const SizedBox(width: 8),
                _filterChip("जमा प्राप्त (Payment)", _selectedType == "PAYMENT", () {
                  setState(() => _selectedType = "PAYMENT");
                  _filter();
                }, activeColor: AppColors.paymentGreen),
                const SizedBox(width: 14),
                Container(width: 1.5, height: 22, color: AppColors.divider),
                const SizedBox(width: 14),
                _filterChip("सभी स्रोत (All Sources)", _selectedSource == null, () {
                  setState(() => _selectedSource = null);
                  _filter();
                }),
                const SizedBox(width: 8),
                _filterChip("AI स्कैन (Scanned)", _selectedSource == "AI_SCAN", () {
                  setState(() => _selectedSource = "AI_SCAN");
                  _filter();
                }, activeColor: AppColors.primary),
                const SizedBox(width: 8),
                _filterChip("मैन्युअल (Manual)", _selectedSource == "MANUAL", () {
                  setState(() => _selectedSource = "MANUAL");
                  _filter();
                }),
              ],
            ),
          ),

          // ── Totals Strip ────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.arrow_outward_rounded, size: 16, color: AppColors.creditRed),
                    const SizedBox(width: 4),
                    const Text("उधार: ", style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    Text(
                      "₹${NumberFormat('#,##,###.00').format(totalCredit)}",
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.creditRed),
                    ),
                  ],
                ),
                Container(width: 1, height: 16, color: AppColors.divider),
                Row(
                  children: [
                    const Icon(Icons.arrow_downward_rounded, size: 16, color: AppColors.paymentGreen),
                    const SizedBox(width: 4),
                    const Text("जमा: ", style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    Text(
                      "₹${NumberFormat('#,##,###.00').format(totalPayment)}",
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.paymentGreen),
                    ),
                  ],
                ),
                Container(width: 1, height: 16, color: AppColors.divider),
                Text(
                  "${txState.transactions.length} लेन-देन",
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // ── Transaction List ────────────────────────────────────────────
          Expanded(
            child: txState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : txState.transactions.isEmpty
                    ? EmptyStateView(
                        icon: Icons.receipt_long_outlined,
                        titleHindi: "कोई लेन-देन नहीं मिला",
                        titleEnglish: "No Transactions Found",
                        messageHindi: "फिल्टर बदलकर देखें या नया उधार/जमा लेन-देन दर्ज करें।",
                        messageEnglish: "Try clearing filters or add transactions through AI scanning or manual entry.",
                        buttonText: "+ लेन-देन जोड़ें",
                        onButtonPressed: () => context.push("/add-transaction"),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: txState.transactions.length,
                        itemBuilder: (context, index) {
                          final tx = txState.transactions[index];
                          return TransactionTile(
                            transaction: tx,
                            onTap: () => context.push("/customer/${tx.customerId}"),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push("/add-transaction"),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          "+ लेन-देन जोड़ें",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _filterChip(String label, bool isSelected, VoidCallback onTap, {Color? activeColor}) {
    final color = activeColor ?? AppColors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? color : AppColors.divider.withOpacity(0.5),
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
}
