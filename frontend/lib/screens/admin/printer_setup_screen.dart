import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/api_client.dart';

class PrinterSetupScreen extends StatefulWidget {
  final ApiClient apiClient;
  const PrinterSetupScreen({super.key, required this.apiClient});

  @override
  State<PrinterSetupScreen> createState() => _PrinterSetupScreenState();
}

class _PrinterSetupScreenState extends State<PrinterSetupScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _printers = [];
  List<Map<String, dynamic>> _destinations = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final p = await widget.apiClient.get('/admin/printers');
      final d = await widget.apiClient.get('/destinations');
      _printers = List<Map<String, dynamic>>.from((p['data']['printers'] as List).map((x) => Map<String, dynamic>.from(x as Map)));
      _destinations = List<Map<String, dynamic>>.from((d['data']['destinations'] as List).map((x) => Map<String, dynamic>.from(x as Map)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addOrEdit({Map<String, dynamic>? printer}) async {
    final nameC = TextEditingController(text: (printer?['name'] ?? '').toString());
    String type = (printer?['type'] ?? 'stub').toString();
    String? destinationId = printer?['destinationId'] as String?;
    String printScope = (printer?['config']?['printScope'] ?? 'both').toString();
    final ipC = TextEditingController(text: (printer?['ip'] ?? '').toString());
    final portC = TextEditingController(text: (printer?['port'] ?? '').toString());

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: Text(printer == null ? 'Add Printer' : 'Edit Printer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameC, decoration: const InputDecoration(hintText: 'Printer name')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(hintText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'stub', child: Text('Stub')),
                  DropdownMenuItem(value: 'network', child: Text('Network (IP)')),
                  DropdownMenuItem(value: 'usb', child: Text('USB')),
                ],
                onChanged: (v) => ss(() => type = v ?? 'stub'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: printScope,
                decoration: const InputDecoration(hintText: 'Receipt Type / Scope'),
                items: const [
                  DropdownMenuItem(value: 'both', child: Text('Both (Fiscal & Off-Track)')),
                  DropdownMenuItem(value: 'fiscal', child: Text('Fiscal Receipts Only')),
                  DropdownMenuItem(value: 'off_track', child: Text('Off-Track Receipts Only')),
                  DropdownMenuItem(value: 'kitchen', child: Text('Kitchen/Bar Orders Only')),
                ],
                onChanged: (v) => ss(() => printScope = v ?? 'both'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value: destinationId,
                decoration: const InputDecoration(hintText: 'Destination (optional)'),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('— None —')),
                  ..._destinations.map((d) => DropdownMenuItem<String?>(
                        value: d['id'] as String,
                        child: Text(d['name'] as String? ?? 'Destination'),
                      )),
                ],
                onChanged: (v) => ss(() => destinationId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ipC,
                decoration: const InputDecoration(hintText: 'IP (for network printers)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: portC,
                decoration: const InputDecoration(hintText: 'Port (e.g. 9100)'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  final body = {
                    'name': nameC.text.trim(),
                    'type': type,
                    'destinationId': destinationId,
                    'ip': ipC.text.trim().isEmpty ? null : ipC.text.trim(),
                    'port': int.tryParse(portC.text.trim()),
                    'config': {
                      if (printer?['config'] != null) ...(printer!['config'] as Map<String, dynamic>),
                      'printScope': printScope,
                    }
                  };
                  if (printer == null) {
                    await widget.apiClient.post('/admin/printers', body: body);
                  } else {
                    await widget.apiClient.put('/admin/printers/${printer['id']}', body: body);
                  }
                  _load();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e'), backgroundColor: AppTheme.error));
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate printer'),
        content: const Text('Deactivate this printer?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error), child: const Text('Deactivate')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.apiClient.delete('/admin/printers/$id');
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Printer Setup')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              onRefresh: _load,
              child: _printers.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 200),
                        Center(child: Text('No printers configured', style: TextStyle(color: AppTheme.textSecondary))),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _printers.length,
                      itemBuilder: (ctx, i) {
                        final p = _printers[i];
                        final dest = p['destination'] as Map?;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: AppTheme.surfaceLight,
                              child: Icon(Icons.print, color: AppTheme.accent),
                            ),
                            title: Text(p['name'] as String? ?? ''),
                            subtitle: Text(
                              '${p['type']} • ${dest?['name'] ?? 'No destination'} • Scope: ${p['config']?['printScope'] ?? 'both'}',
                              style: const TextStyle(color: AppTheme.textSecondary),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(icon: const Icon(Icons.edit, color: AppTheme.info), onPressed: () => _addOrEdit(printer: p)),
                                IconButton(icon: const Icon(Icons.delete, color: AppTheme.error), onPressed: () => _delete(p['id'] as String)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEdit(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

