import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../storage/token_storage.dart';

/// Strategy used to obtain a brand-new access token. The refresh token is
/// passed in; throws on network errors so the caller can decide whether the
/// session is truly invalid.
typedef TokenRefresher = Future<String?> Function(String refreshToken);

/// Owns the token lifecycle for the whole app.
///
/// - persists access/refresh tokens
/// - decides whether the access token can still be used (JWT `exp`)
/// - performs refresh with a single in-flight request (concurrent callers all
///   wait on the same refresh instead of firing N refreshes)
/// - clears credentials when refresh is definitively refused by the server
///
/// `RealtimeSocketService`, `ApiClient` and `AuthService` all go through this
/// class. Nothing else may read tokens from storage directly.
class TokenManager {
  TokenManager({required TokenStorage storage, TokenRefresher? refresher})
    : _storage = storage,
      _refresher = refresher;

  final TokenStorage _storage;
  TokenRefresher? _refresher;
  Completer<String?>? _refreshInFlight;

  /// Installed by [AuthService] so refreshing goes through the HTTP layer
  /// without creating a circular dependency (AuthService -> TokenManager ->
  /// refresher -> AuthService -> HTTP).
  set refresher(TokenRefresher? value) => _refresher = value;

  Future<String?> get accessToken => _storage.accessToken;
  Future<String?> get refreshToken => _storage.refreshToken;

  Future<bool> hasSession() => _storage.hasSession();

  Future<void> saveSession({required String access, required String refresh}) =>
      _storage.saveTokens(access: access, refresh: refresh);

  Future<void> updateAccessToken(String access) async {
    final current = await _storage.refreshToken;
    if (current == null || current.isEmpty) return;
    await _storage.saveTokens(access: access, refresh: current);
  }

  Future<String?> get cachedUser => _storage.cachedUser;
  Future<void> saveUser(String json) => _storage.saveUser(json);

  Future<void> clear() => _storage.clear();

  /// True when the token carries a JWT `exp` and that time has passed (with a
  /// small safety margin so we never hand an about-to-expire token to a socket).
  bool isExpired(String token) {
    final expSeconds = _jwtExpSeconds(token);
    if (expSeconds == null) return false;
    final cutoff = DateTime.now().add(const Duration(seconds: 15));
    return DateTime.fromMillisecondsSinceEpoch(
      expSeconds * 1000,
    ).isBefore(cutoff);
  }

  /// Returns a usable access token:
  /// - the stored token if it is not expired;
  /// - otherwise refreshes it (single-flight) and returns the new one;
  /// - null when there is no session or refresh was refused.
  Future<String?> getValidAccessToken() async {
    final access = await _storage.accessToken;
    if (access != null && access.isNotEmpty && !isExpired(access)) {
      return access;
    }
    return _refresh();
  }

  /// Force a refresh even when the stored token looks valid. Used when the
  /// backend rejects the WS token (UNAUTHORIZED): the stored token may still
  /// pass a local expiry check while being unusable. Guarantees the next
  /// socket connect or HTTP request uses a token the server accepts.
  Future<String?> forceRefresh() => _refresh();

  Future<String?> _refresh() async {
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight.future;

    final completer = Completer<String?>();
    _refreshInFlight = completer;
    try {
      final refresher = _refresher;
      final refresh = await _storage.refreshToken;
      if (refresher == null || refresh == null || refresh.isEmpty) {
        await _storage.clear();
        completer.complete(null);
        return null;
      }

      String? fresh;
      try {
        fresh = await refresher(refresh);
      } on Exception catch (e) {
        debugPrint('[AUTH] token refresh threw: $e');
        fresh = null;
      }

      if (fresh == null || fresh.isEmpty) {
        // Refresher already cleared the persisted session when the server
        // refused the refresh token (401). A transient network error leaves
        // the stored tokens in place so a later attempt can retry.
        completer.complete(null);
        return null;
      }

      await updateAccessToken(fresh);
      debugPrint('[AUTH] token refreshed');
      completer.complete(fresh);
      return fresh;
    } finally {
      _refreshInFlight = null;
    }
  }

  int? _jwtExpSeconds(String token) {
    final parts = token.split('.');
    if (parts.length < 2) return null;
    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final map = jsonDecode(payload) as Map<String, dynamic>;
      final exp = map['exp'];
      return exp is num ? exp.toInt() : null;
    } catch (_) {
      return null;
    }
  }
}
