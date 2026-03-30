import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Cross-platform notification service singleton.
/// Works on Android, iOS, Windows, macOS, and Linux.
/// On web, notifications are handled via browser SnackBars only.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  int _idCounter = 0;

  // Channel IDs (Android-specific, but defined here for consistency)
  static const String alertChannelId = 'restaurant_high_alerts';
  static const String alertChannelName = 'Table Alerts';
  static const String alertChannelDesc =
      'Immediate alerts for waiter calls, orders, bill requests.';

  /// Initialize the notification plugin. Safe to call multiple times.
  Future<void> initialize() async {
    if (_initialized) return;
    if (kIsWeb) return; // Web doesn't support local notifications

    try {
      // Android settings
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS/macOS settings
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      // Windows settings
      const windowsSettings = WindowsInitializationSettings(
        appName: 'Restaurant Manager',
        appUserModelId: 'com.restaurant.manager',
        guid: 'd3b0a3c2-5f1e-4b8a-9c2d-1a2b3c4d5e6f',
      );

      // Linux settings
      const linuxSettings =
          LinuxInitializationSettings(defaultActionName: 'Open');

      final initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
        windows: windowsSettings,
        linux: linuxSettings,
      );

      await _plugin.initialize(settings: initSettings);

      // Create high-priority channel on Android
      if (!kIsWeb && Platform.isAndroid) {
        final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

        await androidPlugin?.createNotificationChannel(
          const AndroidNotificationChannel(
            alertChannelId,
            alertChannelName,
            description: alertChannelDesc,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            enableLights: true,
          ),
        );

        // Request notification permission (Android 13+)
        await androidPlugin?.requestNotificationsPermission();
      }

      _initialized = true;
    } catch (e) {
      // Silently fail — notifications are best-effort
      _initialized = false;
    }
  }

  /// Show a high-priority alert notification.
  /// Works on Android (heads-up banner + vibrate + sound),
  /// Windows (toast notification), iOS (banner), etc.
  Future<void> showAlert(String title, String body) async {
    if (!_initialized || kIsWeb) return;

    _idCounter++;

    try {
      await _plugin.show(
        id: _idCounter,
        title: title,
        body: body,
        notificationDetails: _buildDetails(),
      );
    } catch (e) {
      // Best-effort — don't crash the app
    }
  }

  NotificationDetails _buildDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        alertChannelId,
        alertChannelName,
        channelDescription: alertChannelDesc,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
        enableLights: true,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        fullScreenIntent: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      windows: WindowsNotificationDetails(
        subtitle: 'Restaurant Manager',
      ),
    );
  }

  /// Build an alert title with emoji based on notification type.
  static String buildAlertTitle(String? type, String tableName) {
    switch (type) {
      case 'newOrder':
        return '🍽️ NEW ORDER — $tableName';
      case 'callWaiter':
        return '🔔 WAITER NEEDED — $tableName';
      case 'requestBill':
        return '💳 BILL REQUEST — $tableName';
      case 'requestWater':
        return '💧 WATER REQUEST — $tableName';
      case 'itemReady':
      case 'item_ready':
        return '✅ ITEM READY — $tableName';
      default:
        return '📢 Alert — $tableName';
    }
  }

  /// Check if a notification type should trigger a native alert.
  static bool isAlertType(String? type) {
    return type == 'newOrder' ||
        type == 'callWaiter' ||
        type == 'requestBill' ||
        type == 'requestWater' ||
        type == 'itemReady' ||
        type == 'item_ready';
  }
}
