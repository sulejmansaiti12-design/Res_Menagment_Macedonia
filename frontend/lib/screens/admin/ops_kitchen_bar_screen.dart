import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../config/app_theme.dart';
import '../../services/api_client.dart';
import '../../providers/auth_provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

class OpsKitchenBarScreen extends StatefulWidget {
  final ApiClient apiClient;
  const OpsKitchenBarScreen({super.key, required this.apiClient});

  @override
  State<OpsKitchenBarScreen> createState() => _OpsKitchenBarScreenState();
}

class _OpsKitchenBarScreenState extends State<OpsKitchenBarScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _destinations = [];
  String? _destinationId;
  List<Map<String, dynamic>> _items = [];
  
  http.Client? _sseClient;

  @override
  void initState() {
    super.initState();
    _loadDestinations();
  }

  @override
  void dispose() {
    _sseClient?.close();
    super.dispose();
  }

  Future<void> _loadDestinations() async {
    setState(() => _loading = true);
    try {
      final res = await widget.apiClient.get('/admin/operations/destinations');
      _destinations = List<Map<String, dynamic>>.from(
        (res['data']['destinations'] as List).map((d) => Map<String, dynamic>.from(d as Map)),
      );
      if (_destinations.isNotEmpty) {
        _destinationId = _destinations.first['id'] as String?;
        await _loadQueue();
        _startSSE();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadQueue() async {
    if (_destinationId == null) return;
    try {
      final res = await widget.apiClient.get('/orders/queue/$_destinationId');
      if (mounted) {
        setState(() {
          _items = List<Map<String, dynamic>>.from(
            (res['data']['items'] as List).map((i) => Map<String, dynamic>.from(i as Map)),
          );
        });
      }
    } catch (_) {}
  }

  void _startSSE() async {
    _sseClient?.close();
    if (_destinationId == null || !mounted) return;
    
    final auth = context.read<AuthProvider>();
    final tk = auth.token;
    if (tk == null) return;

    _sseClient = http.Client();
    final baseUrl = AppConfig.baseUrl; 
    
    try {
      final req = http.Request('GET', Uri.parse('$baseUrl/notifications/sse/destination/$_destinationId'));
      req.headers['Authorization'] = 'Bearer $tk';
      req.headers['Accept'] = 'text/event-stream';
      req.headers['ngrok-skip-browser-warning'] = '69420';
      
      final res = await _sseClient!.send(req);
      
      res.stream.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        if (!mounted) return;
        if (line.startsWith('data: ')) {
          final dataString = line.substring(6);
          try {
            final Map<String, dynamic> data = jsonDecode(dataString);
            if (data['type'] == 'newOrderItems' || data['type'] == 'itemStatusChanged') {
              // Refresh queue completely to ensure total sync rather than manually patching array
              _loadQueue();
            }
          } catch (_) {}
        }
      }, onError: (e) {
        if (mounted) Future.delayed(const Duration(seconds: 5), _startSSE);
      }, onDone: () {
        if (mounted) Future.delayed(const Duration(seconds: 5), _startSSE);
      });
    } catch (e) {
      if (mounted) Future.delayed(const Duration(seconds: 5), _startSSE);
    }
  }

  Future<void> _changeStatus(String itemId, String newStatus) async {
    // Optimistic UI update
    final index = _items.indexWhere((i) => i['id'] == itemId);
    if (index != -1) {
      setState(() {
        _items[index]['status'] = newStatus;
      });
    }

    try {
      await widget.apiClient.patch('/orders/items/$itemId/status', body: {'status': newStatus});
    } catch (e) {
      // Revert optimism on failure
      if (mounted) {
        await _loadQueue(); 
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.error));
      }
    }
  }

  Future<void> _completeItem(String itemId) async {
    // Optimistic remove entirely from board
    setState(() => _items.removeWhere((i) => i['id'] == itemId));
    try {
      await widget.apiClient.patch('/orders/items/$itemId/status', body: {'status': 'served'});
    } catch (e) {
      if (mounted) await _loadQueue();
    }
  }

  Widget _buildItemCard(Map<String, dynamic> it, Color accentColor, {bool showCompleteButton = false}) {
    final mi = it['menuItem'] as Map? ?? {};
    final order = it['order'] as Map? ?? {};
    final session = order['tableSession'] as Map? ?? {};
    final table = session['table'] as Map? ?? {};
    final name = (mi['name'] ?? '').toString();
    final qty = (it['quantity'] ?? 1).toString();
    final notes = (it['notes'] ?? '').toString();
    final tableName = (table['name'] ?? '').toString();
    
    DateTime? createdAt;
    if (it['createdAt'] != null) {
      createdAt = DateTime.tryParse(it['createdAt'] as String);
    }
    final timeStr = createdAt != null ? DateFormat('HH:mm').format(createdAt.toLocal()) : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accentColor.withValues(alpha: 0.4), width: 1.5),
      ),
      color: AppTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text('${qty}x $name'.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AppTheme.textPrimary))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                  child: Text(timeStr, style: TextStyle(color: accentColor, fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.table_bar, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(tableName, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              ],
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.comment, size: 12, color: AppTheme.warning),
                    const SizedBox(width: 4),
                    Expanded(child: Text(notes, style: const TextStyle(color: AppTheme.warning, fontSize: 12, fontStyle: FontStyle.italic))),
                  ],
                ),
              ),
            ],
            if (showCompleteButton) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _completeItem(it['id'] as String),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success.withValues(alpha: 0.2), foregroundColor: AppTheme.success),
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('SERVE / CLEAR'),
                ),
              ),
            ]
          ],
        ),
      ),
    ).animate().fade(duration: 400.ms).slideX(begin: 0.05);
  }

  int _getStatusWeight(String st) {
    switch (st) {
      case 'pending': return 0;
      case 'preparing': return 1;
      case 'ready': return 2;
      case 'served': return 3;
      default: return -1;
    }
  }

  Widget _buildKanbanColumn(String title, String status, Color color, {bool showCompleteButton = false, required double width}) {
    final colItems = _items.where((i) => i['status'] == status).toList();
    return SizedBox(
      width: width,
      child: DragTarget<Map<String, dynamic>>(
        onAcceptWithDetails: (details) {
          final oldStatus = details.data['status'] as String;
          if (oldStatus != status) {
            if (_getStatusWeight(status) < _getStatusWeight(oldStatus)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Orders cannot be moved backward in the queue!'),
                  backgroundColor: AppTheme.warning,
                  behavior: SnackBarBehavior.floating,
                ),
              );
              return;
            }
            _changeStatus(details.data['id'] as String, status);
          }
        },
        builder: (context, candidateData, rejectedData) {
          final isActive = candidateData.isNotEmpty;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: isActive ? color.withValues(alpha: 0.1) : Colors.transparent,
              border: Border.all(color: isActive ? color : Colors.white.withValues(alpha: 0.05)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2)),
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: color,
                        child: Text('${colItems.length}', style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: colItems.length,
                    itemBuilder: (ctx, i) {
                      final item = colItems[i];
                      return LongPressDraggable<Map<String, dynamic>>(
                        data: item,
                        hapticFeedbackOnStart: true,
                        delay: const Duration(milliseconds: 200), // Quick delay so they don't have to wait long
                        feedback: Material(
                          elevation: 8,
                          color: Colors.transparent,
                          child: SizedBox(width: 320, child: _buildItemCard(item, color)),
                        ),
                        childWhenDragging: Opacity(opacity: 0.3, child: _buildItemCard(item, color)),
                        child: _buildItemCard(item, color, showCompleteButton: showCompleteButton),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Real-Time Queue: '),
            if (_destinations.isNotEmpty)
              DropdownButton<String>(
                value: _destinationId,
                dropdownColor: AppTheme.surface,
                underline: const SizedBox(),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.accent),
                icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.accent),
                items: _destinations
                    .map((d) => DropdownMenuItem<String>(
                          value: d['id'] as String,
                          child: Text(d['name'] as String? ?? 'Destination'),
                        ))
                    .toList(),
                onChanged: (v) async {
                  setState(() => _destinationId = v);
                  await _loadQueue();
                  _startSSE();
                },
              ),
          ],
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: _sseClient == null ? AppTheme.error : AppTheme.success),
                  ),
                  const SizedBox(width: 8),
                  Text(_sseClient == null ? 'Offline' : 'Live stream', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : LayoutBuilder(
              builder: (context, constraints) {
                // Determine column width - minimum 340px for mobile/tablet, larger for desktop
                final minColWidth = 340.0;
                final availableWidth = constraints.maxWidth - 24; // account for padding
                final colWidth = (availableWidth / 3) > minColWidth ? (availableWidth / 3) : minColWidth;

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(12.0),
                  child: SizedBox(
                    height: constraints.maxHeight - 24, // subtract vertical padding
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildKanbanColumn('NEW / PENDING', 'pending', AppTheme.info, width: colWidth),
                        _buildKanbanColumn('PREPARING', 'preparing', AppTheme.warning, width: colWidth),
                        _buildKanbanColumn('READY / SERVE', 'ready', AppTheme.success, showCompleteButton: true, width: colWidth),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
