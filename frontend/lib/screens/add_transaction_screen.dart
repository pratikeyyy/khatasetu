import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../providers/customer_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/dashboard_provider.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final int? prefilledCustomerId;
  const AddTransactionScreen({super.key, this.prefilledCustomerId});

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _customerSearchCtrl = TextEditingController();

  // "CREDIT" = उधार दिया (Customer owes money)
  // "PAYMENT" = जमा प्राप्त (Customer pays money)
  String _txType = "CREDIT";
  String _paymentMode = "Cash";
  final List<Map<String, dynamic>> _paymentModes = [
    {"id": "Cash", "label": "Cash / नकद", "icon": Icons.payments_outlined},
    {"id": "UPI", "label": "UPI", "icon": Icons.qr_code_2_rounded},
    {"id": "Card", "label": "Card / कार्ड", "icon": Icons.credit_card_rounded},
    {"id": "Bank Transfer", "label": "Bank Transfer / बैंक ट्रांसफर", "icon": Icons.account_balance_rounded},
    {"id": "Cheque", "label": "Cheque / चेक", "icon": Icons.receipt_long_rounded},
    {"id": "Other", "label": "Other / अन्य", "icon": Icons.more_horiz_rounded},
  ];
  DateTime _date = DateTime.now();
  int? _selectedCustomerId;
  bool _showCustomerDropdown = false;
  String? _duplicateWarning;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(customerProvider.notifier).fetchCustomers();
      if (widget.prefilledCustomerId != null) {
        final customers = ref.read(customerProvider).customers;
        final c = customers.where((c) => c.id == widget.prefilledCustomerId).firstOrNull;
        if (c != null) {
          setState(() {
            _selectedCustomerId = c.id;
            _customerSearchCtrl.text = c.name;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    _customerSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkDuplicate() async {
    if (_selectedCustomerId == null || _amountCtrl.text.isEmpty) return;
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null) return;

    final isDuplicate = await ref.read(transactionProvider.notifier).checkDuplicate(
      customerId: _selectedCustomerId!,
      amount: amount,
      transactionType: _txType,
      date: _date,
    );

    setState(() {
      _duplicateWarning = isDuplicate
          ? "⚠️ चेतावनी: इस ग्राहक के लिए पिछले 24 घंटे में ₹${amount.toStringAsFixed(2)} का समान लेन-देन मौजूद है। क्या आप निश्चित हैं?"
          : null;
    });
  }

  Future<void> _submit({bool force = false}) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("कृपया लेन-देन के लिए ग्राहक चुनें"),
          backgroundColor: AppColors.creditRed,
        ),
      );
      return;
    }

    final amount = double.parse(_amountCtrl.text);

    final ok = await ref.read(transactionProvider.notifier).addTransaction(
      customerId: _selectedCustomerId!,
      amount: amount,
      transactionType: _txType,
      date: _date,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      paymentMode: _txType == "PAYMENT" ? _paymentMode : null,
      force: force,
    );

    if (ok && mounted) {
      // Refresh dashboard summary and customers list
      ref.read(dashboardProvider.notifier).fetchSummary();
      ref.read(customerProvider.notifier).fetchCustomers();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "₹${amount.toStringAsFixed(2)} का लेन-देन (${_txType == "CREDIT" ? "उधार दिया" : "जमा प्राप्त"}) सफलतापूर्वक दर्ज हुआ!",
          ),
          backgroundColor: AppColors.paymentGreen,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final customerState = ref.watch(customerProvider);
    final txState = ref.watch(transactionProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredCustomers = customerState.customers.where((c) {
      final q = _customerSearchCtrl.text.toLowerCase();
      return c.name.toLowerCase().contains(q) || (c.phone != null && c.phone!.contains(q));
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("नया लेन-देन जोड़ें", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            Text("Add Udhaar / Jama Transaction", style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── 1. TRANSACTION TYPE SELECTOR (Big, Unambiguous) ───────────
              const Text(
                "लेन-देन का प्रकार चुनें (Transaction Type):",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  // Credit / उधार दिया
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() => _txType = "CREDIT");
                        _checkDuplicate();
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                        decoration: BoxDecoration(
                          color: _txType == "CREDIT"
                              ? AppColors.creditRed.withOpacity(0.12)
                              : (isDark ? const Color(0xFF1E293B) : Colors.white),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _txType == "CREDIT" ? AppColors.creditRed : AppColors.divider,
                            width: _txType == "CREDIT" ? 2.5 : 1,
                          ),
                          boxShadow: _txType == "CREDIT"
                              ? [
                                  BoxShadow(
                                    color: AppColors.creditRed.withOpacity(0.15),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ]
                              : [],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.arrow_outward_rounded,
                                  color: _txType == "CREDIT" ? AppColors.creditRed : AppColors.textMuted,
                                  size: 22,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "उधार दिया",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: _txType == "CREDIT" ? AppColors.creditRed : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Customer owes money",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _txType == "CREDIT" ? AppColors.creditRed : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Payment / जमा प्राप्त
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() => _txType = "PAYMENT");
                        _checkDuplicate();
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                        decoration: BoxDecoration(
                          color: _txType == "PAYMENT"
                              ? AppColors.paymentGreen.withOpacity(0.12)
                              : (isDark ? const Color(0xFF1E293B) : Colors.white),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _txType == "PAYMENT" ? AppColors.paymentGreen : AppColors.divider,
                            width: _txType == "PAYMENT" ? 2.5 : 1,
                          ),
                          boxShadow: _txType == "PAYMENT"
                              ? [
                                  BoxShadow(
                                    color: AppColors.paymentGreen.withOpacity(0.15),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ]
                              : [],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.arrow_downward_rounded,
                                  color: _txType == "PAYMENT" ? AppColors.paymentGreen : AppColors.textMuted,
                                  size: 22,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "जमा प्राप्त",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: _txType == "PAYMENT" ? AppColors.paymentGreen : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Customer paid money",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _txType == "PAYMENT" ? AppColors.paymentGreen : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // ─── 2. SELECT CUSTOMER ────────────────────────────────────────
              const Text(
                "ग्राहक चुनें (Select Customer):",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _customerSearchCtrl,
                onTap: () => setState(() => _showCustomerDropdown = true),
                onChanged: (_) => setState(() => _showCustomerDropdown = true),
                decoration: InputDecoration(
                  hintText: "ग्राहक खोजें या चुनें...",
                  prefixIcon: const Icon(Icons.person_search_rounded, color: AppColors.primary),
                  suffixIcon: _selectedCustomerId != null
                      ? IconButton(
                          icon: const Icon(Icons.check_circle_rounded, color: AppColors.paymentGreen),
                          onPressed: () {},
                        )
                      : null,
                ),
              ),

              // Dropdown suggestions
              if (_showCustomerDropdown)
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.divider),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))
                    ],
                  ),
                  child: filteredCustomers.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text("कोई ग्राहक नहीं मिला। कृपया Customers टैब से जोड़ें।", style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: filteredCustomers.length,
                          itemBuilder: (ctx, idx) {
                            final c = filteredCustomers[idx];
                            return ListTile(
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor: AppColors.primary.withOpacity(0.12),
                                child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : "?", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                              title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                              subtitle: Text(c.phone ?? "बकाया: ₹${c.balance.toStringAsFixed(2)}", style: const TextStyle(fontSize: 11)),
                              onTap: () {
                                setState(() {
                                  _selectedCustomerId = c.id;
                                  _customerSearchCtrl.text = c.name;
                                  _showCustomerDropdown = false;
                                });
                                _checkDuplicate();
                              },
                            );
                          },
                        ),
                ),
              const SizedBox(height: 20),

              // ─── 3. AMOUNT ────────────────────────────────────────────────
              const Text(
                "रकम दर्ज करें (Amount in Rupees):",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                decoration: const InputDecoration(
                  prefixText: "₹ ",
                  prefixStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primary),
                  hintText: "0.00",
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return "कृपया रकम दर्ज करें";
                  final num = double.tryParse(val.trim());
                  if (num == null || num <= 0) return "कृपया मान्य रकम दर्ज करें (0 से अधिक)";
                  return null;
                },
                onChanged: (_) => _checkDuplicate(),
              ),
              const SizedBox(height: 20),

              // ─── PAYMENT MODE (Only for PAYMENT / जमा) ────────
              if (_txType == "PAYMENT") ...[
                Row(
                  children: [
                    const Text(
                      "भुगतान का माध्यम (Payment Mode):",
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.paymentGreen.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        "जमा के लिए",
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.paymentGreen),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _paymentModes.map((mode) {
                    final isSelected = _paymentMode == mode["id"];
                    return ChoiceChip(
                      avatar: Icon(
                        mode["icon"] as IconData,
                        size: 16,
                        color: isSelected ? Colors.white : AppColors.primary,
                      ),
                      label: Text(mode["label"] as String),
                      selected: isSelected,
                      selectedColor: AppColors.paymentGreen,
                      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppColors.textPrimary),
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                        fontSize: 12,
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _paymentMode = mode["id"] as String);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
              ],

              // ─── 4. DATE SELECTOR ─────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("दिनांक (Date):", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _date,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(const Duration(days: 1)),
                            );
                            if (picked != null) {
                              setState(() => _date = picked);
                              _checkDuplicate();
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primary),
                                const SizedBox(width: 10),
                                Text(
                                  DateFormat("dd MMM yyyy").format(_date),
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ─── 5. NOTES (Optional) ──────────────────────────────────────
              const Text(
                "विवरण / सामान की जानकारी (Note - Optional):",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  hintText: "उदा. दाल, तेल, चीनी, बिस्किट...",
                  prefixIcon: Icon(Icons.note_alt_outlined),
                ),
              ),
              const SizedBox(height: 20),

              // Duplicate warning banner if any
              if (_duplicateWarning != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _duplicateWarning!,
                        style: const TextStyle(color: Color(0xFF92400E), fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => _submit(force: true),
                            child: const Text("हाँ, फिर भी सेव करें (Force Save)", style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFB45309))),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ─── SUBMIT BUTTON ────────────────────────────────────────────
              ElevatedButton(
                onPressed: txState.isLoading ? null : () => _submit(force: false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _txType == "CREDIT" ? AppColors.creditRed : AppColors.paymentGreen,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: txState.isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _txType == "CREDIT" ? Icons.arrow_outward_rounded : Icons.arrow_downward_rounded,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _txType == "CREDIT" ? "उधार सेव करें / Save Credit" : "जमा सेव करें / Save Payment",
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
