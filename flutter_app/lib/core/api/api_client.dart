import 'package:dio/dio.dart';
import '../storage/token_storage.dart';

const _baseUrl = String.fromEnvironment('API_URL', defaultValue: 'https://syncra-backend-aofm.onrender.com/api');

Dio createApiClient() {
  final dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  // Add Authorization header from saved token
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await TokenStorage.getAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        // Auto-refresh on 401
        if (error.response?.statusCode == 401) {
          final refreshToken = await TokenStorage.getRefreshToken();
          if (refreshToken != null) {
            try {
              final refreshDio = Dio(BaseOptions(baseUrl: _baseUrl));
              final resp = await refreshDio.post(
                '/auth/refresh',
                data: {'refreshToken': refreshToken},
              );
              final newAccess = resp.data['accessToken'] as String;
              final newRefresh = resp.data['refreshToken'] as String;
              await TokenStorage.setTokens(
                accessToken: newAccess,
                refreshToken: newRefresh,
              );
              // Retry original request
              error.requestOptions.headers['Authorization'] =
                  'Bearer $newAccess';
              final retried = await dio.fetch(error.requestOptions);
              return handler.resolve(retried);
            } catch (_) {
              await TokenStorage.clearTokens();
            }
          }
        }
        return handler.next(error);
      },
    ),
  );

  return dio;
}

/// Singleton client
final apiClient = createApiClient();
