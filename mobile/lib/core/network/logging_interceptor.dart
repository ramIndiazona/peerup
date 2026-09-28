import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class LoggingInterceptor extends Interceptor {
  const LoggingInterceptor();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      options.extra['startTime'] = DateTime.now().millisecondsSinceEpoch;
      debugPrint('REQUEST  ${options.method} ${options.uri}');
      final headers = options.headers;
      debugPrint('REQUEST HEADERS: ${_sanitizeHeaders(headers)}');
      if (options.queryParameters.isNotEmpty) {
        debugPrint('REQUEST QUERY: ${options.queryParameters}');
      }
      final data = options.data;
      if (data != null) {
        debugPrint(
          'REQUEST BODY: ${data is FormData ? '<FormData ${data.fields.length} fields>' : _toJson(data)}',
        );
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (kDebugMode) {
      final start = response.requestOptions.extra['startTime'] as int?;
      final elapsed =
          start == null ? null : DateTime.now().millisecondsSinceEpoch - start;
      debugPrint(
        'RESPONSE ${response.requestOptions.method} ${response.requestOptions.uri} '
        '[${response.statusCode}]${elapsed == null ? '' : ' in ${elapsed}ms'}',
      );
      if (response.data != null) {
        debugPrint('RESPONSE BODY: ${_toJson(response.data)}');
      }
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint(
        'ERROR ${err.requestOptions.method} ${err.requestOptions.uri} '
        '[${err.response?.statusCode ?? 'NO_RESPONSE'}] ${err.type}',
      );
      debugPrint('ERROR MESSAGE: ${err.message}');
      final data = err.response?.data;
      if (data != null) {
        debugPrint('ERROR BODY: ${_toJson(data)}');
      }
    }
    handler.next(err);
  }

  String _sanitizeHeaders(Map<String, dynamic> headers) {
    final copy = Map<String, dynamic>.from(headers);
    if (copy.containsKey('Authorization')) {
      copy['Authorization'] = 'Bearer ***';
    }
    return _toJson(copy);
  }

  String _toJson(dynamic value) {
    try {
      return const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      return value.toString();
    }
  }
}
