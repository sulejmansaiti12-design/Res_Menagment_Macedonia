import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/api_client.dart';

class OpsTableMapScreen extends StatefulWidget {
  final ApiClient apiClient;
  const OpsTableMapScreen({super.key, required this.apiClient});

  @override
  State<OpsTableMapScreen> createState() => _OpsTableMapScreenState();
}

class _OpsTableMapScreenState extends State<OpsTableMapScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _zones = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await widget.apiClient.get('/admin/operations/table-map');
      _zones = List<Map<String, dynamic>>.from((res['data']['zones'] as List).map((z) => Map<String, dynamic>.from(z as Map)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _statusColor(String s, int pendingRequests) {
    if (pendingRequests > 0) return AppTheme.warning;
    switch (s) {
      case 'occupied':
        return AppTheme.accent;
      case 'needsAttention':
        return AppTheme.error;
      default:
        return AppTheme.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Operations: Table Map')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: _zones.map((z) {
                  final tables = (z['tables'] as List?)?.map((t) => Map<String, dynamic>.from(t as Map)).toList() ?? [];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ExpansionTile(
                      leading: const Icon(Icons.place, color: AppTheme.accent),
                      title: Text(z['name'] as String? ?? 'Zone', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${tables.length} tables', style: const TextStyle(color: AppTheme.textSecondary)),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: tables.map((t) {
                              final status = (t['status'] ?? 'free').toString();
                              final pending = (t['pendingRequestsCount'] ?? 0) as int;
                              final openOrders = (t['openOrdersCount'] ?? 0) as int;
                              final total = (t['openOrdersTotal'] ?? 0).toString();
                              final color = _statusColor(status, pending);
                              return Container(
                                width: 160,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceLight,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: color.withValues(alpha: 0.35)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            (t['name'] ?? '').toString(),
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text('Orders: $openOrders', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                    Text('Total: $total', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                    if (pending > 0) ...[
                                      const SizedBox(height: 4),
                                      Text('Requests: $pending', style: const TextStyle(color: AppTheme.warning, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
    );
  }
}

