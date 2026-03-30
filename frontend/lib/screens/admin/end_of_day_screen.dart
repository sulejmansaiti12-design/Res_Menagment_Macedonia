import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/api_client.dart';

class EndOfDayScreen extends StatefulWidget {
  final ApiClient apiClient;
  final bool isOwner;
  const EndOfDayScreen({super.key, required this.apiClient, required this.isOwner});

  @override
  State<EndOfDayScreen> createState() => _EndOfDayScreenState();
}

class _EndOfDayScreenState extends State<EndOfDayScreen> {
  DateTime _date = DateTime.now();
  bool _loading = true;
  Map<String, dynamic>? _summary;
  Map<String, dynamic>? _closeRecord;
  final _actualCashC = TextEditingController();
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _actualCashC.dispose();
    super.dispose();
  }

  String get _dateStr => '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (d != null) {
      setState(() => _date = d);
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await widget.apiClient.get('/admin/end-of-day/summary?date=$_dateStr');
      setState(() {
        _summary = Map<String, dynamic>.from(res['data']['summary'] as Map);
        _closeRecord = res['data']['closeRecord'] == null ? null : Map<String, dynamic>.from(res['data']['closeRecord'] as Map);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _closeDay() async {
    final actual = double.tryParse(_actualCashC.text.trim());
    if (actual == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter actual cash amount')));
      return;
    }

    setState(() => _closing = true);
    try {
      await widget.apiClient.post('/admin/end-of-day/close', body: {
        'date': _dateStr,
        'actualCash': actual,
      });
      _actualCashC.clear();
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Day closed (Z report saved)'), backgroundColor: AppTheme.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Close failed: $e'), backgroundColor: AppTheme.error));
      }
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  Future<void> _printFiscalReport(String type) async {
    try {
      final res = await widget.apiClient.post('/admin/end-of-day/print-$type');
      if (mounted) {
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${type.toUpperCase()}-Report printed successfully'), backgroundColor: AppTheme.success));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Print failed: ${res['error'] ?? 'Unknown'}'), backgroundColor: AppTheme.error));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error printing $type-Report: $e'), backgroundColor: AppTheme.error));
    }
  }

  Widget _stat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('End of Day (X/Z)'),
        actions: [IconButton(onPressed: _pickDate, icon: const Icon(Icons.calendar_today))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Business date: $_dateStr', style: const TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 12),
                  if (_summary != null) ...[
                    Row(
                      children: [
                        _stat('Total', '${_summary!['total']}', AppTheme.accent),
                        const SizedBox(width: 8),
                        _stat('Cash', '${_summary!['cashTotal']}', AppTheme.success),
                        const SizedBox(width: 8),
                        _stat('Card', '${_summary!['cardTotal']}', AppTheme.info),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _stat('Fiscal', '${_summary!['fiscalTotal']}', AppTheme.success),
                        const SizedBox(width: 8),
                        _stat('Off-track', '${_summary!['offTrackTotal']}', AppTheme.error),
                        const SizedBox(width: 8),
                        _stat('Payments', '${_summary!['paymentCount']}', AppTheme.textSecondary),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Cash reconciliation', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(
                            _closeRecord != null
                                ? 'Closed. Expected: ${_closeRecord!['expectedCash']} • Actual: ${_closeRecord!['actualCash']} • Diff: ${_closeRecord!['difference']}'
                                : 'Not closed yet. Enter actual cash in drawer to close the day.',
                            style: const TextStyle(color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 12),
                          if (_closeRecord == null) ...[
                            TextField(
                              controller: _actualCashC,
                              decoration: const InputDecoration(hintText: 'Actual cash (counted)'),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: _closing ? null : _closeDay,
                                icon: _closing
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Icon(Icons.lock),
                                label: const Text('Close Day (System Z)'),
                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 16),
                          const Text('Fiscal Hardware Actions', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.success)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _printFiscalReport('x'),
                                  icon: const Icon(Icons.receipt_long, color: AppTheme.success),
                                  label: const Text('Print Fiscal X-Report', style: TextStyle(color: AppTheme.success)),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: AppTheme.success.withValues(alpha: 0.5)),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _printFiscalReport('z'),
                                  icon: const Icon(Icons.receipt),
                                  label: const Text('Print Fiscal Z-Report'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.success,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

