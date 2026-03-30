import 'dart:async';
import 'dart:convert';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

// ─── Channel IDs ───────────────────────────────────────────────────
const _serviceChannelId = 'restaurant_service';
const _alertChannelId = 'restaurant_high_alerts';
const foregroundNotificationId = 888;

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  // ── 1. Silent Service Channel (keeps app alive quietly) ──────────
  const AndroidNotificationChannel serviceChannel = AndroidNotificationChannel(
    _serviceChannelId,
    'Background Service',
    description: 'Keeps the restaurant notification listener running.',
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
    showBadge: false,
  );

  // ── 2. High-Priority Alert Channel (vibrate + heads-up banner) ───
  const AndroidNotificationChannel alertChannel = AndroidNotificationChannel(
    _alertChannelId,
    'Table Alerts',
    description: 'Immediate alerts for waiter calls, orders, bill requests.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    enableLights: true,
  );

  final FlutterLocalNotificationsPlugin flnPlugin =
      FlutterLocalNotificationsPlugin();

  await flnPlugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  // Create both channels
  final android = flnPlugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  await android?.createNotificationChannel(serviceChannel);
  await android?.createNotificationChannel(alertChannel);

  // Request notification permission on Android 13+
  await android?.requestNotificationsPermission();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: _serviceChannelId,
      initialNotificationTitle: 'Restaurant Manager',
      initialNotificationContent: 'Listening for table requests...',
      foregroundServiceNotificationId: foregroundNotificationId,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Initialize local notifications inside the isolate
  final FlutterLocalNotificationsPlugin flnPlugin =
      FlutterLocalNotificationsPlugin();

  await flnPlugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  // Re-create the alert channel (required in the isolate context)
  await flnPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(const AndroidNotificationChannel(
        _alertChannelId,
        'Table Alerts',
        description:
            'Immediate alerts for waiter calls, orders, bill requests.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
      ));

  int notifCounter = 0;

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  String? token;
  String? zoneId;
  String? baseUrl;
  http.Client? httpClient;
  StreamSubscription? activeSubscription;
  bool isConnecting = false;

  void showAlertNotification(String title, String body) {
    notifCounter++;
    flnPlugin.show(
      id: notifCounter,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _alertChannelId,
          'Table Alerts',
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
      ),
    );
  }

  void connectSSE() async {
    if (token == null || zoneId == null || baseUrl == null) return;
    if (isConnecting) return; // Prevent overlapping connections
    isConnecting = true;

    // ── Clean up previous connection ──
    activeSubscription?.cancel();
    activeSubscription = null;
    try {
      httpClient?.close();
    } catch (_) {}
    httpClient = http.Client();

    final uri = Uri.parse('$baseUrl/notifications/sse?zoneId=$zoneId');
    final request = http.Request('GET', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'text/event-stream'
      ..headers['Cache-Control'] = 'no-cache'
      ..headers['ngrok-skip-browser-warning'] = '69420';

    try {
      final response = await httpClient!.send(request);
      isConnecting = false;

      if (response.statusCode == 200) {
        activeSubscription = response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
          (String line) {
            // ── FIX: Process data lines IMMEDIATELY ──
            // The server sends: `data: {"type":"newOrder",...}\n\n`
            // LineSplitter gives us the `data: ...` line directly.
            // No need to buffer and wait for an empty line.
            if (line.startsWith('data: ')) {
              final dataStr = line.substring(6).trim();
              if (dataStr.isEmpty) return;

              try {
                final data = jsonDecode(dataStr);
                final type = data['type'] as String?;
                if (type == 'connected') return;

                if (type == 'newOrder' ||
                    type == 'callWaiter' ||
                    type == 'requestBill' ||
                    type == 'requestWater' ||
                    type == 'itemReady' ||
                    type == 'item_ready') {
                  final msg = data['message'] as String? ?? 'New Alert';
                  final table = data['tableName'] as String? ?? 'Table';

                  String alertTitle;
                  switch (type) {
                    case 'newOrder':
                      alertTitle = '🍽️ NEW ORDER — $table';
                      break;
                    case 'callWaiter':
                      alertTitle = '🔔 WAITER NEEDED — $table';
                      break;
                    case 'requestBill':
                      alertTitle = '💳 BILL REQUEST — $table';
                      break;
                    case 'requestWater':
                      alertTitle = '💧 WATER REQUEST — $table';
                      break;
                    case 'itemReady':
                    case 'item_ready':
                      alertTitle = '✅ ITEM READY — $table';
                      break;
                    default:
                      alertTitle = '📢 Alert — $table';
                  }

                  showAlertNotification(alertTitle, msg);
                }
              } catch (e) {
                // JSON parse error — ignore
              }
            }
            // Ignore SSE comments (`:heartbeat ...`) and empty lines
          },
          onError: (err) {
            isConnecting = false;
            Future.delayed(const Duration(seconds: 5), connectSSE);
          },
          onDone: () {
            // Server closed the connection — reconnect
            isConnecting = false;
            Future.delayed(const Duration(seconds: 5), connectSSE);
          },
          cancelOnError: false, // ← FIX: Don't kill the stream on errors
        );
      } else {
        Future.delayed(const Duration(seconds: 5), connectSSE);
      }
    } catch (e) {
      isConnecting = false;
      Future.delayed(const Duration(seconds: 5), connectSSE);
    }
  }

  service.on('setParams').listen((event) {
    if (event == null) return;
    token = event['token'] as String?;
    zoneId = event['zoneId'] as String?;
    baseUrl = event['baseUrl'] as String?;
    connectSSE();
  });
}
