class ApiException implements Exception {
  const ApiException(this.code, this.message, {this.statusCode, this.details});

  final String code;
  final String message;
  final int? statusCode;
  final dynamic details;

  bool get isUnauthorized => statusCode == 401 || code == 'UNAUTHORIZED';
  bool get isRateLimited => statusCode == 429 || code == 'RATE_LIMITED';

  @override
  String toString() => message;
}

class NetworkException extends ApiException {
  const NetworkException(String message) : super('NETWORK_ERROR', message);
}
