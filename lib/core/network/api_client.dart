import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';

/// Error de la API con el formato estándar del backend (sección 2.4 de la
/// Especificación de Endpoints): { error: { code, message, details, request_id } }.
class ApiException implements Exception {
  ApiException({required this.statusCode, required this.code, required this.message});

  final int statusCode;
  final String code;
  final String message;

  factory ApiException.fromDio(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] is Map) {
      final err = data['error'] as Map;
      return ApiException(
        statusCode: e.response?.statusCode ?? 0,
        code: (err['code'] ?? 'UNKNOWN').toString(),
        message: (err['message'] ?? 'Ocurrió un error inesperado.').toString(),
      );
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError) {
      return ApiException(
        statusCode: 0,
        code: 'NETWORK_ERROR',
        message: 'Sin conexión. Revisa tu internet e intenta de nuevo.',
      );
    }
    return ApiException(
      statusCode: e.response?.statusCode ?? 0,
      code: 'UNKNOWN',
      message: 'Algo salió mal. Intenta más tarde.',
    );
  }

  @override
  String toString() => 'ApiException($statusCode $code): $message';
}

/// Cliente HTTP con renovación automática del access token.
class ApiClient {
  /// [dio] y [refreshDio] solo existen para reemplazar el cliente HTTP real
  /// por uno falso en los tests (ver test/core/network/api_client_test.dart).
  /// En la app nunca se pasan: se arman con la configuración normal.
  ApiClient(
    this._tokens, {
    @visibleForTesting Dio? dio,
    @visibleForTesting Dio? refreshDio,
  }) : _refreshDio = refreshDio ??
            Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl + AppConfig.apiVersion)) {
    _dio = dio ??
        Dio(BaseOptions(
          baseUrl: AppConfig.apiBaseUrl + AppConfig.apiVersion,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
          headers: {'Content-Type': 'application/json'},
        ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _tokens.accessToken;
        if (token != null && !_isPublicPath(options.path)) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        // 401 -> intenta refresh una vez y reintenta la petición original.
        if (error.response?.statusCode == 401 &&
            !_isPublicPath(error.requestOptions.path) &&
            error.requestOptions.extra['retried'] != true) {
          final refreshed = await _tryRefresh();
          if (refreshed) {
            final opts = error.requestOptions..extra['retried'] = true;
            opts.headers['Authorization'] = 'Bearer ${await _tokens.accessToken}';
            try {
              final response = await _dio.fetch(opts);
              return handler.resolve(response);
            } catch (_) {/* cae al handler.next */}
          } else {
            await _tokens.clear();
            onSessionExpired?.call();
          }
        }
        handler.next(error);
      },
    ));
  }

  final TokenStorage _tokens;
  late final Dio _dio;
  final Dio _refreshDio;

  /// Callback para que la capa de auth reaccione al vencimiento de sesión.
  void Function()? onSessionExpired;

  bool _isPublicPath(String path) =>
      path.startsWith('/auth/') || path == '/health';

  Future<bool> _tryRefresh() async {
    final refresh = await _tokens.refreshToken;
    if (refresh == null) return false;
    try {
      final res = await _refreshDio.post('/auth/refresh', data: {'refresh_token': refresh});
      await _tokens.save(
        access: res.data['access_token'] as String,
        refresh: res.data['refresh_token'] as String,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<T> get<T>(String path, {Map<String, dynamic>? query}) =>
      _wrap(() => _dio.get<T>(path, queryParameters: query));

  Future<T> post<T>(String path, {Object? data}) =>
      _wrap(() => _dio.post<T>(path, data: data));

  Future<T> patch<T>(String path, {Object? data}) =>
      _wrap(() => _dio.patch<T>(path, data: data));

  Future<T> put<T>(String path, {Object? data}) =>
      _wrap(() => _dio.put<T>(path, data: data));

  Future<T> delete<T>(String path) => _wrap(() => _dio.delete<T>(path));

  Future<T> _wrap<T>(Future<Response<T>> Function() call) async {
    try {
      final res = await call();
      return res.data as T;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(tokenStorageProvider));
});
