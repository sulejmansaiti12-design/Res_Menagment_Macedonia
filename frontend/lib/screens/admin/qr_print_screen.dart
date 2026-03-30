import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../config/app_theme.dart';
import '../../services/api_client.dart';

class QrPrintScreen extends StatefulWidget {
  final ApiClient apiClient;
  const QrPrintScreen({super.key, required this.apiClient});

  @override
  State<QrPrintScreen> createState() => _QrPrintScreenState();
}

class _QrPrintScreenState extends State<QrPrintScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _zones = [];
  String? _zoneId;
  List<Map<String, dynamic>> _tables = [];

  @override
  void initState() {
    super.initState();
    _loadZones();
  }

  Future<void> _loadZones() async {
    setState(() => _loading = true);
    try {
      final res = await widget.apiClient.get('/zones');
      _zones = List<Map<String, dynamic>>.from(
        (res['data']['zones'] as List).map((z) => Map<String, dynamic>.from(z as Map)),
      );
      if (_zones.isNotEmpty) {
        _zoneId ??= _zones.first['id'] as String?;
        await _loadTables();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadTables() async {
    if (_zoneId == null) return;
    final res = await widget.apiClient.get('/admin/zone-tables/$_zoneId');
    _tables = List<Map<String, dynamic>>.from(
      (res['data']['tables'] as List).map((t) => Map<String, dynamic>.from(t as Map)),
    );
    if (mounted) setState(() {});
  }

  Future<void> _printPDFCodes() async {
    final pdf = pw.Document();
    final zName = _zones.firstWhere((z) => z['id'] == _zoneId, orElse: () => {'name': 'Zone'})['name'] as String? ?? 'Zone';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(level: 0, child: pw.Text('QR Codes — $zName', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 16),
            pw.Wrap(
              spacing: 20,
              runSpacing: 20,
              children: _tables.map((table) {
                return pw.Container(
                  width: 200,
                  height: 250,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 1),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                  ),
                  padding: const pw.EdgeInsets.all(16),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(table['name'] as String? ?? 'Table', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 12),
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: table['qrToken'] as String? ?? table['id'] as String? ?? '',
                        width: 150,
                        height: 150,
                      ),
                      pw.SizedBox(height: 12),
                      pw.Text('Scan to Order', style: const pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Print Table QR Codes')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Select zone and print (Ctrl+P).', style: TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _zoneId,
                  decoration: const InputDecoration(hintText: 'Zone'),
                  items: _zones
                      .map((z) => DropdownMenuItem(value: z['id'] as String, child: Text(z['name'] as String? ?? 'Zone')))
                      .toList(),
                  onChanged: (v) async {
                    setState(() => _zoneId = v);
                    await _loadTables();
                  },
                ),
                const SizedBox(height: 16),
                if (_tables.isNotEmpty) ...[
                  ElevatedButton.icon(
                    onPressed: _printPDFCodes,
                    icon: const Icon(Icons.print),
                    label: const Text('Print Native PDF'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_tables.isEmpty)
                  const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No tables', style: TextStyle(color: AppTheme.textSecondary))))
                else
                  ..._tables.map((t) => _QrCard(tableName: t['name']?.toString() ?? '', token: t['qrToken']?.toString() ?? '')),
              ],
            ),
    );
  }
}

class _QrCard extends StatelessWidget {
  final String tableName;
  final String token;
  const _QrCard({required this.tableName, required this.token});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: QrImageView(
              data: token,
              size: 120,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tableName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('Customer enters/scans this code in the app.', style: TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                SelectableText(token, style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

