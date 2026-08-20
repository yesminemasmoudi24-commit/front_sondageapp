import '../core/api_client.dart';
import '../models/user_model.dart';

class AuthService {
  AuthService(this._api);

  final ApiClient _api;

  Future<({UserModel user, String token})> login({
    required String email,
    required String password,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/login',
      body: {'email': email, 'password': password},
      parser: (raw) => raw as Map<String, dynamic>,
    );

    final data = res.data!;
    final token = data['token'] as String;
    final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
    await _api.setToken(token);
    return (user: user, token: token);
  }

  Future<void> logout() async {
    try {
      await _api.post('/logout');
    } finally {
      await _api.setToken(null);
    }
  }

  Future<UserModel> profile() async {
    final res = await _api.get<UserModel>(
      '/profile',
      parser: (raw) => UserModel.fromJson(raw as Map<String, dynamic>),
    );
    return res.data!;
  }
}
