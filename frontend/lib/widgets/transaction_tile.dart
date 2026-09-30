import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../models/transaction_model.dart';

class TransactionTile extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback? onTap;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isCredit = transaction.transactionType.toUpperCase() == "CREDIT";
    final amountColor = isCredit ? AppColors.creditRed : AppColors.paymentGreen;
    final formattedDate = DateFormat("dd MMM yyyy, hh:mm a").format(transaction.date);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Status Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: amountColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCredit ? Icons.arrow_outward_rounded : Icons.arrow_downward_rounded,
                color: amountColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),

            // Customer Name and Metadata
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          transaction.customerName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (transaction.source == "AI_SCAN")
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome, size: 10, color: AppColors.primary),
                              SizedBox(width: 3),
                              Text(
                                "AI Scan",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        formattedDate,
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                      if (transaction.notes != null && transaction.notes!.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        const Text("•", style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            transaction.notes!,
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontStyle: FontStyle.italic),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Amount and Accounting Label
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "₹${NumberFormat('#,##,###.00').format(transaction.amount)}",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: amountColor,
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: amountColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isCredit ? "उधार दिया (Credit)" : "जमा प्राप्त (Payment)",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: amountColor,
                    ),
                  ),
                ),
                if (!isCredit && transaction.paymentMode != null && transaction.paymentMode!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getPaymentModeIcon(transaction.paymentMode!),
                          size: 10,
                          color: isDark ? Colors.white70 : AppColors.textPrimary,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          transaction.paymentMode!,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getPaymentModeIcon(String mode) {
    final m = mode.toLowerCase();
    if (m.contains("upi")) return Icons.qr_code_2_rounded;
    if (m.contains("card")) return Icons.credit_card_rounded;
    if (m.contains("bank")) return Icons.account_balance_rounded;
    if (m.contains("cheque")) return Icons.receipt_long_rounded;
    if (m.contains("cash")) return Icons.payments_outlined;
    return Icons.payment_rounded;
  }
}
