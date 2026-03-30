import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';

class WaiterTablesTab extends StatefulWidget {
  final ApiClient apiClient;
  final Map<String, dynamic> activeShift;
  final int refreshCounter;
  final List<dynamic> notifications;

  const WaiterTablesTab({
    super.key,
    required this.apiClient,
    required this.activeShift,
    this.refreshCounter = 0,
    this.notifications = const [],
  });

  @override
  State<WaiterTablesTab> createState() => _WaiterTablesTabState();
}

class _WaiterTablesTabState extends State<WaiterTablesTab> {
  List<Map<String, dynamic>> _tables = [];
  bool _isLoading = true;

  @override
  void didUpdateWidget(WaiterTablesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshCounter != oldWidget.refreshCounter) {
      _loadTables();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  Future<void> _loadTables() async {
    setState(() => _isLoading = true);
    try {
      final zoneId = widget.activeShift['zoneId'] as String;
      final res = await widget.apiClient.get('/tables?zoneId=$zoneId');
      setState(() {
        _tables = List<Map<String, dynamic>>.from(
          (res['data']['tables'] as List).map((t) => Map<String, dynamic>.from(t as Map)),
        );
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        int columns;
        if (constraints.maxWidth < 450) {
          columns = 2;
        } else if (constraints.maxWidth < 800) {
          columns = 3;
        } else if (constraints.maxWidth < 1200) {
          columns = 4;
        } else {
          columns = 5;
        }
        final double aspectRatio = 1.0;

        return RefreshIndicator(
          onRefresh: _loadTables,
          color: AppTheme.primaryLight,
          backgroundColor: AppTheme.surface,
          child: CustomScrollView(
            slivers: [
              if (widget.notifications.isNotEmpty)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('RECENT ALERTS / REQUESTS', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.error)),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 70,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: widget.notifications.length,
                            itemBuilder: (ctx, i) {
                              final n = widget.notifications[i];
                              return Container(
                                width: 280,
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppTheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.1)),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.error.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.notifications_active_rounded, color: AppTheme.error, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        n['message'] ?? 'Action required',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 120),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    childAspectRatio: aspectRatio,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _buildTableCard(_tables[i], i),
                    childCount: _tables.length,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTableCard(Map<String, dynamic> table, int delayIndex) {
    final status = table['status'] as String? ?? 'free';

    Color statusColor;
    IconData statusIcon;
    List<Color> gradientColors;
    
    switch (status) {
      case 'free':
        statusColor = AppTheme.success;
        statusIcon = Icons.check_circle_rounded;
        gradientColors = [AppTheme.surfaceLight, AppTheme.surface];
        break;
      case 'occupied':
        statusColor = AppTheme.warning;
        statusIcon = Icons.people_rounded;
        gradientColors = [AppTheme.warning.withValues(alpha: 0.15), AppTheme.surface];
        break;
      case 'needsAttention':
        statusColor = AppTheme.error;
        statusIcon = Icons.priority_high_rounded;
        gradientColors = [AppTheme.error.withValues(alpha: 0.2), AppTheme.error.withValues(alpha: 0.05)];
        break;
      default:
        statusColor = AppTheme.textSecondary;
        statusIcon = Icons.table_restaurant_rounded;
        gradientColors = [AppTheme.surfaceLight, AppTheme.surface];
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 15, offset: const Offset(0, 8)),
        ],
        border: Border.all(
          color: status == 'needsAttention' ? AppTheme.error.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.06),
          width: status == 'needsAttention' ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _handleTableTap(table),
          splashColor: statusColor.withValues(alpha: 0.2),
          highlightColor: statusColor.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(statusIcon, color: statusColor, size: 20),
                    ),
                    if (status == 'needsAttention')
                      Container(
                        width: 12, height: 12,
                        decoration: const BoxDecoration(
                          color: AppTheme.error, 
                          shape: BoxShape.circle, 
                          boxShadow: [BoxShadow(color: AppTheme.error, blurRadius: 8)],
                        ),
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (table['name'] as String).toUpperCase(),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: 1.0),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: status == 'needsAttention' ? AppTheme.error : statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        status == 'needsAttention' ? 'ACTION' : status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9, 
                          fontWeight: FontWeight.w800, 
                          color: status == 'needsAttention' ? Colors.white : statusColor,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fade(delay: (30 * delayIndex).ms, duration: 400.ms).scaleXY(begin: 0.95);
  }

  Future<void> _handleTableTap(Map<String, dynamic> table) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
    );
    try {
      final res = await widget.apiClient.get('/tables/${table['id']}/alerts');
      if (!mounted) return;
      Navigator.pop(context); // hide loading

      final pendingOrders = res['data']?['pendingOrders'] as List? ?? [];
      final notifications = res['data']?['notifications'] as List? ?? [];

      if (pendingOrders.isNotEmpty || notifications.isNotEmpty) {
        _showAttentionDialog(table, pendingOrders, notifications);
      } else {
        _showTableOptions(table);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // hide loading
      _showTableOptions(table); // Fallback
    }
  }

  void _showAttentionDialog(Map<String, dynamic> table, List pendingOrders, List notifications) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
        title: Row(
          children: [
            const Icon(Icons.warning_rounded, color: AppTheme.error),
            const SizedBox(width: 12),
            Text('${table['name']} Needs Attention', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              if (notifications.isNotEmpty) ...[
                const Text('ALERTS', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.5)),
                const SizedBox(height: 12),
                ...notifications.map((n) {
                  final msg = n['message'] as String? ?? 'Notification';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.error.withValues(alpha: 0.2))),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.2), shape: BoxShape.circle),
                        child: const Icon(Icons.notifications_active_rounded, color: AppTheme.error, size: 20),
                      ),
                      title: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      trailing: IconButton(
                        icon: const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 28),
                        onPressed: () async {
                          try {
                            if (n['id'] != null) {
                              await widget.apiClient.put('/notifications/${n['id']}/read');
                            }
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            await _loadTables();
                            final updatedTable = _tables.firstWhere((t) => t['id'] == table['id'], orElse: () => table);
                            _handleTableTap(updatedTable);
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                            }
                          }
                        },
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 20),
              ],
              if (pendingOrders.isNotEmpty) ...[
                const Text('PENDING ORDERS', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.5)),
                const SizedBox(height: 12),
                ...pendingOrders.map((o) {
                  final items = o['items'] as List? ?? [];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text('Order #${o['id'].toString().substring(0, 4)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('${items.length} items • ${o['totalAmount']} MKD', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.1), shape: BoxShape.circle),
                            child: IconButton(
                              icon: const Icon(Icons.close_rounded, color: AppTheme.error),
                              onPressed: () => _updateOrderStatus(ctx, o['id'], 'cancelled', table),
                              tooltip: 'Decline',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.1), shape: BoxShape.circle),
                            child: IconButton(
                              icon: const Icon(Icons.check_rounded, color: AppTheme.success),
                              onPressed: () => _updateOrderStatus(ctx, o['id'], 'confirmed', table),
                              tooltip: 'Accept',
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.all(24),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx), 
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openOrderScreen(table);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryLight,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('New Order', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.1)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _updateOrderStatus(BuildContext ctx, String orderId, String status, Map<String, dynamic> table) async {
    try {
      if (status == 'confirmed') {
        await widget.apiClient.post('/orders/$orderId/confirm');
      } else {
        await widget.apiClient.post('/orders/$orderId/decline', body: {'reason': 'Declined by waiter'});
      }
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Order $status', style: const TextStyle(fontWeight: FontWeight.w700)), 
        backgroundColor: status == 'confirmed' ? AppTheme.success : AppTheme.warning,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      Navigator.pop(ctx);
      _handleTableTap(table);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error, behavior: SnackBarBehavior.floating));
    }
  }

