import '../../models/auth_result.dart';
import '../network/api_client.dart';
import '../network/api_url.dart';

class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  Future<AuthResult> register({
    required String email,
    required String password,
    required String name,
    required String avatar,
    String? phone,
    String? gender,
    String? englishLevel,
  }) async {
    final data = await _api.post(
      APIURL.authRegister,
      data: {
        'email': email.trim().toLowerCase(),
        'password': password,
        'name': name.trim(),
        'avatar': avatar,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (gender != null) 'gender': gender,
        if (englishLevel != null) 'englishLevel': englishLevel,
      },
    );
    return AuthResult.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final data = await _api.post(
      APIURL.authLogin,
      data: {'email': email.trim().toLowerCase(), 'password': password},
    );
    return AuthResult.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<void> logout(String? refreshToken) async {
    await _api.post(
      APIURL.authLogout,
      data: {if (refreshToken != null) 'refreshToken': refreshToken},
    );
  }

  /// New access token via POST auth/refresh. Goes through [ApiClient.postRaw]
  /// so the request never re-enters the 401 refresh interceptor.
  Future<String?> refresh(String refreshToken) async {
    final data = await _api.postRaw(
      APIURL.authRefresh,
      data: {'refreshToken': refreshToken},
    );
    return (data as Map?)?['accessToken'] as String?;
  }
}
