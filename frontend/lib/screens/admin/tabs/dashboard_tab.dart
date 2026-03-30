import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../services/api_client.dart';
import '../../../providers/auth_provider.dart';

class DashboardTab extends StatefulWidget {
  final ApiClient apiClient;
  final AuthProvider auth;
  const DashboardTab({super.key, required this.apiClient, required this.auth});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  bool _isLoading = true;
  Map<String, dynamic> _totals = {'total': 0, 'fiscal': 0, 'offTrack': 0};
  List<dynamic> _waiters = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardSummary();
  }

  Future<void> _loadDashboardSummary() async {
    try {
      final res = await widget.apiClient.get('/admin/dashboard/summary');
      if (mounted) {
        setState(() {
          _totals = res['data']['totals'] ?? _totals;
          _waiters = res['data']['waiters'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load dashboard: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  double _t(dynamic val) => (val as num?)?.toDouble() ?? 0.0;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── TOP BAR / WELCOME ──
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.primaryLight]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    widget.auth.userName.isNotEmpty ? widget.auth.userName[0].toUpperCase() : 'A',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome ${widget.auth.userName}',
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    widget.auth.userRole == 'owner' ? 'Owner Dashboard' : 'Admin Dashboard',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 48),

          // ── TODAY'S REVENUE ──
          const Text(
            'Today\'s Revenue',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildRevenueText('${_t(_totals['total']).toStringAsFixed(0)} mkd total', Colors.white),
              _buildRevenueText('${_t(_totals['fiscal']).toStringAsFixed(0)} mkd fiskal', AppTheme.primaryLight),
              _buildRevenueText('${_t(_totals['offTrack']).toStringAsFixed(0)} mkd offtrack', AppTheme.error),
            ],
          ),
          const SizedBox(height: 48),

          // ── BY WAITER ──
          const Text(
            'By Waiter',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),

          if (_waiters.isEmpty)
            Text('No active transactions today.', style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),

          ..._waiters.map((w) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_t(w['offTrack']) > 0)
                    Text(
                      '${w['name']} - ${_t(w['offTrack']).toStringAsFixed(0)}mkd off track',
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  if (_t(w['fiscal']) > 0)
                    Text(
                      '${w['name']} - ${_t(w['fiscal']).toStringAsFixed(0)}mkd fiskal',
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRevenueText(String text, Color baseColor) {
    return Expanded(
      child: Text(
        text,
        style: TextStyle(color: baseColor, fontSize: 15, fontWeight: FontWeight.w500),
        textAlign: TextAlign.left,
      ),
    );
  }
}