  void _showTableOptions(Map<String, dynamic> table) {
    final status = table['status'] as String? ?? 'free';
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.9),
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppTheme.textSecondary.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(table['name'] as String, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: (status == 'free' ? AppTheme.success : status == 'occupied' ? AppTheme.warning : AppTheme.error).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: (status == 'free' ? AppTheme.success : status == 'occupied' ? AppTheme.warning : AppTheme.error).withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: status == 'free' ? AppTheme.success : status == 'occupied' ? AppTheme.warning : AppTheme.error,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                // Main Create Order Button
                Container(
                  width: double.infinity,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.accent]),
                    boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 8))],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openOrderScreen(table);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.restaurant_menu_rounded, color: Colors.white, size: 24),
                        SizedBox(width: 12),
                        Text('OPEN MENU', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.5, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            _showQRCode(table);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.qr_code_rounded, size: 20, color: AppTheme.textPrimary),
                              SizedBox(width: 8),
                              Text('QR Code', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (status == 'occupied') ...[
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppTheme.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                          ),
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(ctx);
                              _handleCheckout(table);
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.point_of_sale_rounded, size: 20, color: AppTheme.success),
                                SizedBox(width: 8),
                                Text('PAY TABLE', style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.success, letterSpacing: 1.2)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleCheckout(Map<String, dynamic> table) async {
    final role = context.read<AuthProvider>().userRole;
    final isOffTrack = role == 'waiter_offtrack';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
        title: Row(
          children: [
            Icon(Icons.point_of_sale_rounded, color: isOffTrack ? AppTheme.error : AppTheme.success, size: 28),
            const SizedBox(width: 12),
            Text('${isOffTrack ? 'Off-Track' : 'Fiscal'} Checkout', style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        content: const Text('Process payment for all unpaid orders on this table? This action cannot be reversed.', style: TextStyle(color: AppTheme.textSecondary, height: 1.5)),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, false), 
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: const Text('Confirm Pay', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.success)),
    );

    try {
      final res = await widget.apiClient.post('/payments', body: {
        'tableId': table['id'],
        'paymentMethod': 'cash',
      });

      if (!mounted) return;
      Navigator.pop(context); // close loading

      if (res['success'] == true) {
        final data = res['data'];
        final isFiscal = data['isFiscal'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.receipt_long_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Payment successful! ${isFiscal ? 'Fiscal' : 'Off-Track'} receipt printed.', style: const TextStyle(fontWeight: FontWeight.w600))),
              ],
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.all(16),
          ),
        );
        _loadTables(); // refresh tables
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e', style: const TextStyle(fontWeight: FontWeight.w600)), backgroundColor: AppTheme.error, behavior: SnackBarBehavior.floating),
      );
    }
  }

  void _openOrderScreen(Map<String, dynamic> table) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _WaiterTableOrderScreen(
          apiClient: widget.apiClient,
          tableId: table['id'] as String,
          tableName: table['name'] as String,
          onOrderPlaced: _loadTables,
        ),
      ),
    );
  }

  Future<void> _showQRCode(Map<String, dynamic> table) async {
    try {
      final res = await widget.apiClient.get('/tables/${table['id']}/qr');
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
          title: Text(table['name'] as String, style: const TextStyle(fontWeight: FontWeight.w800), textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Customer scan token', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.primaryDark.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.primaryLight.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: SelectableText(
                    table['qrToken'] as String? ?? '',
                    style: const TextStyle(color: AppTheme.primaryLight, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Use this token on the customer screen\nto test native ordering',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx), 
              style: TextButton.styleFrom(minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error, behavior: SnackBarBehavior.floating),
      );
    }
  }
}

