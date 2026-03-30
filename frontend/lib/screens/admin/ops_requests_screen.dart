import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/api_client.dart';

class OpsRequestsScreen extends StatefulWidget {
  final ApiClient apiClient;
  const OpsRequestsScreen({super.key, required this.apiClient});

  @override
  State<OpsRequestsScreen> createState() => _OpsRequestsScreenState();
}

class _OpsRequestsScreenState extends State<OpsRequestsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await widget.apiClient.get('/admin/operations/requests?unreadOnly=true&limit=200');
      _requests = List<Map<String, dynamic>>.from(
        (res['data']['notifications'] as List).map((n) => Map<String, dynamic>.from(n as Map)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(String id) async {
    try {
      await widget.apiClient.put('/notifications/$id/read');
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.error));
      }
    }
  }

  Color _colorForType(String t) {
    switch (t) {
      case 'requestBill':
        return AppTheme.accent;
      case 'requestWater':
        return AppTheme.info;
      case 'callWaiter':
        return AppTheme.warning;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _labelForType(String t) {
    switch (t) {
      case 'requestBill':
        return 'Bill requested';
      case 'requestWater':
        return 'Water requested';
      case 'callWaiter':
        return 'Waiter called';
      default:
        return t;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Operations: Requests Inbox')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              onRefresh: _load,
              child: _requests.isEmpty
                  ? ListView(children: const [SizedBox(height: 200), Center(child: Text('No pending requests', style: TextStyle(color: AppTheme.textSecondary)))])
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _requests.length,
                      itemBuilder: (ctx, i) {
                        final n = _requests[i];
                        final type = (n['type'] ?? '').toString();
                        final title = (n['title'] ?? '').toString();
                        final createdAt = (n['createdAt'] ?? '').toString();
                        final data = n['data'] as Map? ?? {};
                        final tableName = (data['tableName'] ?? '').toString();
                        final color = _colorForType(type);
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: color.withValues(alpha: 0.15),
                              child: Icon(Icons.notifications_active, color: color),
                            ),
                            title: Text(tableName.isNotEmpty ? '$tableName — ${_labelForType(type)}' : title),
                            subtitle: Text(createdAt, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                            trailing: ElevatedButton(
                              onPressed: () => _markRead(n['id'] as String),
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
                              child: const Text('Done'),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

