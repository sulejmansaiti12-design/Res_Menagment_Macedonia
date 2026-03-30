import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// SSE (Server-Sent Events) client for the foreground Flutter app.
///
/// Key fixes over the previous version:
/// - Processes `data:` lines immediately (no empty-line buffering bug)
/// - Exponential backoff with jitter on reconnect
/// - Proper cleanup of old connections before reconnecting
class SseService {
  http.Client? _client;
  StreamController<Map<String, dynamic>>? _controller;
  StreamSubscription? _subscription;
  bool _isConnected = false;
  bool _isReconnecting = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectDelay = 30; // seconds

  Stream<Map<String, dynamic>> connect(String path, String token) {
    disconnect(); // Clean up any existing connection
    _controller = StreamController<Map<String, dynamic>>.broadcast();
    _reconnectAttempts = 0;
    _startListening(path, token);
    return _controller!.stream;
  }

  void _startListening(String path, String token) async {
    if (_controller == null || _controller!.isClosed) return;
    if (_isReconnecting) return;
    _isReconnecting = true;

    // Clean up previous connection
    _subscription?.cancel();
    _client?.close();
    _client = http.Client();

    try {
      final request =
          http.Request('GET', Uri.parse('${AppConfig.baseUrl}$path'));
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'text/event-stream';
      request.headers['Cache-Control'] = 'no-cache';
      request.headers['ngrok-skip-browser-warning'] = '69420';

      final response = await _client!.send(request);

      if (response.statusCode != 200) {
        _scheduleReconnect(path, token);
        return;
      }

      _isConnected = true;
      _isReconnecting = false;
      _reconnectAttempts = 0; // Reset on successful connection

      _subscription = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          // Process data lines immediately — the server sends
          // single-line JSON payloads as `data: {...}\n\n`
          if (line.startsWith('data: ')) {
            try {
              final jsonStr = line.substring(6).trim();
              if (jsonStr.isEmpty) return;
              final data =
                  jsonDecode(jsonStr) as Map<String, dynamic>;
              _controller?.add(data);
            } catch (e) {
              debugPrint('[SSE] JSON parse error: $e');
            }
          }
          // Ignore SSE comments (`:heartbeat ...`) and empty lines
        },
        onError: (error) {
          debugPrint('[SSE] Stream error: $error');
          _isConnected = false;
          _scheduleReconnect(path, token);
        },
        onDone: () {
          debugPrint('[SSE] Stream closed by server');
          _isConnected = false;
          _scheduleReconnect(path, token);
        },
        cancelOnError: false, // ← CRITICAL: Don't kill the listener on errors
      );
    } catch (e) {
      debugPrint('[SSE] Connection error: $e');
      _isConnected = false;
      _scheduleReconnect(path, token);
    }
  }

  /// Exponential backoff with jitter: 1s, 2s, 4s, 8s, ... up to 30s
  void _scheduleReconnect(String path, String token) {
    _isReconnecting = false;
    if (_controller == null || _controller!.isClosed) return;

    final baseDelay = min(pow(2, _reconnectAttempts).toInt(), _maxReconnectDelay);
    final jitter = Random().nextInt(1000); // 0-999ms jitter
    final delay = Duration(seconds: baseDelay, milliseconds: jitter);

    _reconnectAttempts++;
    debugPrint('[SSE] Reconnecting in ${delay.inMilliseconds}ms (attempt $_reconnectAttempts)');

    Future.delayed(delay, () {
      if (_controller != null && !_controller!.isClosed) {
        _startListening(path, token);
      }
    });
  }

  bool get isConnected => _isConnected;

  void disconnect() {
    _isConnected = false;
    _isReconnecting = false;
    _subscription?.cancel();
    _subscription = null;
    _client?.close();
    _client = null;
    _controller?.close();
    _controller = null;
    _reconnectAttempts = 0;
  }
}
