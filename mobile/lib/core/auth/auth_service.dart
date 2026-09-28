import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../models/auth_result.dart';
import '../network/api_exception.dart';
import 'auth_repository.dart';
import 'token_manager.dart';

/// Application-level auth orchestration.
///
/// Talks to [AuthRepository] for login/register/logout and to [TokenManager]
/// for credential persistence + refreshing. Installing the refresh callback on
/// the [TokenManager] keeps the dependency acyclic
/// (AuthService -> TokenManager -> refresher -> AuthService -> HTTP).
class AuthService {
  AuthService({required AuthRepository repo, required TokenManager tokens})
    : _repo = repo,
      _tokens = tokens {
    _tokens.refresher = _refresh;
  }

  final AuthRepository _repo;
  final TokenManager _tokens;

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final result = await _repo.login(email: email, password: password);
    await _persist(result);
    return result;
  }

  Future<AuthResult> register({
    required String email,
    required String password,
    required String name,
    required String avatar,
    String? phone,
    String? gender,
    String? englishLevel,
  }) async {
    final result = await _repo.register(
      email: email,
      password: password,
      name: name,
      avatar: avatar,
      phone: phone,
      gender: gender,
      englishLevel: englishLevel,
    );
    await _persist(result);
    return result;
  }

  Future<void> logout() async {
    try {
      await _repo.logout(await _tokens.refreshToken);
    } on ApiException {
      // Best effort server-side revoke.
    } finally {
      await _tokens.clear();
    }
  }

  Future<void> updateIdentity(UserIdentity identity) async {
    await _tokens.saveUser(jsonEncode(identity.toJson()));
  }

  Future<String?> getValidAccessToken() => _tokens.getValidAccessToken();

  Future<bool> hasSession() => _tokens.hasSession();
  Future<String?> get cachedUser => _tokens.cachedUser;

  Future<void> _persist(AuthResult result) async {
    await _tokens.saveSession(
      access: result.accessToken,
      refresh: result.refreshToken,
    );
    final identity = result.user;
    if (identity != null) {
      await _tokens.saveUser(jsonEncode(identity.toJson()));
    }
  }

  /// Refresh strategy handed to [TokenManager]. Returns null (and clears the
  /// persisted session) only when the server definitively refuses the refresh
  /// token (401); transient network errors leave the stored tokens in place.
  Future<String?> _refresh(String refreshToken) async {
    debugPrint('[AUTH] refreshing token');
    try {
      final access = await _repo.refresh(refreshToken);
      if (access == null || access.isEmpty) {
        await _tokens.clear();
        return null;
      }
      return access;
    } on ApiException catch (e) {
      debugPrint('[AUTH] refresh failed code=${e.code} status=${e.statusCode}');
      if (e.statusCode == 401) {
        await _tokens.clear();
      }
      return null;
    }
  }
}
