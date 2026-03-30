import 'dart:convert';
import 'package:universal_html/html.dart' as html;
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class ApiClient {
  String? _token;

  void setToken(String? token) {
    _token = token;
  }

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'ngrok-skip-browser-warning': '69420',
    };
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  Future<Map<String, dynamic>> get(String path) async {
    final response = await http
        .get(Uri.parse('${AppConfig.baseUrl}$path'), headers: _headers)
        .timeout(AppConfig.httpTimeout);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body}) async {
    final response = await http
        .post(
          Uri.parse('${AppConfig.baseUrl}$path'),
          headers: _headers,
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(AppConfig.httpTimeout);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? body}) async {
    final response = await http
        .put(
          Uri.parse('${AppConfig.baseUrl}$path'),
          headers: _headers,
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(AppConfig.httpTimeout);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> patch(String path, {Map<String, dynamic>? body}) async {
    final response = await http
        .patch(
          Uri.parse('${AppConfig.baseUrl}$path'),
          headers: _headers,
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(AppConfig.httpTimeout);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final response = await http
        .delete(Uri.parse('${AppConfig.baseUrl}$path'), headers: _headers)
        .timeout(AppConfig.httpTimeout);
    return _handleResponse(response);
  }

  Future<void> downloadFile(String path, String filename) async {
    final headers = <String, String>{};
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }

    final response = await http
        .get(Uri.parse('${AppConfig.baseUrl}$path'), headers: headers)
        .timeout(AppConfig.httpTimeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      // Create a blob and download for web
      final blob = html.Blob([response.bodyBytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..target = 'blank'
        ..download = filename;
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        code: 'DOWNLOAD_ERROR',
        message: 'Failed to download file',
      );
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    final error = body['error'] as Map<String, dynamic>?;
    throw ApiException(
      statusCode: response.statusCode,
      code: error?['code'] as String? ?? 'UNKNOWN',
      message: error?['message'] as String? ?? 'Unknown error',
    );
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String code;
  final String message;

  ApiException({required this.statusCode, required this.code, required this.message});

  @override
  String toString() => message;
}
