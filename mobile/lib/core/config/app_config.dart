class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3100',
  );

  static const String apiPrefix = String.fromEnvironment(
    'API_PREFIX',
    defaultValue: 'api',
  );

  static const String wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'http://localhost:3100',
  );

  static const String wsPath = '/realtime';

  static const String stunUrl = 'stun:stun.l.google.com:19302';

  static const String turnUrl = String.fromEnvironment('TURN_URL');
  static const String turnUsername = String.fromEnvironment('TURN_USERNAME');
  static const String turnCredential = String.fromEnvironment(
    'TURN_CREDENTIAL',
  );

  static String get apiRoot => '$apiBaseUrl/$apiPrefix/';

  static String resolveAssetUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return '$apiBaseUrl$url';
  }
}
