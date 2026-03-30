import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/api_client.dart';

class AdvancedReportsScreen extends StatefulWidget {
  final ApiClient apiClient;
  const AdvancedReportsScreen({super.key, required this.apiClient});

  @override
  State<AdvancedReportsScreen> createState() => _AdvancedReportsScreenState();
}

class _AdvancedReportsScreenState extends State<AdvancedReportsScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  bool _isExporting = false;
  List<Map<String, dynamic>> _waiters = [];
  String? _selectedWaiterId;

  @override
  void initState() {
    super.initState();
    _loadWaiters();
  }

  Future<void> _loadWaiters() async {
    try {
      final res = await widget.apiClient.get('/admin/waiters');
      if (mounted) {
        setState(() {
          _waiters = List<Map<String, dynamic>>.from(res['data']?['waiters'] ?? []);
        });
      }
    } catch (e) {
      debugPrint('Error loading waiters: $e');
    }
  }

  final List<Map<String, dynamic>> _reportTypes = [
    {
      'id': 'payments',
      'name': 'Payments Report',
      'description': 'Export all payment transactions (waiter, table, amount, method)',
      'icon': Icons.payments_rounded,
      'color': AppTheme.accent,
    },
    {
      'id': 'shifts',
      'name': 'Shifts Report',
      'description': 'Export complete shift history with revenue breakdowns',
      'icon': Icons.history_toggle_off_rounded,
      'color': AppTheme.info,
    },
    {
      'id': 'orders',
      'name': 'Orders Report',
      'description': 'Export all orders with item counts and amounts',
      'icon': Icons.receipt_long_rounded,
      'color': AppTheme.success,
    },
  ];

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
    }
  }

  Future<void> _exportReport(String type) async {
    setState(() => _isExporting = true);
    try {
      final startStr = _formatDateForApi(_startDate);
      final endStr = _formatDateForApi(_endDate);
      
      String url = '/admin/reports/export?type=$type&startDate=$startStr&endDate=$endStr';
      if (_selectedWaiterId != null) {
        url += '&waiterId=$_selectedWaiterId';
      }
      
      await widget.apiClient.downloadFile(
        url,
        '${type}_report_${startStr}_to_${endStr}.csv',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$type report downloaded successfully'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting report: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  String _formatDateForApi(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  String _formatDateDisplay(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          // ── Premium Header ──────────────────────────────────────────
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
                    const Text('Advanced Reports', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, letterSpacing: -0.5)),
                    const SizedBox(height: 4),
                    Text('Export raw historical data (CSV) for accounting', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  ],
                ),
                Row(
                  children: [
                    if (_waiters.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: _selectedWaiterId,
                            dropdownColor: AppTheme.surfaceDark,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54, size: 18),
                            style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                            hint: const Text('All Waiters', style: TextStyle(color: AppTheme.textSecondary)),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('All Waiters')),
                              ..._waiters.map((w) => DropdownMenuItem(value: w['id'] as String, child: Text(w['name'] as String))),
                            ],
                            onChanged: (v) => setState(() => _selectedWaiterId = v),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    InkWell(
                      onTap: _pickDateRange,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month_rounded, color: AppTheme.primaryLight, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              '${_formatDateDisplay(_startDate)} - ${_formatDateDisplay(_endDate)}',
                              style: const TextStyle(color: AppTheme.primaryLight, fontWeight: FontWeight.w700, fontSize: 13),
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
          
          // ── Content ───────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // Quick Presets
                const Text('Quick Select Period', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _presetChip('Today', AppTheme.primary, () => _setPreset(0, 0)),
                    _presetChip('Yesterday', Colors.grey.shade400, () => _setPreset(1, 1)),
                    _presetChip('Last 7 Days', Colors.teal, () => _setPreset(7, 0)),
                    _presetChip('Last 30 Days', Colors.purple, () => _setPreset(30, 0)),
                    _presetChip('This Month', Colors.indigo, () => _setPreset(DateTime.now().day - 1, 0)),
                  ],
                ),
                const SizedBox(height: 40),

                // Report Types
                const Text('Available Reports (CSV Export)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                const SizedBox(height: 16),
                if (_isExporting)
                  Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: const Column(
                      children: [
                        CircularProgressIndicator(color: AppTheme.primary),
                        SizedBox(height: 16),
                        Text('Generating CSV report from server...', style: TextStyle(color: AppTheme.textSecondary)),
                      ],
                    ),
                  )
                else
                  ..._reportTypes.map((report) => _buildReportCard(report)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final color = report['color'] as Color;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _exportReport(report['id']),
          borderRadius: BorderRadius.circular(16),
          hoverColor: Colors.white.withValues(alpha: 0.02),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(report['icon'] as IconData, color: color, size: 24),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(report['name'] as String, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                      const SizedBox(height: 6),
                      Text(report['description'] as String, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.download_rounded, color: AppTheme.primary, size: 16),
                      const SizedBox(width: 8),
                      const Text('Export CSV', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _presetChip(String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }

  void _setPreset(int daysBackStart, int daysBackEnd) {
    setState(() {
      _endDate = DateTime.now().subtract(Duration(days: daysBackEnd));
      _startDate = DateTime.now().subtract(Duration(days: daysBackStart));
    });
  }
}
