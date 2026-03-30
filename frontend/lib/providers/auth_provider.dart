import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_client.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient _api;
  String? _token;
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _activeShift;
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _waiterList = [];

  AuthProvider(this._api);

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  Map<String, dynamic>? get activeShift => _activeShift;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _token != null;
  String get userRole => _user?['role'] ?? '';
  String get userName => _user?['name'] ?? '';
  String get userId => _user?['id'] ?? '';
  List<Map<String, dynamic>> get waiterList => _waiterList;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    final userData = prefs.getString('user_data');
    if (userData != null) {
      try {
        _user = Map<String, dynamic>.from(jsonDecode(userData) as Map);
      } catch (_) {}
    }
    if (_token != null) {
      _api.setToken(_token);
      // Verify token is still valid
      try {
        final res = await _api.get('/auth/me');
        _user = res['data']['user'] as Map<String, dynamic>;
        await prefs.setString('user_data', jsonEncode(_user));
      } catch (_) {
        await logout();
      }
    }
    notifyListeners();
  }

  Future<void> loadWaiterList() async {
    try {
      final res = await _api.get('/auth/waiters');
      _waiterList = List<Map<String, dynamic>>.from(
        (res['data']['waiters'] as List).map((w) => Map<String, dynamic>.from(w as Map)),
      );
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _api.post('/auth/login', body: {
        'username': username,
        'password': password,
      });

      _token = res['data']['token'] as String;
      _user = res['data']['user'] as Map<String, dynamic>;
      if (res['data']['activeShift'] != null) {
        _activeShift = res['data']['activeShift'] as Map<String, dynamic>;
      }

      _api.setToken(_token);

      // Save to prefs
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', _token!);
      await prefs.setString('user_data', jsonEncode(_user));

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    _activeShift = null;
    _api.setToken(null);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_data');

    notifyListeners();
  }

  void setActiveShift(Map<String, dynamic>? shift) {
    _activeShift = shift;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
