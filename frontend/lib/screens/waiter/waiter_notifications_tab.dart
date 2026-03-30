import 'dart:ui';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/api_client.dart';

class WaiterNotificationsTab extends StatelessWidget {
  final List<Map<String, dynamic>> notifications;
  final ApiClient apiClient;
  final Map<String, dynamic> activeShift;
  final VoidCallback onClearNotifications;
  final VoidCallback? onRefresh;

  const WaiterNotificationsTab({
    super.key,
    required this.notifications,
    required this.apiClient,
    required this.activeShift,
    required this.onClearNotifications,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: AppTheme.surfaceLight, shape: BoxShape.circle),
              child: Icon(Icons.notifications_active_rounded, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
            ),
            const SizedBox(height: 24),
            const Text('All Caught Up', style: TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
            const SizedBox(height: 8),
            const Text('New orders and alerts will appear here.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                    child: Text('${notifications.length}', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w900, fontSize: 14)),
                  ),
                  const SizedBox(width: 8),
                  const Text('Pending Alerts', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                ],
              ),
              TextButton.icon(
                onPressed: onClearNotifications,
                icon: const Icon(Icons.done_all_rounded, size: 18, color: AppTheme.textSecondary),
                label: const Text('Mark Read', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                style: TextButton.styleFrom(
                  backgroundColor: AppTheme.surfaceLight,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 120), // Bottom padding for dock layout
            itemCount: notifications.length,
            itemBuilder: (ctx, i) => _buildNotificationCard(ctx, notifications[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationCard(BuildContext context, Map<String, dynamic> notification) {
    final type = notification['type'] as String? ?? '';
    final message = notification['message'] as String? ?? '';
    final tableName = notification['tableName'] as String? ?? '';

    IconData icon;
    Color color;
    switch (type) {
      case 'newOrder':
        icon = Icons.receipt_long_rounded;
        color = AppTheme.success;
        break;
      case 'callWaiter':
        icon = Icons.front_hand_rounded;
        color = AppTheme.accent;
        break;
      case 'requestBill':
        icon = Icons.point_of_sale_rounded;
        color = AppTheme.warning;
        break;
      case 'requestWater':
        icon = Icons.water_drop_rounded;
        color = AppTheme.info;
        break;
      case 'itemReady':
        icon = Icons.room_service_rounded;
        color = AppTheme.success;
        break;
      case 'zoneChange':
        icon = Icons.swap_horiz_rounded;
        color = AppTheme.primaryLight;
        break;
      default:
        icon = Icons.notifications_rounded;
        color = AppTheme.textSecondary;
    }

    final isUrgent = type == 'requestBill' || type == 'callWaiter' || type == 'requestWater';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isUrgent ? color.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.06)),
        boxShadow: [
          if (isUrgent) BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: type == 'newOrder' ? () {
            String? orderId;
            if (notification['orderId'] != null) {
              orderId = notification['orderId'].toString();
            } else if (notification['data'] != null && notification['data']['orderId'] != null) {
              orderId = notification['data']['orderId'].toString();
            }
            if (orderId != null) {
              _showOrderDetailsDialog(context, orderId, tableName);
            }
          } : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (tableName.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(6)),
                          child: Text(tableName.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppTheme.textSecondary, letterSpacing: 1.5)),
                        ),
                      Text(message, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700, height: 1.3)),
                    ],
                  ),
                ),
                if (type == 'newOrder')
                  Container(
                    margin: const EdgeInsets.only(left: 12),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.chevron_right_rounded, color: AppTheme.primary),
                  )
                else if (isUrgent)
                  Container(
                    margin: const EdgeInsets.only(left: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                    child: Text('ACTION REQUIRED', style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showOrderDetailsDialog(BuildContext context, String orderId, String tableName) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
    );

    try {
      final res = await apiClient.get('/orders/$orderId');
      if (!context.mounted) return;
      Navigator.pop(context); // hide loading
      
      final order = res['data']['order'] as Map<String, dynamic>;
      final items = (order['items'] as List?) ?? [];
      final total = order['totalAmount']?.toString() ?? '0';

      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
          titlePadding: EdgeInsets.zero,
          title: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.receipt_long_rounded, color: AppTheme.success),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('NEW ORDER', style: TextStyle(color: AppTheme.success, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    Text(tableName.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                  ],
                ),
              ],
            ),
          ),
          contentPadding: const EdgeInsets.all(24),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${items.length} ITEMS', style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textSecondary, letterSpacing: 1.5, fontSize: 13)),
                    Text('$total MKD', style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.primaryLight, fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  constraints: const BoxConstraints(maxHeight: 250),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: items.length,
                    itemBuilder: (c, i) {
                      final item = items[i];
                      final menuItem = item['menuItem'] as Map<String, dynamic>? ?? {};
                      final hasNote = item['notes'] != null && item['notes'].toString().isNotEmpty;
                      final unitPrice = double.tryParse(item['unitPrice']?.toString() ?? '0') ?? 0;
                      final qty = (item['quantity'] as num?) ?? 1;
                      final subtotal = unitPrice * qty;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(8)),
                              child: Text('${item['quantity']}x', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w900)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${menuItem['name'] ?? 'Item'}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white)),
                                  if (hasNote)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.edit_note_rounded, size: 14, color: AppTheme.info),
                                          const SizedBox(width: 4),
                                          Expanded(child: Text('"${item['notes']}"', style: const TextStyle(color: AppTheme.info, fontStyle: FontStyle.italic, fontSize: 12))),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text('${subtotal.toStringAsFixed(0)} MKD', style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textSecondary)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.all(24),
          actions: [
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _updateOrderStatus(ctx, orderId, 'cancelled'),
                        icon: const Icon(Icons.close_rounded, color: AppTheme.error),
                        label: const Text('Decline'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.error,
                          side: BorderSide(color: AppTheme.error.withValues(alpha: 0.3)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () => _updateOrderStatus(ctx, orderId, 'confirmed'),
                        icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                        label: const Text('Accept Order'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(ctx), 
                  style: TextButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                  ),
                  child: const Text('Close Later', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // hide loading
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e', style: const TextStyle(fontWeight: FontWeight.w600)), backgroundColor: AppTheme.error, behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _updateOrderStatus(BuildContext ctx, String orderId, String status) async {
    try {
      if (status == 'confirmed') {
        await apiClient.post('/orders/$orderId/confirm');
      } else {
        await apiClient.post('/orders/$orderId/decline', body: {'reason': 'Declined by waiter'});
      }
      
      if (!ctx.mounted) return;
      Navigator.pop(ctx); // close dialog
      if (onRefresh != null) onRefresh!();
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(status == 'confirmed' ? 'Order accepted and sent to preparation!' : 'Order declined.', style: const TextStyle(fontWeight: FontWeight.w700)), 
          backgroundColor: status == 'confirmed' ? AppTheme.success : AppTheme.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        )
      );
    } catch (e) {
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error, behavior: SnackBarBehavior.floating));
    }
  }
}
