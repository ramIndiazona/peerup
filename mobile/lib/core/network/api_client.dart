import 'dart:async';

import 'package:dio/dio.dart';

import '../auth/token_manager.dart';
import '../config/app_config.dart';
import 'api_exception.dart';
import 'logging_interceptor.dart';

class ApiClient {
  ApiClient({required this.tokens}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiRoot,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Accept': 'application/json'},
      ),
    );
    _dio.interceptors.add(const LoggingInterceptor());
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.extra['skipAuthRefresh'] == true) {
            handler.next(options);
            return;
          }
          final token = await tokens.accessToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.requestOptions.extra['skipAuthRefresh'] == true) {
            handler.next(error);
            return;
          }
          if (error.response?.statusCode == 401 && !_isRetry(error)) {
            // Single-flight refresh is owned by TokenManager; every HTTP 401
            // goes through it so the socket and HTTP layers share one refresh.
            final newAccess = await tokens.getValidAccessToken();
            if (newAccess != null) {
              final opts = error.requestOptions;
              opts.headers['Authorization'] = 'Bearer $newAccess';
              try {
                final response = await _dio.fetch(opts);
                handler.resolve(response);
                return;
              } catch (e) {
                handler.next(
                  e is DioException
                      ? e
                      : DioException(requestOptions: opts, error: e),
                );
                return;
              }
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  late final Dio _dio;
  final TokenManager tokens;

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    Options? options,
  }) async {
    return _run(() => _dio.get(path, queryParameters: query, options: options));
  }

  Future<dynamic> post(String path, {dynamic data, Options? options}) async {
    return _run(() => _dio.post(path, data: data, options: options));
  }

  Future<dynamic> patch(String path, {dynamic data, Options? options}) async {
    return _run(() => _dio.patch(path, data: data, options: options));
  }

  Future<dynamic> delete(String path, {dynamic data, Options? options}) async {
    return _run(() => _dio.delete(path, data: data, options: options));
  }

  /// POST that bypasses access-token injection and the 401 refresh retry.
  /// Used when the credentials live in the body (e.g. auth/refresh).
  Future<dynamic> postRaw(String path, {dynamic data}) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        options: Options(
          headers: {'Content-Type': 'application/json'},
          extra: const {'skipAuthRefresh': true},
        ),
      );
      return response.data;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<dynamic> _run(Future<Response<dynamic>> Function() request) async {
    try {
      final response = await request();
      return response.data;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  ApiException _mapError(DioException e) {
    if (e.response == null) {
      return NetworkException('No connection to server. Check your network.');
    }
    final data = e.response?.data;
    final message = data is Map ? data['message'] : null;
    final code = data is Map ? data['code'] : null;
    return ApiException(
      code is String ? code : 'HTTP_${e.response?.statusCode}',
      message is String
          ? message
          : 'Request failed (${e.response?.statusCode})',
      statusCode: e.response?.statusCode,
      details: data,
    );
  }

  bool _isRetry(DioException e) {
    final id = '${e.requestOptions.method}:${e.requestOptions.path}';
    if (_retried.contains(id)) return true;
    _retried.add(id);
    return false;
  }

  final Set<String> _retried = {};
}
