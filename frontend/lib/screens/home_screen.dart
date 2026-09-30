import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/kpi_card.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/empty_state_view.dart';
import '../models/dashboard_model.dart';
import '../models/transaction_model.dart';
import '../providers/scan_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dashboardProvider.notifier).fetchSummary();
      ref.read(scanProvider.notifier).fetchScanHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final dashState = ref.watch(dashboardProvider);
    final scanState = ref.watch(scanProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final greeting = _getGreeting();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              ref.read(dashboardProvider.notifier).fetchSummary(),
              ref.read(scanProvider.notifier).fetchScanHistory(),
            ]);
          },
          child: CustomScrollView(
            slivers: [
              // ─── Header: Shopkeeper Greeting & Store Name ─────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF131B2E), const Color(0xFF1E293B)]
                            : [Colors.white, const Color(0xFFF1F5F9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Store Icon Avatar
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.primaryLight],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                greeting,
                                style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                auth.ownerName.isNotEmpty ? auth.ownerName : "दुकानदार (Shopkeeper)",
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.verified_rounded, size: 14, color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      auth.shopName.isNotEmpty ? auth.shopName : "मेरी किराना दुकान",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Pending Review Badge if any
                        if ((dashState.summary?.pendingReviewsCount ?? 0) > 0)
                          GestureDetector(
                            onTap: () {
                              if (dashState.summary!.pendingReviews.isNotEmpty) {
                                context.push("/scan-review/${dashState.summary!.pendingReviews.first.scanId}");
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.pending_actions_rounded, size: 14, color: Color(0xFFB45309)),
                                  const SizedBox(width: 4),
                                  Text(
                                    "${dashState.summary!.pendingReviewsCount} जाँच",
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFFB45309)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // ─── GRAND CTA — 📷 खाता स्कैन करें (Scan Paper Khata) ─────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: InkWell(
                    onTap: () => context.push("/scanner"),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F766E), Color(0xFF134E4A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Text("📷", style: TextStyle(fontSize: 28)),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      "📷 खाता स्कैन करें",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 17,
                                      ),
                                    ),
                                    SizedBox(width: 6),
                                    Icon(Icons.auto_awesome, color: Color(0xFFFDE68A), size: 16),
                                  ],
                                ),
                                SizedBox(height: 3),
                                Text(
                                  "Scan Paper Khata",
                                  style: TextStyle(color: Color(0xFFFDE68A), fontSize: 13, fontWeight: FontWeight.w700),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  "रजिस्टर पेज की फोटो लें और AI अपने आप नाम व रकम पहचान लेगा",
                                  style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.2),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ─── RECENT SCANS / SCAN HISTORY ──────────────────────────────
              if (scanState.scanHistory.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.history_rounded, size: 18, color: AppColors.primary),
                            SizedBox(width: 6),
                            Text(
                              "हाल के स्कैन / Recent Scans",
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () => context.push("/scanner"),
                          child: const Text("+ नया स्कैन (Scan)"),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 105,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      itemCount: scanState.scanHistory.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, idx) {
                        final scan = scanState.scanHistory[idx];
                        final isNeedsReview = scan.status == "REVIEW_NEEDED";
                        return InkWell(
                          onTap: () => context.push("/scan-review/${scan.id}"),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 195,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isNeedsReview
                                    ? Colors.orange.withOpacity(0.5)
                                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                width: isNeedsReview ? 1.5 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        "Scan #${scan.id}",
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isNeedsReview
                                            ? Colors.orange.withOpacity(0.15)
                                            : AppColors.paymentGreen.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isNeedsReview ? "समीक्षा बाकी" : "पुष्टीकृत",
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: isNeedsReview ? Colors.orange[800] : AppColors.paymentGreen,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "${scan.totalEntries} प्रविष्टियां दर्ज",
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      DateFormat("dd MMM, hh:mm a").format(scan.createdAt),
                                      style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],

              // ─── Quick Actions (4 Clear Pillars) ──────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text(
                            "त्वरित कार्य / Quick Actions",
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            "Khata Tools",
                            style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _actionTile(
                            context: context,
                            icon: Icons.person_add_alt_1_rounded,
                            hindiLabel: "ग्राहक जोड़ें",
                            englishLabel: "+ Customer",
                            color: const Color(0xFF0284C7),
                            onTap: () => context.push("/customers"),
                          ),
                          const SizedBox(width: 10),
                          _actionTile(
                            context: context,
                            icon: Icons.add_circle_outline_rounded,
                            hindiLabel: "लेन-देन जोड़ें",
                            englishLabel: "+ Entry",
                            color: AppColors.primary,
                            onTap: () => context.push("/add-transaction"),
                          ),
                          const SizedBox(width: 10),
                          _actionTile(
                            context: context,
                            icon: Icons.document_scanner_rounded,
                            hindiLabel: "खाता स्कैन",
                            englishLabel: "Scan Khata",
                            color: const Color(0xFFD97706),
                            onTap: () => context.push("/scanner"),
                          ),
                          const SizedBox(width: 10),
                          _actionTile(
                            context: context,
                            icon: Icons.bar_chart_rounded,
                            hindiLabel: "रिपोर्ट देखें",
                            englishLabel: "Analytics",
                            color: const Color(0xFF7C3AED),
                            onTap: () => context.push("/analytics"),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Financial KPI Cards (Correct Indian Khata Accounting) ───
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: dashState.isLoading
                      ? const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                      : dashState.summary == null
                          ? const SizedBox.shrink()
                          : Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: KpiCard(
                                        hindiTitle: "कुल बकाया",
                                        englishTitle: "Total Outstanding",
                                        value: "₹${NumberFormat('#,##,###.00').format(dashState.summary!.totalOutstanding)}",
                                        icon: Icons.account_balance_wallet_rounded,
                                        iconColor: AppColors.creditRed,
                                        subtitle: "${dashState.summary!.totalCustomers} ग्राहकों का बकाया",
                                        onTap: () => context.push("/customers"),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: KpiCard(
                                        hindiTitle: "आज का उधार",
                                        englishTitle: "Today's Udhaar (Credit)",
                                        value: "₹${NumberFormat('#,##,###.00').format(dashState.summary!.todayCredit)}",
                                        icon: Icons.arrow_outward_rounded,
                                        iconColor: AppColors.creditRed,
                                        subtitle: "आज दिया गया उधार",
                                        onTap: () => context.push("/ledger"),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: KpiCard(
                                        hindiTitle: "आज की जमा",
                                        englishTitle: "Today's Jama (Collection)",
                                        value: "₹${NumberFormat('#,##,###.00').format(dashState.summary!.todayPayment)}",
                                        icon: Icons.arrow_downward_rounded,
                                        iconColor: AppColors.paymentGreen,
                                        subtitle: "आज प्राप्त हुआ भुगतान",
                                        onTap: () => context.push("/ledger"),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: KpiCard(
                                        hindiTitle: "स्कैन किए खाते",
                                        englishTitle: "Scans Done",
                                        value: "${dashState.summary!.totalScans}",
                                        icon: Icons.document_scanner_rounded,
                                        iconColor: AppColors.primary,
                                        subtitle: dashState.summary?.pendingReviewsCount != null && dashState.summary!.pendingReviewsCount > 0
                                            ? "${dashState.summary!.pendingReviewsCount} समीक्षा बाकी"
                                            : "${dashState.summary!.totalCustomers} कुल ग्राहक",
                                        onTap: () => context.push("/scanner"),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                ),
              ),

              // ─── 7-Day Cashflow Trend ─────────────────────────────────────
              if (dashState.summary != null && dashState.summary!.trendChart.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
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
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "7 दिन का ट्रेंड / 7-Day Trend",
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                                  ),
                                  Text(
                                    "Cashflow comparison",
                                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  _legendDot(AppColors.creditRed, "उधार (Credit)"),
                                  const SizedBox(width: 12),
                                  _legendDot(AppColors.paymentGreen, "जमा (Payment)"),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 160,
                            child: BarChart(
                              BarChartData(
                                barGroups: _buildBarGroups(dashState.summary!.trendChart),
                                borderData: FlBorderData(show: false),
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                  getDrawingHorizontalLine: (value) => FlLine(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                    strokeWidth: 1,
                                  ),
                                ),
                                titlesData: FlTitlesData(
                                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (x, meta) {
                                        final idx = x.toInt();
                                        final points = dashState.summary!.trendChart;
                                        if (idx >= 0 && idx < points.length) {
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 6),
                                            child: Text(
                                              points[idx].label,
                                              style: const TextStyle(fontSize: 9, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                                            ),
                                          );
                                        }
                                        return const SizedBox.shrink();
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ─── Recent Activity / हाल के लेन-देन ──────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "हाल के लेन-देन / Recent Activity",
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            "Latest khata ledger entries",
                            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: () => context.push("/ledger"),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                        label: const Text(
                          "सभी देखें (See All)",
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (dashState.summary == null || dashState.summary!.recentTransactions.isEmpty)
                SliverToBoxAdapter(
                  child: EmptyStateView(
                    icon: Icons.receipt_long_outlined,
                    titleHindi: "अभी कोई लेन-देन नहीं है",
                    titleEnglish: "No Transactions Yet",
                    messageHindi: "कागज़ी खाता स्कैन करें या नया लेन-देन जोड़ें।",
                    messageEnglish: "Scan your paper register or add a manual entry to get started.",
                    buttonText: "+ नया लेन-देन जोड़ें",
                    onButtonPressed: () => context.push("/add-transaction"),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, idx) {
                      final rt = dashState.summary!.recentTransactions[idx];
                      final tx = TransactionModel(
                        id: rt.id,
                        shopId: 0,
                        customerId: rt.customerId,
                        customerName: rt.customerName,
                        amount: rt.amount,
                        transactionType: rt.transactionType,
                        date: rt.date,
                        source: rt.source,
                      );
                      return TransactionTile(
                        transaction: tx,
                        onTap: () => context.push("/customer/${rt.customerId}"),
                      );
                    },
                    childCount: dashState.summary!.recentTransactions.length,
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
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

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "सुप्रभात / Good Morning";
    if (hour < 17) return "नमस्कार / Good Afternoon";
    return "शुभ संध्या / Good Evening";
  }

  List<BarChartGroupData> _buildBarGroups(List<ChartDataPointModel> points) {
    return List.generate(points.length, (i) {
      final p = points[i];
      return BarChartGroupData(
        x: i,
        barsSpace: 4,
        barRods: [
          BarChartRodData(
            toY: p.credit,
            color: AppColors.creditRed.withOpacity(0.85),
            width: 8,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
          BarChartRodData(
            toY: p.payment,
            color: AppColors.paymentGreen.withOpacity(0.85),
            width: 8,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    });
  }

  Widget _legendDot(Color color, String label) => Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
        ],
      );

  Widget _actionTile({
    required BuildContext context,
    required IconData icon,
    required String hindiLabel,
    required String englishLabel,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(0.2),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                hindiLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                englishLabel,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
