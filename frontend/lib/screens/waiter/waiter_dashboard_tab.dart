import 'dart:ui';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/api_client.dart';

class WaiterDashboardTab extends StatefulWidget {
  final ApiClient apiClient;
  final Map<String, dynamic> activeShift;
  const WaiterDashboardTab({super.key, required this.apiClient, required this.activeShift});

  @override
  State<WaiterDashboardTab> createState() => _WaiterDashboardTabState();
}

class _WaiterDashboardTabState extends State<WaiterDashboardTab> {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final zoneId = widget.activeShift['zoneId'] as String;
      final res = await widget.apiClient.get('/orders/zone/$zoneId');
      setState(() {
        _orders = List<Map<String, dynamic>>.from(
          (res['data']['orders'] as List).map((o) => Map<String, dynamic>.from(o as Map)),
        );
        // Sort: pending first, then preparing, then ready, then confirmed, then others
        _orders.sort((a, b) {
          final ranks = {'pending': 0, 'confirmed': 1, 'preparing': 2, 'ready': 3, 'served': 4};
          final rankA = ranks[a['status']] ?? 5;
          final rankB = ranks[b['status']] ?? 5;
          if (rankA != rankB) return rankA.compareTo(rankB);
          final dateA = DateTime.tryParse(a['createdAt'].toString()) ?? DateTime.now();
          final dateB = DateTime.tryParse(b['createdAt'].toString()) ?? DateTime.now();
          return dateB.compareTo(dateA); // newest first within same rank
        });
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmOrder(String orderId) async {
    try {
      await widget.apiClient.post('/orders/$orderId/confirm');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [Icon(Icons.check_circle_rounded, color: Colors.white), SizedBox(width: 12), Expanded(child: Text('Order Confirmed!', style: TextStyle(fontWeight: FontWeight.w600)))]),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
      _loadOrders();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error, behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _markServed(String orderId) async {
    try {
      await widget.apiClient.post('/orders/$orderId/served');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [Icon(Icons.room_service_rounded, color: Colors.white), SizedBox(width: 12), Expanded(child: Text('Order marked as served.', style: TextStyle(fontWeight: FontWeight.w600)))]),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
      _loadOrders();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error, behavior: SnackBarBehavior.floating));
    }
  }

