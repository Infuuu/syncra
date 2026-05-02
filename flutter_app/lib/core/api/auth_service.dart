import 'package:dio/dio.dart';
import '../api/api_client.dart';
import '../storage/token_storage.dart';

class AuthService {
  final _dio = apiClient;

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final resp = await _dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    final data = resp.data as Map<String, dynamic>;
    await TokenStorage.setTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
    return data;
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final resp = await _dio.post(
      '/auth/register',
      data: {'email': email, 'password': password, 'displayName': displayName},
    );
    final data = resp.data as Map<String, dynamic>;
    await TokenStorage.setTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
    return data;
  }

  Future<void> logout() async {
    final refreshToken = await TokenStorage.getRefreshToken();
    if (refreshToken != null) {
      try {
        await _dio.post('/auth/logout', data: {'refreshToken': refreshToken});
      } on DioException {
        // ignore
      }
    }
    await TokenStorage.clearTokens();
  }
}

final authService = AuthService();
