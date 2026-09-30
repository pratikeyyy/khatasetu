import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../providers/dashboard_provider.dart';
import '../models/dashboard_model.dart';
import '../widgets/empty_state_view.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _selectedDays = 7;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dashboardProvider.notifier).fetchSummary(days: _selectedDays);
    });
  }

  void _onDaysChanged(int days) {
    setState(() => _selectedDays = days);
    ref.read(dashboardProvider.notifier).fetchSummary(days: days);
  }

  @override
  Widget build(BuildContext context) {
    final dashState = ref.watch(dashboardProvider);
    final summary = dashState.summary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("व्यापार विश्लेषण", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text("Business Analytics & Cashflow", style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: "रिफ्रेश (Refresh)",
            onPressed: () => ref.read(dashboardProvider.notifier).fetchSummary(days: _selectedDays),
          ),
        ],
      ),
      body: dashState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : summary == null
              ? EmptyStateView(
                  icon: Icons.bar_chart_rounded,
                  titleHindi: "डेटा लोड नहीं हो सका",
                  titleEnglish: "Failed to Load Analytics",
                  messageHindi: "कृपया सर्वर कनेक्शन की जाँच करें।",
                  messageEnglish: "Please check your network and backend connection.",
                  buttonText: "दोबारा कोशिश करें",
                  onButtonPressed: () => ref.read(dashboardProvider.notifier).fetchSummary(days: _selectedDays),
                )
              : RefreshIndicator(
                  onRefresh: () async => ref.read(dashboardProvider.notifier).fetchSummary(days: _selectedDays),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // ── Period Range Selector ─────────────────────────────────
                      Row(
                        children: [
                          const Text(
                            "अवधि / Period:",
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                          const SizedBox(width: 12),
                          _periodChip(7, "पिछले 7 दिन (7 Days)"),
                          const SizedBox(width: 8),
                          _periodChip(30, "पिछले 30 दिन (30 Days)"),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // ── Summary Cards Strip ──────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: _miniStatCard(
                              titleHindi: "कुल बकाया",
                              titleEnglish: "Outstanding",
                              value: "₹${NumberFormat('#,##,###.00').format(summary.totalOutstanding)}",
                              color: AppColors.creditRed,
                              icon: Icons.account_balance_wallet_rounded,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _miniStatCard(
                              titleHindi: "कुल ग्राहक",
                              titleEnglish: "Customers",
                              value: "${summary.totalCustomers}",
                              color: AppColors.primary,
                              icon: Icons.people_rounded,
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _miniStatCard(
                              titleHindi: "आज का उधार",
                              titleEnglish: "Today's Credit",
                              value: "₹${NumberFormat('#,##,###.00').format(summary.todayCredit)}",
                              color: AppColors.creditRed,
                              icon: Icons.arrow_outward_rounded,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _miniStatCard(
                              titleHindi: "आज की जमा",
                              titleEnglish: "Today's Payment",
                              value: "₹${NumberFormat('#,##,###.00').format(summary.todayPayment)}",
                              color: AppColors.paymentGreen,
                              icon: Icons.arrow_downward_rounded,
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── Bar Chart Card ───────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "उधार बनाम जमा ट्रेंड ($_selectedDays दिन)",
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text("Credit vs Collection Cashflow Trend", style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _legendIndicator(AppColors.creditRed, "उधार दिया (Credit)"),
                                const SizedBox(width: 16),
                                _legendIndicator(AppColors.paymentGreen, "जमा प्राप्त (Payment)"),
                              ],
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 240,
                              child: summary.trendChart.isEmpty
                                  ? const EmptyStateView(
                                      icon: Icons.bar_chart_outlined,
                                      titleHindi: "अभी पर्याप्त लेन-देन डेटा नहीं है",
                                      titleEnglish: "Not Enough Data",
                                      messageHindi: "लेन-देन जोड़ें और अपना बिज़नेस ट्रेंड देखें।",
                                    )
                                  : BarChart(
                                      BarChartData(
                                        alignment: BarChartAlignment.spaceAround,
                                        barGroups: _generateGroups(summary.trendChart),
                                        titlesData: FlTitlesData(
                                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                          bottomTitles: AxisTitles(
                                            sideTitles: SideTitles(
                                              showTitles: true,
                                              getTitlesWidget: (value, meta) {
                                                final idx = value.toInt();
                                                if (idx >= 0 && idx < summary.trendChart.length) {
                                                  return Padding(
                                                    padding: const EdgeInsets.only(top: 8),
                                                    child: Text(
                                                      summary.trendChart[idx].label,
                                                      style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                                                    ),
                                                  );
                                                }
                                                return const Text("");
                                              },
                                            ),
                                          ),
                                        ),
                                        gridData: FlGridData(
                                          show: true,
                                          drawVerticalLine: false,
                                          getDrawingHorizontalLine: (val) => FlLine(
                                            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                            strokeWidth: 1,
                                          ),
                                        ),
                                        borderData: FlBorderData(show: false),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Scans & Audit Stats ─────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "खाता डिजिटाइजेशन सांख्यिकी (Scan Statistics)",
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _auditCol("कुल स्कैन", "${summary.totalScans}", AppColors.primary),
                                Container(width: 1, height: 32, color: AppColors.divider),
                                _auditCol("समीक्षा बाकी", "${summary.pendingReviewsCount}", AppColors.saffron),
                                Container(width: 1, height: 32, color: AppColors.divider),
                                _auditCol("कुल ग्राहक", "${summary.totalCustomers}", AppColors.paymentGreen),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
    );
  }

  Widget _miniStatCard({
    required String titleHindi,
    required String titleEnglish,
    required String value,
    required Color color,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titleHindi, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700), maxLines: 1),
                Text(titleEnglish, style: const TextStyle(fontSize: 10, color: AppColors.textMuted), maxLines: 1),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _auditCol(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _periodChip(int days, String label) {
    final isSelected = _selectedDays == days;
    return InkWell(
      onTap: () => _onDaysChanged(days),
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

  Widget _legendIndicator(Color color, String label) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      ],
    );
  }

  List<BarChartGroupData> _generateGroups(List<ChartDataPointModel> data) {
    return List.generate(data.length, (idx) {
      final p = data[idx];
      return BarChartGroupData(
        x: idx,
        barRods: [
          BarChartRodData(
            toY: p.credit,
            color: AppColors.creditRed.withOpacity(0.85),
            width: 10,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
          BarChartRodData(
            toY: p.payment,
            color: AppColors.paymentGreen.withOpacity(0.85),
            width: 10,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    });
  }
}