// ==================== WAITER TABLE ORDER SCREEN ====================

class _WaiterTableOrderScreen extends StatefulWidget {
  final ApiClient apiClient;
  final String tableId;
  final String tableName;
  final VoidCallback onOrderPlaced;

  const _WaiterTableOrderScreen({
    super.key,
    required this.apiClient,
    required this.tableId,
    required this.tableName,
    required this.onOrderPlaced,
  });

  @override
  State<_WaiterTableOrderScreen> createState() => _WaiterTableOrderScreenState();
}

class _WaiterTableOrderScreenState extends State<_WaiterTableOrderScreen> {
  List<Map<String, dynamic>> _categories = [];
  List _existingOrders = [];
  bool _isLoading = true;
  int _selectedCategoryIndex = 0;
  final Map<String, int> _cart = {};
  final Map<String, String> _itemNotes = {};
  final Map<String, Map<String, dynamic>> _itemDetails = {};
  bool _isOrdering = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final menuRes = await widget.apiClient.get('/customer/menu');
      final sessionRes = await widget.apiClient.get('/tables/${widget.tableId}/session');
      
      setState(() {
        _categories = List<Map<String, dynamic>>.from(
          (menuRes['data']['categories'] as List).map((c) => Map<String, dynamic>.from(c as Map)),
        );
        _existingOrders = sessionRes['data']['existingOrders'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get _totalCartItems => _cart.values.fold(0, (a, b) => a + b);

  double get _totalCartPrice {
    double total = 0;
    _cart.forEach((id, qty) {
      final item = _itemDetails[id];
      if (item != null) {
        total += (double.tryParse(item['price'].toString()) ?? 0) * qty;
      }
    });
    return total;
  }

  Future<void> _placeOrder() async {
    if (_cart.isEmpty) return;
    setState(() => _isOrdering = true);

    try {
      final items = _cart.entries.map((e) => {
        'menuItemId': e.key,
        'quantity': e.value,
        'notes': _itemNotes[e.key] ?? '',
      }).toList();

      await widget.apiClient.post('/orders/waiter-order', body: {
        'tableId': widget.tableId,
        'items': items,
      });

      if (mounted) {
        widget.onOrderPlaced();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Order placed for ${widget.tableName}! Sent to preparation.', style: const TextStyle(fontWeight: FontWeight.w600))),
              ],
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
    } catch (e) {
      setState(() => _isOrdering = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Widget _buildAlreadyOrdered() {
    if (_existingOrders.isEmpty) return const SizedBox();

    final Map<String, int> aggregated = {};
    for (final order in _existingOrders) {
      if (order['status'] != 'paid' && order['status'] != 'cancelled') {
        final items = order['items'] as List? ?? [];
        for (final it in items) {
          final name = it['menuItem']?['name'] as String? ?? 'Item';
          final qty = it['quantity'] as int? ?? 1;
          aggregated[name] = (aggregated[name] ?? 0) + qty;
        }
      }
    }

    if (aggregated.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryDark.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primaryLight.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: AppTheme.primaryLight.withValues(alpha: 0.2), shape: BoxShape.circle),
                child: const Icon(Icons.history_rounded, color: AppTheme.primaryLight, size: 16),
              ),
              const SizedBox(width: 12),
              const Text('ALREADY ORDERED', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.primaryLight, letterSpacing: 1.5)),
            ],
          ),
          const SizedBox(height: 16),
          ...aggregated.entries.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(e.key.toUpperCase(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(10)),
                  child: Text('x${e.value}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
            : Column(
                children: [
                  // Custom Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(color: AppTheme.surfaceLight, shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('NEW ORDER', style: TextStyle(color: AppTheme.primaryLight, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                            Text(widget.tableName.toUpperCase(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, letterSpacing: 1.2)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(top: 16, bottom: 120), // Bottom padding for floating dock
                      children: [
                        _buildAlreadyOrdered(),
                        
                        // Horizontal Categories
                        SizedBox(
                          height: 56,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _categories.length,
                            itemBuilder: (ctx, i) {
                              final isSelected = i == _selectedCategoryIndex;
                              return Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: GestureDetector(
                                  onTap: () => setState(() => _selectedCategoryIndex = i),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 24),
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.white : AppTheme.surfaceLight,
                                      borderRadius: BorderRadius.circular(28),
                                      border: Border.all(color: isSelected ? Colors.transparent : Colors.white.withValues(alpha: 0.05)),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      (_categories[i]['name'] as String? ?? '').toUpperCase(),
                                      style: TextStyle(
                                        color: isSelected ? Colors.black : AppTheme.textSecondary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        _categories.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(40),
                                child: Center(child: Text('Menu unavailable', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16, fontWeight: FontWeight.w600))),
                              )
                            : _buildMenuList(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
      extendBody: true,
      bottomNavigationBar: _cart.isNotEmpty ? Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 10))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$_totalCartItems ITEMS', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                      const SizedBox(height: 4),
                      Text('${_totalCartPrice.toStringAsFixed(0)} MKD', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: _isOrdering ? null : _placeOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isOrdering
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('SEND', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                              SizedBox(width: 8),
                              Icon(Icons.send_rounded, size: 20),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ) : null,
    );
  }

  Widget _buildMenuList() {
    if (_selectedCategoryIndex >= _categories.length) return const SizedBox();
    final items = _categories[_selectedCategoryIndex]['items'] as List? ?? [];

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = Map<String, dynamic>.from(items[i] as Map);
        final id = item['id'] as String;
        final qty = _cart[id] ?? 0;
        final note = _itemNotes[id];
        _itemDetails[id] = item;
        final hasNote = note != null && note.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: qty > 0 ? AppTheme.primaryDark.withValues(alpha: 0.1) : AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: qty > 0 ? AppTheme.primaryLight.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((item['name'] as String? ?? '').toUpperCase(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: 1.1)),
                      if (item['description'] != null && (item['description'] as String).isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(item['description'] as String, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4)),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                            child: Text('${item['price']} MKD', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppTheme.accent)),
                          ),
                          const SizedBox(width: 12),
                          if (qty > 0)
                            GestureDetector(
                              onTap: () => _showNoteDialog(id, item['name'] as String? ?? ''),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: hasNote ? AppTheme.info.withValues(alpha: 0.2) : AppTheme.surfaceLight, borderRadius: BorderRadius.circular(8)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(hasNote ? Icons.edit_note_rounded : Icons.note_add_rounded, size: 14, color: hasNote ? AppTheme.info : AppTheme.textSecondary),
                                    const SizedBox(width: 4),
                                    Text(hasNote ? 'NOTE ADDED' : 'ADD NOTE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: hasNote ? AppTheme.info : AppTheme.textSecondary)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (hasNote && qty > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('"$note"', style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: AppTheme.info.withValues(alpha: 0.8))),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                qty == 0
                    ? Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.accent], begin: Alignment.topLeft, end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => setState(() => _cart[id] = 1),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              child: Icon(Icons.add_rounded, color: Colors.white, size: 24),
                            ),
                          ),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => setState(() { if (qty <= 1) { _cart.remove(id); _itemNotes.remove(id); } else { _cart[id] = qty - 1; } }),
                              icon: Icon(qty == 1 ? Icons.delete_outline_rounded : Icons.remove_rounded, size: 20, color: qty == 1 ? AppTheme.error : Colors.white),
                              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                            ),
                            Container(
                              width: 32,
                              alignment: Alignment.center,
                              child: Text('$qty', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white)),
                            ),
                            IconButton(
                              onPressed: () => setState(() => _cart[id] = qty + 1),
                              icon: const Icon(Icons.add_rounded, size: 20, color: Colors.white),
                              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                            ),
                          ],
                        ),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showNoteDialog(String itemId, String itemName) {
    final c = TextEditingController(text: _itemNotes[itemId] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
        title: Text('Note for $itemName', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        content: TextField(
          controller: c, 
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'e.g., no cheese, extra spicy...', 
            hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.5)),
            filled: true,
            fillColor: AppTheme.surfaceLight,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.all(16),
          ), 
          maxLines: 3, 
          autofocus: true,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () { setState(() => _itemNotes.remove(itemId)); Navigator.pop(ctx); }, 
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: const Text('Clear', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () { 
                    final t = c.text.trim(); 
                    setState(() { if (t.isNotEmpty) { _itemNotes[itemId] = t; } else { _itemNotes.remove(itemId); } }); 
                    Navigator.pop(ctx); 
                  }, 
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryLight,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Save Note', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
