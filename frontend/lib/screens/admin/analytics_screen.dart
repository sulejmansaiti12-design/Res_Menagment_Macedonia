import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../config/app_theme.dart';
import '../../services/api_client.dart';

double _toNum(dynamic v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

class AnalyticsScreen extends StatefulWidget {
  final ApiClient apiClient;
  const AnalyticsScreen({super.key, required this.apiClient});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  bool _isLoading = true;
  
  Map<String, dynamic>? _waiterStats;
  Map<String, dynamic>? _salesStats;
  Map<String, dynamic>? _itemStats;
  Map<String, dynamic>? _tableStats;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final startStr = _formatDateForApi(_startDate);
      final endStr = _formatDateForApi(_endDate);
      
      final results = await Future.wait([
        widget.apiClient.get('/admin/analytics/waiters?startDate=$startStr&endDate=$endStr'),
        widget.apiClient.get('/admin/analytics/sales?startDate=$startStr&endDate=$endStr'),
        widget.apiClient.get('/admin/analytics/items?startDate=$startStr&endDate=$endStr'),
        widget.apiClient.get('/admin/analytics/tables?startDate=$startStr&endDate=$endStr'),
      ]);

      setState(() {
        _waiterStats = results[0]['data'] as Map<String, dynamic>?;
        _salesStats = results[1]['data'] as Map<String, dynamic>?;
        _itemStats = results[2]['data'] as Map<String, dynamic>?;
        _tableStats = results[3]['data'] as Map<String, dynamic>?;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading analytics: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  String _formatDateForApi(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primary,
              surface: AppTheme.surface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadAllData();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // PDF PRINTING ENGINE
  // ══════════════════════════════════════════════════════════════════════════════
  Future<void> _printCurrentReport() async {
    final pdf = pw.Document();
    final tabIndex = _tabController.index;
    final dateRange = '${_startDate.day}/${_startDate.month}/${_startDate.year} - ${_endDate.day}/${_endDate.month}/${_endDate.year}';
    final title = ['Staff Performance Report', 'Sales & Revenue Report', 'Item Sales Report', 'Tables & Zones Report'][tabIndex];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          final content = <pw.Widget>[
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  pw.Text(dateRange, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                ]
              )
            ),
            pw.SizedBox(height: 20),
          ];

          if (tabIndex == 0) content.addAll(_buildWaitersPdf());
          else if (tabIndex == 1) content.addAll(_buildSalesPdf());
          else if (tabIndex == 2) content.addAll(_buildItemsPdf());
          else if (tabIndex == 3) content.addAll(_buildTablesPdf());

          return content;
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '${title.replaceAll(' ', '_')}_$dateRange.pdf',
    );
  }

  List<pw.Widget> _buildWaitersPdf() {
    final waiters = (_waiterStats?['waiters'] as List?) ?? [];
    if (waiters.isEmpty) return [pw.Text('No data available.')];

    return [
      pw.TableHelper.fromTextArray(
        headers: ['Rank', 'Staff Member', 'Shifts', 'Payments', 'Avg / Shift', 'Total Revenue'],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
        cellAlignment: pw.Alignment.centerLeft,
        data: List<List<String>>.generate(waiters.length, (i) {
          final w = waiters[i];
          final name = w['waiter']?['name'] ?? 'Unknown';
          return [
            '#${i + 1}',
            name,
            w['totalShifts'].toString(),
            w['totalPayments'].toString(),
            '${_toNum(w['avgRevenuePerShift']).toStringAsFixed(0)} MKD',
            '${_toNum(w['totalRevenue']).toStringAsFixed(0)} MKD',
          ];
        }),
      )
    ];
  }

  List<pw.Widget> _buildSalesPdf() {
    final summary = _salesStats?['summary'] as Map<String, dynamic>?;
    final daily = (_salesStats?['dailyBreakdown'] as List?) ?? [];
    if (summary == null && daily.isEmpty) return [pw.Text('No data available.')];

    return [
      pw.Text('Summary', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 10),
      pw.Text('Total Revenue: ${_toNum(summary?['totalRevenue']).toStringAsFixed(0)} MKD'),
      pw.Text('Fiscal Revenue: ${_toNum(summary?['fiscalRevenue']).toStringAsFixed(0)} MKD'),
      pw.Text('Off-Track Revenue: ${_toNum(summary?['offTrackRevenue']).toStringAsFixed(0)} MKD'),
      pw.Text('Total Payments: ${_toNum(summary?['paymentCount']).toStringAsFixed(0)}'),
      pw.SizedBox(height: 20),
      pw.Text('Daily Breakdown', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 10),
      pw.TableHelper.fromTextArray(
        headers: ['Date', 'Payments', 'Revenue'],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
        data: daily.map((d) => [
          d['date']?.toString() ?? '',
          d['count']?.toString() ?? '0',
          '${_toNum(d['revenue']).toStringAsFixed(0)} MKD',
        ]).toList(),
      )
    ];
  }

  List<pw.Widget> _buildItemsPdf() {
    final topItems = (_itemStats?['topItems'] as List?) ?? [];
    final cats = (_itemStats?['categoryBreakdown'] as List?) ?? [];

    return [
      pw.Text('Top Selling Items', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 10),
      pw.TableHelper.fromTextArray(
        headers: ['Item Name', 'Category', 'Quantity Sold', 'Revenue'],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
        data: topItems.map((i) => [
          i['item']?['name'] ?? 'Unknown',
          i['item']?['category'] ?? 'Unknown',
          i['quantitySold']?.toString() ?? '0',
          '${_toNum(i['revenue']).toStringAsFixed(0)} MKD',
        ]).toList(),
      ),
      pw.SizedBox(height: 20),
      pw.Text('Category Breakdown', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 10),
      pw.TableHelper.fromTextArray(
        headers: ['Category', 'Items Sold', 'Revenue'],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
        data: cats.map((c) => [
          c['category']?.toString() ?? 'Unknown',
          c['itemCount']?.toString() ?? '0',
          '${_toNum(c['revenue']).toStringAsFixed(0)} MKD',
        ]).toList(),
      )
    ];
  }

  List<pw.Widget> _buildTablesPdf() {
    final summary = _tableStats?['summary'] as Map<String, dynamic>?;
    final zones = (_tableStats?['zones'] as List?) ?? [];
    final tables = (_tableStats?['tables'] as List?) ?? [];

    return [
      pw.Text('Performance Summary', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 10),
      pw.Text('Total Sessions: ${_toNum(summary?['totalSessions']).toStringAsFixed(0)}'),
      pw.Text('Avg Turnover Time: ${_toNum(summary?['avgTurnoverMinutes']).toStringAsFixed(0)} min'),
      pw.Text('Total Revenue: ${_toNum(summary?['totalRevenue']).toStringAsFixed(0)} MKD'),
      pw.SizedBox(height: 20),
      pw.Text('Zone Performance', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 10),
      pw.TableHelper.fromTextArray(
        headers: ['Zone Name', 'Sessions', 'Orders', 'Revenue'],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
        data: zones.map((z) => [
          z['zone']?.toString() ?? 'Unknown',
          z['sessions']?.toString() ?? '0',
          z['orders']?.toString() ?? '0',
          '${_toNum(z['revenue']).toStringAsFixed(0)} MKD',
        ]).toList(),
      ),
      pw.SizedBox(height: 20),
      pw.Text('Top Performing Tables', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 10),
      pw.TableHelper.fromTextArray(
        headers: ['Table Name', 'Zone', 'Sessions', 'Avg Duration', 'Revenue'],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
        data: tables.map((t) => [
          t['table']?['name']?.toString() ?? 'Unknown',
          t['table']?['zone']?.toString() ?? 'Unknown',
          t['sessions']?.toString() ?? '0',
          '${_toNum(t['avgSessionDuration']).toStringAsFixed(0)} min',
          '${_toNum(t['totalRevenue']).toStringAsFixed(0)} MKD',
        ]).toList(),
      ),
    ];
  }

  Future<void> _print80mmWaiterReport(Map<String, dynamic> w) async {
    final pdf = pw.Document();
    
    final name = w['waiter']?['name'] ?? 'Unknown';
    final fiscalRev = _toNum(w['fiscalRevenue']);
    final offTrackRev = _toNum(w['offTrackRevenue']);
    final totalRev = _toNum(w['totalRevenue']);
    final shifts = w['totalShifts'];
    final payments = w['totalPayments'];

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text('STAFF PERFORMANCE', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Staff: $name'),
              pw.Text('Date range: ${_startDate.day}/${_startDate.month} - ${_endDate.day}/${_endDate.month}'),
              pw.Divider(),
              pw.SizedBox(height: 5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('ON-TRACK (Fiscal):'),
                  pw.Text('${fiscalRev.toStringAsFixed(0)} MKD'),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('OFF-TRACK:'),
                  pw.Text('${offTrackRev.toStringAsFixed(0)} MKD'),
                ],
              ),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL REVENUE:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('${totalRev.toStringAsFixed(0)} MKD', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Text('Shifts: $shifts'),
              pw.Text('Payments: $payments'),
              pw.SizedBox(height: 20),
              pw.Center(child: pw.Text('--- END OF REPORT ---')),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '${name}_performance_report.pdf',
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // UI BUILDERS
  // ══════════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          // Premium Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.surfaceDark.withValues(alpha: 0.9), AppTheme.surfaceDark.withValues(alpha: 0.5)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Analytics & Insights', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
                    const SizedBox(height: 4),
                    Text('Track your business performance in real-time', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
                  ],
                ),
                Row(
                  children: [
                    // Print Button
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                      ),
                      child: IconButton(
                        onPressed: _isLoading ? null : _printCurrentReport,
                        icon: const Icon(Icons.print_rounded, color: AppTheme.primaryLight),
                        tooltip: 'Print Report PDF',
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Date Picker Button
                    InkWell(
                      onTap: _pickDateRange,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_month_rounded, color: Colors.white.withValues(alpha: 0.7), size: 18),
                            const SizedBox(width: 8),
                            Text(
                              '${_startDate.day}/${_startDate.month} - ${_endDate.day}/${_endDate.month}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Custom TabBar
          Container(
            color: AppTheme.surfaceDark.withValues(alpha: 0.4),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: AppTheme.primary,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withValues(alpha: 0.4),
              labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              tabs: const [
                Tab(icon: Icon(Icons.people_alt_rounded), text: 'Staff Performance'),
                Tab(icon: Icon(Icons.trending_up_rounded), text: 'Sales Overview'),
                Tab(icon: Icon(Icons.fastfood_rounded), text: 'Item Sales'),
                Tab(icon: Icon(Icons.table_restaurant_rounded), text: 'Tables & Zones'),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildWaitersTab(),
                      _buildSalesTab(),
                      _buildItemsTab(),
                      _buildTablesTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // TAB BUILDERS
  // ══════════════════════════════════════════════════════════════════════════════

  Widget _buildWaitersTab() {
    final waiters = (_waiterStats?['waiters'] as List?) ?? [];
    if (waiters.isEmpty) return _emptyState('No staff performance data for this period');

    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              Expanded(child: _premiumStatCard('Active Staff', waiters.length.toString(), Icons.people_rounded, AppTheme.info)),
              const SizedBox(width: 16),
              Expanded(child: _premiumStatCard('Total Generated', '${_calculateTotalRevenue(waiters).toStringAsFixed(0)} MKD', Icons.account_balance_wallet_rounded, AppTheme.success)),
            ],
          ),
          const SizedBox(height: 32),
          const Text('Staff Leaderboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 16),
          ...waiters.asMap().entries.map((e) => _buildWaiterRankingCard(e.value as Map<String, dynamic>, e.key + 1)),
        ],
      ),
    );
  }

  Widget _buildSalesTab() {
    final summary = _salesStats?['summary'] as Map<String, dynamic>?;
    final peakHour = _salesStats?['peakHour'] as Map<String, dynamic>?;
    final hourlyBreakdown = (_salesStats?['hourlyBreakdown'] as List?) ?? [];
    final dailyBreakdown = (_salesStats?['dailyBreakdown'] as List?) ?? [];

    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              Expanded(child: _premiumStatCard('Total Revenue', '${_toNum(summary?['totalRevenue']).toStringAsFixed(0)} MKD', Icons.monetization_on_rounded, AppTheme.primary)),
              const SizedBox(width: 16),
              Expanded(child: _premiumStatCard('Fiscal (UJP)', '${_toNum(summary?['fiscalRevenue']).toStringAsFixed(0)} MKD', Icons.receipt_rounded, AppTheme.success)),
              const SizedBox(width: 16),
              Expanded(child: _premiumStatCard('Off-Track', '${_toNum(summary?['offTrackRevenue']).toStringAsFixed(0)} MKD', Icons.receipt_long_rounded, AppTheme.error)),
            ],
          ),
          const SizedBox(height: 32),
          if (peakHour != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppTheme.warning.withValues(alpha: 0.15), AppTheme.warning.withValues(alpha: 0.05)]),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: AppTheme.warning, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Peak Hour Output', style: TextStyle(color: AppTheme.warning, fontWeight: FontWeight.w800, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text('${peakHour['hour']}:00 - ${(peakHour['hour'] as int) + 1}:00 • Generated ${peakHour['revenue']?.toStringAsFixed(0) ?? '0'} MKD', 
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
          const Text('Daily Revenue Trend', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 16),
          ...dailyBreakdown.map((day) => _buildBasicListTile(
                day['date'] as String? ?? '', 
                '${_toNum(day['count']).toStringAsFixed(0)} transactions', 
                '${_toNum(day['revenue']).toStringAsFixed(0)} MKD'
              )),
        ],
      ),
    );
  }

  Widget _buildItemsTab() {
    final topItems = (_itemStats?['topItems'] as List?) ?? [];
    final cats = (_itemStats?['categoryBreakdown'] as List?) ?? [];
    final totalSold = _toNum(_itemStats?['totalItemsSold']);

    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _premiumStatCard('Total Items Sold', totalSold.toStringAsFixed(0), Icons.shopping_basket_rounded, AppTheme.primary),
          const SizedBox(height: 32),
          const Text('Top Performing Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 16),
          if (topItems.isEmpty) _emptyState('No item data available')
          else ...topItems.asMap().entries.map((e) => _buildItemCard(e.value as Map<String, dynamic>, e.key + 1)),
          const SizedBox(height: 32),
          const Text('Category Breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 16),
          ...cats.map((cat) => _buildBasicListTile(
            cat['category']?.toString() ?? 'Unknown',
            '${_toNum(cat['itemCount']).toStringAsFixed(0)} items sold',
            '${_toNum(cat['revenue']).toStringAsFixed(0)} MKD'
          )),
        ],
      ),
    );
  }

  Widget _buildTablesTab() {
    final summary = _tableStats?['summary'] as Map<String, dynamic>?;
    final zones = (_tableStats?['zones'] as List?) ?? [];
    final tables = (_tableStats?['tables'] as List?) ?? [];

    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              Expanded(child: _premiumStatCard('Table Sessions', '${_toNum(summary?['totalSessions']).toStringAsFixed(0)}', Icons.chair_alt_rounded, AppTheme.info)),
              const SizedBox(width: 16),
              Expanded(child: _premiumStatCard('Avg. Turnover', '${_toNum(summary?['avgTurnoverMinutes']).toStringAsFixed(0)} min', Icons.timer_rounded, AppTheme.warning)),
              const SizedBox(width: 16),
              Expanded(child: _premiumStatCard('Total Output', '${_toNum(summary?['totalRevenue']).toStringAsFixed(0)} MKD', Icons.payments_rounded, AppTheme.accent)),
            ],
          ),
          const SizedBox(height: 32),
          const Text('Zone Performance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 16),
          if (zones.isEmpty) _emptyState('No zone data available')
          else ...zones.map((zone) => _buildBasicListTile(
            zone['zone']?.toString() ?? 'Unknown',
            '${_toNum(zone['sessions']).toStringAsFixed(0)} sessions • ${_toNum(zone['orders']).toStringAsFixed(0)} orders',
            '${_toNum(zone['revenue']).toStringAsFixed(0)} MKD'
          )),
          const SizedBox(height: 32),
          const Text('Top Performing Tables', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 16),
          ...tables.take(15).map((table) => _buildBasicListTile(
            table['table']?['name']?.toString() ?? 'Unknown',
            'Zone: ${table['table']?['zone'] ?? 'Unknown'} • ${_toNum(table['avgSessionDuration']).toStringAsFixed(0)} min avg turnover',
            '${_toNum(table['totalRevenue']).toStringAsFixed(0)} MKD'
          )),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // HELPER COMPONENTS
  // ══════════════════════════════════════════════════════════════════════════════

  double _calculateTotalRevenue(List waiters) => waiters.fold(0.0, (s, w) => s + _toNum(w['totalRevenue']));

  Widget _emptyState(String msg) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Center(child: Text(msg, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14))),
  );

  Widget _premiumStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 30, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.5))),
        ],
      ),
    ).animate().fade(duration: 500.ms).slideY(begin: 0.1, curve: Curves.easeOutCubic);
  }

  Widget _buildBasicListTile(String title, String subtitle, String trailing) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
            ],
          ),
          Text(trailing, style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ),
    ).animate().fade(duration: 400.ms).slideX(begin: 0.05);
  }

  Widget _buildWaiterRankingCard(Map<String, dynamic> w, int rank) {
    Color rankColor = AppTheme.textSecondary;
    if (rank == 1) rankColor = AppTheme.warning;
    else if (rank == 2) rankColor = AppTheme.textPrimary;
    else if (rank == 3) rankColor = AppTheme.accent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: rank <= 3 ? rankColor.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: rankColor.withValues(alpha: 0.15), shape: BoxShape.circle, border: Border.all(color: rankColor.withValues(alpha: 0.3))),
            child: Center(child: Text('#$rank', style: TextStyle(color: rankColor, fontWeight: FontWeight.w900, fontSize: 16))),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(w['waiter']?['name'] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text('${w['totalShifts']} shifts • ${w['totalPayments']} payments', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${_toNum(w['totalRevenue']).toStringAsFixed(0)} MKD', style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text('${_toNum(w['avgRevenuePerShift']).toStringAsFixed(0)} avg/shift', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.print_rounded, color: AppTheme.primaryLight),
            onPressed: () => _print80mmWaiterReport(w),
            tooltip: 'Print 80mm Receipt',
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item, int rank) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(width: 24, child: Text('$rank.', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontWeight: FontWeight.bold))),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['item']?['name'] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text(item['item']?['category'] ?? '', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${_toNum(item['revenue']).toStringAsFixed(0)} MKD', style: const TextStyle(color: AppTheme.primaryLight, fontWeight: FontWeight.bold)),
              Text('${item['quantitySold']} sold', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
            ],
          ),
        ],
      ),
    ).animate().fade(duration: 400.ms).slideX(begin: 0.05);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
