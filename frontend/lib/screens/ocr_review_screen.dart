import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../providers/scan_provider.dart';
import '../models/scan_model.dart';
import '../widgets/confidence_badge.dart';

class OcrReviewScreen extends ConsumerStatefulWidget {
  final int scanId;
  const OcrReviewScreen({super.key, required this.scanId});

  @override
  ConsumerState<OcrReviewScreen> createState() => _OcrReviewScreenState();
}

class _OcrReviewScreenState extends ConsumerState<OcrReviewScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(scanProvider.notifier).loadScan(widget.scanId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(scanProvider);
    final scan = scanState.currentScan;

    if (scanState.isLoading || scan == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("AI खाता समीक्षा")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final pending = scan.entries.where((e) => e.isPending).toList();
    final highConf = pending.where((e) => e.isHighConfidence).toList();
    final needsReview = pending.where((e) => !e.isHighConfidence).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("AI ने ये entries पहचानी हैं", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            Text("कृपया सेव करने से पहले जाँच लें (Review Entries)", style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
        actions: [
          if (pending.isEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: TextButton.icon(
                onPressed: () => context.go("/home"),
                icon: const Icon(Icons.check_circle_rounded, color: AppColors.paymentGreen),
                label: const Text("पूर्ण ✓ / Done", style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ─── Scan Image Header + Progress Strip ───────────────────────
          _buildImageHeader(scan, pending, scan.entries),

          // ─── Entry Cards List ─────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              children: [
                // HIGH CONFIDENCE section
                if (highConf.isNotEmpty) ...[
                  _sectionHeader("उच्च सटीकता / HIGH CONFIDENCE", highConf.length, AppColors.paymentGreen),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: OutlinedButton.icon(
                      onPressed: () => _batchConfirmHigh(context),
                      icon: const Icon(Icons.done_all_rounded, size: 18),
                      label: Text("सभी ${highConf.length} सही प्रविष्टियों की पुष्टि करें (Auto-Confirm)"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.paymentGreen,
                        side: const BorderSide(color: AppColors.paymentGreen, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  ...highConf.map((e) => _EntryCard(entry: e, scanId: widget.scanId)),
                ],

                // NEEDS REVIEW section
                if (needsReview.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _sectionHeader("समीक्षा आवश्यक / NEEDS YOUR REVIEW", needsReview.length, AppColors.saffron),
                  ...needsReview.map((e) => _EntryCard(entry: e, scanId: widget.scanId)),
                ],

                // Already processed
                if (scan.entries.any((e) => !e.isPending)) ...[
                  const SizedBox(height: 12),
                  _sectionHeader(
                    "पुष्टीकृत प्रविष्टियाँ / PROCESSED",
                    scan.entries.where((e) => !e.isPending).length,
                    AppColors.textMuted,
                  ),
                  ...scan.entries
                      .where((e) => !e.isPending)
                      .map((e) => _EntryCard(entry: e, scanId: widget.scanId, readOnly: true)),
                ],
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: pending.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: ElevatedButton(
                  onPressed: () => context.go("/home"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text("प्रगति सेव करें और मुख्य पृष्ठ पर जाएँ (Save Progress & Return Home)"),
                ),
              ),
            )
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: ElevatedButton.icon(
                  onPressed: () => context.go("/home"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.paymentGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.check_rounded, color: Colors.white),
                  label: const Text("सभी प्रविष्टियाँ दर्ज हो गईं! डैशबोर्ड देखें (All Done!)"),
                ),
              ),
            ),
    );
  }

  Future<void> _batchConfirmHigh(BuildContext context) async {
    final result = await ref.read(scanProvider.notifier).batchConfirmHighConfidence(widget.scanId);
    if (result && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("उच्च सटीकता वाली प्रविष्टियों की पुष्टि हो गई और खाते में जुड़ गईं!"),
          backgroundColor: AppColors.paymentGreen,
        ),
      );
    }
  }

  Widget _buildImageHeader(ScanModel scan, List<ScanEntryModel> pending, List<ScanEntryModel> all) {
    final pct = all.isEmpty ? 0 : ((all.length - pending.length) / all.length);
    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          if (scan.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                scan.imageUrl!,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 72,
                  height: 72,
                  color: AppColors.divider,
                  child: const Icon(Icons.image_not_supported_outlined, color: AppColors.textMuted),
                ),
              ),
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${all.length} प्रविष्टियाँ मिलीं (${all.length} entries detected)",
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct.toDouble(),
                    minHeight: 8,
                    backgroundColor: AppColors.divider,
                    valueColor: const AlwaysStoppedAnimation(AppColors.paymentGreen),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${all.length - pending.length} / ${all.length} की पुष्टि हो चुकी है",
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String label, int count, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Container(width: 4, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.8)),
            const SizedBox(width: 8),
            Text("($count)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color.withOpacity(0.8))),
          ],
        ),
      );
}

class _EntryCard extends ConsumerStatefulWidget {
  final ScanEntryModel entry;
  final int scanId;
  final bool readOnly;

  const _EntryCard({required this.entry, required this.scanId, this.readOnly = false});

  @override
  ConsumerState<_EntryCard> createState() => _EntryCardState();
}