  void _showDeclineDialog(String orderId, Map<String, dynamic> order) {
    final reasonC = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
        title: const Row(
          children: [
            Icon(Icons.cancel_rounded, color: AppTheme.error),
            SizedBox(width: 12),
            Text('Decline Order', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This will cancel the order immediately.', style: TextStyle(color: AppTheme.textSecondary, height: 1.5)),
            const SizedBox(height: 16),
            TextField(
              controller: reasonC,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Reason (optional)',
                hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                filled: true,
                fillColor: AppTheme.surfaceLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.all(16),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.all(24),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx), 
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    try {
                      await widget.apiClient.post('/orders/$orderId/decline', body: {'reason': reasonC.text});
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: const Text('Order declined.'), backgroundColor: AppTheme.warning, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        );
                        _loadOrders();
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error, behavior: SnackBarBehavior.floating));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: const Text('Decline Order', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _loadOrders,
        color: AppTheme.primary,
        backgroundColor: AppTheme.surface,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
            : _orders.isEmpty
                ? _buildEmptyState()
                : CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                        sliver: SliverToBoxAdapter(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: AppTheme.surfaceLight, shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
                                child: const Icon(Icons.receipt_long_rounded, color: AppTheme.textSecondary),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('ACTIVE ORDERS', style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                                    Text('${_orders.length} in progress', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, letterSpacing: 1.1)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 120), // Bottom padding for dock
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _buildOrderCard(_orders[i]),
                            childCount: _orders.length,
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: AppTheme.surfaceLight, shape: BoxShape.circle),
                  child: Icon(Icons.receipt_long_rounded, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                ),
                const SizedBox(height: 24),
                const Text('No Active Orders', style: TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
                const SizedBox(height: 8),
                const Text('Pull down to refresh', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = order['status'] as String? ?? 'pending';
    final items = order['items'] as List? ?? [];
    final tableSession = order['tableSession'] as Map?;
    final table = tableSession?['table'] as Map?;
    final tableName = table?['name'] as String? ?? 'Unknown';
    final total = order['totalAmount']?.toString() ?? '0';

    Color statusColor;
    IconData statusIcon;
    List<Color> gradientColors;

    switch (status) {
      case 'pending':
        statusColor = AppTheme.warning;
        statusIcon = Icons.timer_rounded;
        gradientColors = [AppTheme.warning.withValues(alpha: 0.2), AppTheme.warning.withValues(alpha: 0.05)];
        break;
      case 'confirmed':
        statusColor = AppTheme.info;
        statusIcon = Icons.restaurant_menu_rounded;
        gradientColors = [AppTheme.info.withValues(alpha: 0.2), AppTheme.info.withValues(alpha: 0.05)];
        break;
      case 'preparing':
        statusColor = AppTheme.accent;
        statusIcon = Icons.soup_kitchen_rounded;
        gradientColors = [AppTheme.accent.withValues(alpha: 0.2), AppTheme.accent.withValues(alpha: 0.05)];
        break;
      case 'ready':
        statusColor = AppTheme.success;
        statusIcon = Icons.room_service_rounded;
        gradientColors = [AppTheme.success.withValues(alpha: 0.2), AppTheme.success.withValues(alpha: 0.05)];
        break;
      case 'served':
        statusColor = AppTheme.textSecondary;
        statusIcon = Icons.check_circle_rounded;
        gradientColors = [AppTheme.surfaceLight, AppTheme.surface];
        break;
      default:
        statusColor = AppTheme.textSecondary;
        statusIcon = Icons.help_outline_rounded;
        gradientColors = [AppTheme.surfaceLight, AppTheme.surface];
    }

    final isPending = status == 'pending';
    final isReady = status == 'ready';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isPending || isReady ? statusColor.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.06), width: isPending || isReady ? 1.5 : 1),
        boxShadow: [
          if (isPending || isReady) BoxShadow(color: statusColor.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // Header
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.2), shape: BoxShape.circle),
                        child: Icon(statusIcon, color: statusColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tableName.toUpperCase(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, letterSpacing: 1.1)),
                          const SizedBox(height: 2),
                          Text('#${order['id'].toString().substring(0, 6)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            
            // Items List
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${items.length} ITEMS', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                      Text('$total MKD', style: const TextStyle(color: AppTheme.primary, fontSize: 16, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...items.map((it) {
                    final mi = it['menuItem'] as Map? ?? {};
                    final name = mi['name'] as String? ?? 'Item';
                    final qty = it['quantity'] as int? ?? 1;
                    final hasNote = it['notes'] != null && it['notes'].toString().isNotEmpty;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${qty}x', style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.textPrimary, fontSize: 14)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 14)),
                                if (hasNote)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.subdirectory_arrow_right_rounded, size: 12, color: AppTheme.info),
                                        const SizedBox(width: 4),
                                        Expanded(child: Text('"${it['notes']}"', style: const TextStyle(color: AppTheme.info, fontSize: 12, fontStyle: FontStyle.italic))),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
            
            // Actions
            if (isPending || isReady)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  children: [
                    if (isPending) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showDeclineDialog(order['id'], order),
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text('Decline'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.error,
                            side: BorderSide(color: AppTheme.error.withValues(alpha: 0.3)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () => _confirmOrder(order['id']),
                          icon: const Icon(Icons.check_circle_rounded, size: 18),
                          label: const Text('Accept', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.1)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ] else if (isReady) ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _markServed(order['id']),
                          icon: const Icon(Icons.room_service_rounded, size: 18),
                          label: const Text('MARK SERVED', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
