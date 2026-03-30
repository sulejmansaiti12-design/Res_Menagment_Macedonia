import 'dart:async';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/api_client.dart';

class DeveloperLogsScreen extends StatefulWidget {
  final ApiClient apiClient;
  const DeveloperLogsScreen({super.key, required this.apiClient});

  @override
  State<DeveloperLogsScreen> createState() => _DeveloperLogsScreenState();
}

class _DeveloperLogsScreenState extends State<DeveloperLogsScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;
  Timer? _timer;
  bool _autoRefresh = true;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_autoRefresh) _load(silent: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final res = await widget.apiClient.get('/developer/logs?limit=200');
      final list = List<Map<String, dynamic>>.from(
        (res['data']['logs'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );
      if (mounted) {
        setState(() {
          _logs = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load logs: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Color _colorForLevel(String level) {
    switch (level) {
      case 'error':
        return AppTheme.error;
      case 'warn':
        return AppTheme.warning;
      case 'info':
        return AppTheme.info;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Real-time Logs'),
        actions: [
          Row(
            children: [
              const Text('Auto', style: TextStyle(fontSize: 12)),
              Switch(
                value: _autoRefresh,
                onChanged: (v) => setState(() => _autoRefresh = v),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              onRefresh: () => _load(),
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _logs.length,
                itemBuilder: (ctx, i) {
                  final entry = _logs[i];
                  final ts = (entry['ts'] ?? '').toString();
                  final level = (entry['level'] ?? 'log').toString();
                  final msg = (entry['message'] ?? '').toString();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _colorForLevel(level).withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _colorForLevel(level).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                level.toUpperCase(),
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _colorForLevel(level)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                ts,
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SelectableText(msg, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}