class _EntryCardState extends ConsumerState<_EntryCard> {
  bool _isEditing = false;
  late TextEditingController _nameCtrl;
  late TextEditingController _amountCtrl;
  late TextEditingController _notesCtrl;
  String _selectedType = "CREDIT";
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.entry.customerName ?? "");
    _amountCtrl = TextEditingController(text: widget.entry.amount?.toStringAsFixed(2) ?? "");
    _notesCtrl = TextEditingController(text: widget.entry.notes ?? "");
    _selectedType = widget.entry.transactionType ?? "CREDIT";
    _selectedDate = widget.entry.date;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    await ref.read(scanProvider.notifier).confirmEntry(widget.scanId, widget.entry.id);
  }

  Future<void> _editAndConfirm() async {
    await ref.read(scanProvider.notifier).editAndConfirmEntry(
      widget.scanId,
      widget.entry.id,
      customerName: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
      amount: double.tryParse(_amountCtrl.text),
      transactionType: _selectedType,
      date: _selectedDate,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );
    if (mounted) setState(() => _isEditing = false);
  }

  Future<void> _reject() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("प्रविष्टि हटाएँ? (Reject Entry)", style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text("यह प्रविष्टि हटा दी जाएगी और ग्राहक के बहीखाते में नहीं जुड़ेगी।"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("रद्द करें (Cancel)")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.creditRed),
            child: const Text("हटाएँ (Reject)", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(scanProvider.notifier).rejectEntry(widget.scanId, widget.entry.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final fmt = NumberFormat('#,##,###.00');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        border: Border.all(
          color: widget.readOnly
              ? AppColors.divider
              : e.isHighConfidence
                  ? AppColors.paymentGreen.withOpacity(0.3)
                  : AppColors.saffron.withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Confidence Badge & Status ─────────────────────────────
            Row(
              children: [
                Expanded(
                  child: ConfidenceBadge(
                    band: e.confidenceBand,
                    score: e.overallConfidence,
                  ),
                ),
                if (!widget.readOnly) ...[
                  if (e.status == "CONFIRMED" || e.status == "EDITED_CONFIRMED")
                    const Icon(Icons.check_circle_rounded, color: AppColors.paymentGreen, size: 20)
                  else if (e.status == "REJECTED")
                    const Icon(Icons.cancel_rounded, color: AppColors.creditRed, size: 20),
                ],
              ],
            ),
            const SizedBox(height: 10),

            if (!_isEditing) ...[
              _infoRow(Icons.person_outline, "ग्राहक (Customer)", e.customerName ?? "अज्ञात (Unknown)"),
              _infoRow(
                Icons.currency_rupee_rounded,
                "रकम (Amount)",
                e.amount != null ? "₹${fmt.format(e.amount!)}" : "N/A",
                highlight: true,
              ),
              _infoRow(
                Icons.calendar_today_outlined,
                "दिनांक (Date)",
                e.date != null ? DateFormat("dd MMM yyyy").format(e.date!) : "N/A",
              ),
              _infoRow(
                e.transactionType == "CREDIT" ? Icons.arrow_outward_rounded : Icons.arrow_downward_rounded,
                "प्रकार (Type)",
                e.transactionType == "CREDIT" ? "उधार दिया (Credit)" : "जमा प्राप्त (Payment)",
              ),
              if (e.rawText != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.divider.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.text_fields_rounded, size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "पहचाना गया टेक्स्ट: ${e.rawText!}",
                          style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontFamily: 'monospace'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ] else ...[
              // ── Edit Form ─────────────────────────────────────────
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: "ग्राहक का नाम (Customer Name)", prefixIcon: Icon(Icons.person_outline)),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "रकम ₹ (Amount)", prefixIcon: Icon(Icons.currency_rupee_rounded)),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedType,
                items: const [
                  DropdownMenuItem(value: "CREDIT", child: Text("उधार दिया (CREDIT)")),
                  DropdownMenuItem(value: "PAYMENT", child: Text("जमा प्राप्त (PAYMENT)")),
                ],
                onChanged: (v) => setState(() => _selectedType = v!),
                decoration: const InputDecoration(labelText: "लेन-देन का प्रकार"),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
                child: AbsorbPointer(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: "दिनांक (Date)",
                      prefixIcon: const Icon(Icons.calendar_today_outlined),
                      hintText: _selectedDate != null ? DateFormat("dd MMM yyyy").format(_selectedDate!) : "तारीख चुनें",
                    ),
                    controller: TextEditingController(
                      text: _selectedDate != null ? DateFormat("dd MMM yyyy").format(_selectedDate!) : "",
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(labelText: "विवरण (Notes - Optional)", prefixIcon: Icon(Icons.notes_rounded)),
              ),
            ],

            // ── Action buttons ────────────────────────────────────────
            if (!widget.readOnly && e.isPending) ...[
              const SizedBox(height: 12),
              if (!_isEditing)
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: ElevatedButton.icon(
                        onPressed: _confirm,
                        icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                        label: const Text("पुष्टि करें (Confirm)"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.paymentGreen,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => _isEditing = true),
                        icon: const Icon(Icons.edit_rounded, size: 16),
                        label: const Text("संपादित करें (Edit)"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _reject,
                      icon: const Icon(Icons.close_rounded),
                      tooltip: "हटाएँ (Reject)",
                      style: IconButton.styleFrom(
                        foregroundColor: AppColors.creditRed,
                        backgroundColor: AppColors.creditRed.withOpacity(0.08),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _editAndConfirm,
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                        child: const Text("सेव करें और पुष्टि करें"),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => setState(() => _isEditing = false),
                      child: const Text("रद्द करें"),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {bool highlight = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Icon(icon, size: 14, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Text("$label: ", style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
                  color: highlight ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      );
}
