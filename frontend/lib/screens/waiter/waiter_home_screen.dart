import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../config/app_theme.dart';
import '../../services/api_client.dart';
import '../../services/sse_service.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';
import 'waiter_dashboard_tab.dart';
import 'waiter_tables_tab.dart';
import 'waiter_notifications_tab.dart';

class WaiterHomeScreen extends StatefulWidget {
  final ApiClient apiClient;
  const WaiterHomeScreen({super.key, required this.apiClient});

  @override
  State<WaiterHomeScreen> createState() => _WaiterHomeScreenState();
}

class _WaiterHomeScreenState extends State<WaiterHomeScreen> {
  int _currentIndex = 0;
  Map<String, dynamic>? _activeShift;
  List<Map<String, dynamic>> _zones = [];
  bool _isStartingShift = false;
  String? _selectedZoneId;
  final SseService _sseService = SseService();
  int _unreadNotifications = 0;
  List<Map<String, dynamic>> _notifications = [];
  int _refreshCounter = 0;
  Timer? _pollTimer; // Android polling fallback
  final Set<String> _seenNotificationIds = {}; // Track seen IDs

  @override
  void initState() {
    super.initState();
    _loadZones();
    _checkActiveShift();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _sseService.disconnect();
    super.dispose();
  }

  Future<void> _loadZones() async {
    try {
      final res = await widget.apiClient.get('/zones');
      setState(() {
        _zones = List<Map<String, dynamic>>.from(
          (res['data']['zones'] as List).map((z) => Map<String, dynamic>.from(z as Map)),
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading zones: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _checkActiveShift() async {
    try {
      final res = await widget.apiClient.get('/shifts/active');
      if (res['data']['shift'] != null) {
        setState(() {
          _activeShift = Map<String, dynamic>.from(res['data']['shift'] as Map);
        });
        await _fetchNotifications();
        _connectSSE();
        _startPolling();
      }
    } catch (_) {}
  }

  Future<void> _fetchNotifications() async {
    if (_activeShift == null) return;
    try {
      final zoneId = _activeShift!['zoneId'];
      final res = await widget.apiClient.get('/notifications?zoneId=$zoneId&unreadOnly=true');
      if (!mounted) return;
      final list = (res['data']['notifications'] as List).cast<Map<String, dynamic>>();
      setState(() {
        _notifications = list;
        _unreadNotifications = list.length;
      });
    } catch (_) {}
  }

  void _connectSSE() {
    if (_activeShift == null) return;
    final auth = context.read<AuthProvider>();
    final zoneId = _activeShift!['zoneId'];

    final stream = _sseService.connect(
      '/notifications/sse?zoneId=$zoneId',
      auth.token!,
    );

    stream.listen((event) {
      if (!mounted) return;
      final type = event['type'] as String?;
      if (type == 'connected') return;

      setState(() {
        _notifications.insert(0, event);
        _unreadNotifications++;
        _refreshCounter++;
      });
      
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);

      // ── Fire native OS notification (Windows toast / Android heads-up) ──
      if (NotificationService.isAlertType(type)) {
        final tableName = event['tableName'] as String? ?? 'Table';
        final message = event['message'] as String? ?? 'New alert';
        NotificationService.instance.showAlert(
          NotificationService.buildAlertTitle(type, tableName),
          message,
        );
      }

      // Show in-app snackbar for important notifications
      if (type == 'newOrder' || type == 'callWaiter' || type == 'requestBill' || type == 'requestWater') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(event['message'] as String? ?? 'New notification', style: const TextStyle(fontWeight: FontWeight.bold)),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: type == 'newOrder' ? AppTheme.success.withValues(alpha: 0.9) : type == 'requestBill' ? AppTheme.warning.withValues(alpha: 0.9) : AppTheme.info.withValues(alpha: 0.9),
            action: SnackBarAction(
              label: 'VIEW',
              textColor: Colors.white,
              onPressed: () => setState(() => _currentIndex = 1),
            ),
          ),
        );
      }
    });
  }

  /// Polling fallback — every 5 seconds, check for new notifications.
  /// This is the reliable fix for Android where SSE streaming doesn't work.
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted || _activeShift == null) return;
      try {
        final zoneId = _activeShift!['zoneId'];
        final res = await widget.apiClient.get('/notifications?zoneId=$zoneId&unreadOnly=true');
        if (!mounted) return;
        final list = (res['data']['notifications'] as List)
            .map((n) => Map<String, dynamic>.from(n as Map))
            .toList();

        // Track if any new notifications were actually found
        bool hasNew = false;
        
        // If this is the first poll and we have no seen IDs yet,
        // just populate the set so we don't spam alerts for existing ones.
        if (_seenNotificationIds.isEmpty && list.isNotEmpty) {
          for (final notif in list) {
            _seenNotificationIds.add(notif['id'] as String);
          }
        } else {
          for (final notif in list) {
            final id = notif['id'] as String;
            if (!_seenNotificationIds.contains(id)) {
              _seenNotificationIds.add(id);
              hasNew = true;

              final type = notif['type'] as String?;
              if (type == null) continue;

              // ── Fire alerts ──
              HapticFeedback.heavyImpact();
              SystemSound.play(SystemSoundType.alert);

              if (NotificationService.isAlertType(type)) {
                final tableName = notif['title'] as String? ?? 'Table';
                final message = notif['message'] as String? ?? 'New alert';
                NotificationService.instance.showAlert(tableName, message);
              }

              // Show snackbar for only the newest one we process
              if (notif == list.first) {
                final msg = notif['message'] as String? ?? notif['title'] as String? ?? 'New notification';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: type == 'newOrder'
                        ? AppTheme.success.withValues(alpha: 0.9)
                        : type == 'requestBill'
                            ? AppTheme.warning.withValues(alpha: 0.9)
                            : AppTheme.info.withValues(alpha: 0.9),
                    action: SnackBarAction(
                      label: 'VIEW',
                      textColor: Colors.white,
                      onPressed: () => setState(() => _currentIndex = 1),
                    ),
                  ),
                );
              }
            }
          }
        }

        // Update state
        setState(() {
          _notifications = list;
          _unreadNotifications = list.length;
          if (hasNew) _refreshCounter++;
        });
      } catch (_) {}
    });
  }

  Future<void> _startShift() async {
    if (_selectedZoneId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a zone before starting'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isStartingShift = true);
    try {
      final res = await widget.apiClient.post('/shifts/start', body: {
        'zoneId': _selectedZoneId,
      });

      setState(() {
        _activeShift = Map<String, dynamic>.from(res['data']['shift'] as Map);
        _isStartingShift = false;
      });
      context.read<AuthProvider>().setActiveShift(_activeShift);
      await _fetchNotifications();
      _connectSSE();
      _startPolling();

      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final service = FlutterBackgroundService();
        await service.startService();
        service.invoke(
          'setParams',
          {
            'token': context.read<AuthProvider>().token,
            'zoneId': _selectedZoneId,
            'baseUrl': AppConfig.baseUrl,
          },
        );
      }
    } catch (e) {
      setState(() => _isStartingShift = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _endShift() async {
    try {
      final res = await widget.apiClient.post('/shifts/end');
      if (res['success'] == true) {
        _pollTimer?.cancel();
        _sseService.disconnect();
        if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
          FlutterBackgroundService().invoke('stopService');
        }
        setState(() => _activeShift = null);
        context.read<AuthProvider>().setActiveShift(null);
      } else {
        if (mounted) {
          final errorMsg = res['error']?['message'] ?? 'Cannot end shift';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMsg), backgroundColor: AppTheme.warning, behavior: SnackBarBehavior.floating),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // No active shift - show start shift screen
    if (_activeShift == null) {
      return _buildStartShiftScreen(auth);
    }

    final tabs = [
      WaiterTablesTab(apiClient: widget.apiClient, activeShift: _activeShift!, refreshCounter: _refreshCounter, notifications: _notifications),
      WaiterNotificationsTab(
        notifications: _notifications,
        apiClient: widget.apiClient,
        activeShift: _activeShift!,
        onClearNotifications: () async {
          try {
            await widget.apiClient.put('/notifications/read-all', body: {'zoneId': _activeShift!['zoneId']});
            await _fetchNotifications();
            setState(() { _refreshCounter++; });
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error clearing notifications: $e')));
          }
        },
        onRefresh: _fetchNotifications,
      ),
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              auth.userName.toUpperCase(),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: AppTheme.primary),
            ),
            Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(_getZoneName(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
              ],
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings_rounded, color: AppTheme.textSecondary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
            color: AppTheme.surface,
            onSelected: (value) {
              switch (value) {
                case 'logout':
                  _showLogoutDialog();
                  break;
                case 'endShift':
                  _showEndShiftDialog();
                  break;
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, color: AppTheme.textSecondary, size: 20),
                    SizedBox(width: 12),
                    Text('Log Out', style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'endShift',
                child: Row(
                  children: [
                    Icon(Icons.stop_circle_rounded, color: AppTheme.error, size: 20),
                    SizedBox(width: 12),
                    Text('End Shift', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      extendBody: true,
      body: tabs[_currentIndex],
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.surface.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 1),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 10)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(0, Icons.grid_view_rounded, 'Tables'),
                  _buildNavItem(1, Icons.notifications_rounded, 'Alerts', badgeCount: _unreadNotifications),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, {int badgeCount = 0}) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? AppTheme.primary : AppTheme.textSecondary;

    return GestureDetector(
      onTap: () => setState(() {
        _currentIndex = index;
        if (index == 1) _unreadNotifications = 0;
      }),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Badge(
              isLabelVisible: badgeCount > 0,
              label: Text('$badgeCount', style: const TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: AppTheme.error,
              child: AnimatedScale(
                scale: isSelected ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(icon, color: color, size: 28),
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildStartShiftScreen(AuthProvider auth) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.accent], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      boxShadow: [
                        BoxShadow(color: AppTheme.primary.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 10)),
                      ],
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 2),
                    ),
                    child: Center(
                      child: Text(
                        auth.userName.isNotEmpty ? auth.userName[0].toUpperCase() : 'W',
                        style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome back, ${auth.userName}!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select your designated zone to establish your shift and start receiving orders.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 15, height: 1.5),
                  ),
                  const SizedBox(height: 48),

                  // Zone selection
                  if (_zones.isNotEmpty)
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 400),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 10)),
                        ],
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          icon: const Icon(Icons.expand_more_rounded, color: AppTheme.textSecondary),
                          hint: const Text('Assign Working Zone', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                          value: _selectedZoneId,
                          dropdownColor: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(20),
                          items: _zones.map((z) {
                            return DropdownMenuItem<String>(
                              value: z['id'] as String,
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.place_rounded, color: AppTheme.primary, size: 20),
                                  ),
                                  const SizedBox(width: 16),
                                  Text(z['name'] as String, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (v) => setState(() => _selectedZoneId = v),
                        ),
                      ),
                    )
                  else
                    const Center(child: CircularProgressIndicator(color: AppTheme.primary)),

                  const SizedBox(height: 32),

                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 400),
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(colors: [AppTheme.success, AppTheme.success]),
                      boxShadow: [
                        BoxShadow(color: AppTheme.success.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isStartingShift ? null : _startShift,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: _isStartingShift
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('START SHIFT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.5, color: Colors.white)),
                                SizedBox(width: 12),
                                Icon(Icons.arrow_forward_rounded, color: Colors.white),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  TextButton.icon(
                    onPressed: () => context.read<AuthProvider>().logout(),
                    icon: const Icon(Icons.logout_rounded, color: AppTheme.textSecondary, size: 20),
                    label: const Text('Sign Out', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getZoneName() {
    if (_activeShift == null) return '';
    final zone = _activeShift!['zone'];
    if (zone is Map) return zone['name'] as String? ?? '';

    // Find zone by ID
    final zoneId = _activeShift!['zoneId'];
    final found = _zones.where((z) => z['id'] == zoneId);
    return found.isNotEmpty ? found.first['name'] as String : '';
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
        title: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('You will be signed out but your shift will continue on the server. You can log back in later to resume.', style: TextStyle(color: AppTheme.textSecondary, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _sseService.disconnect();
              context.read<AuthProvider>().logout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEndShiftDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.error),
            SizedBox(width: 12),
            Text('End Shift', style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.error)),
          ],
        ),
        content: const Text('Are you sure you want to end your shift? You will stop receiving orders for this zone.', style: TextStyle(color: AppTheme.textSecondary, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _endShift();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('End Shift', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
