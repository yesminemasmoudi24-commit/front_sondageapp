import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._api) : _auth = AuthService(_api);

  final ApiClient _api;
  final AuthService _auth;

  AuthStatus status = AuthStatus.unknown;
  UserModel? user;
  String? error;

  ApiClient get api => _api;
  AuthService get authService => _auth;

  Future<void> bootstrap() async {
    await _api.loadToken();
    if (_api.token == null || _api.token!.isEmpty) {
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    try {
      user = await _auth.profile();
      status = AuthStatus.authenticated;
    } on ApiException {
      await _api.setToken(null);
      user = null;
      status = AuthStatus.unauthenticated;
    } catch (_) {
      await _api.setToken(null);
      user = null;
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    error = null;
    notifyListeners();
    try {
      final result = await _auth.login(email: email, password: password);
      user = result.user;
      status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      error = e.message;
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } catch (e) {
      error = 'Impossible de joindre le serveur. Vérifie que Laravel tourne.';
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _auth.logout();
    } catch (_) {
      await _api.setToken(null);
    }
    user = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    user = await _auth.profile();
    notifyListeners();
  }
}
