import 'enums.dart';

class UserIdentity {
  const UserIdentity({
    required this.id,
    required this.email,
    required this.name,
    required this.onboardingCompleted,
    this.role = UserRole.user,
    this.avatar,
  });

  final String id;
  final String email;
  final String name;
  final String? avatar;
  final UserRole role;
  final bool onboardingCompleted;

  factory UserIdentity.fromJson(Map<String, dynamic> json) => UserIdentity(
    id: json['id'] as String,
    email: json['email'] as String,
    name: json['name'] as String,
    avatar: json['avatar'] as String?,
    role: UserRole.fromApi(json['role'] as String?),
    onboardingCompleted: json['onboardingCompleted'] == true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'name': name,
    'avatar': avatar,
    'role': role.api,
    'onboardingCompleted': onboardingCompleted,
  };
}

class AuthResult {
  const AuthResult({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresInSeconds,
    required this.tokenType,
    this.user,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresInSeconds;
  final String tokenType;
  final UserIdentity? user;

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
    expiresInSeconds: (json['expiresInSeconds'] as num?)?.toInt() ?? 900,
    tokenType: json['tokenType'] as String? ?? 'Bearer',
    user:
        json['user'] is Map
            ? UserIdentity.fromJson(json['user'] as Map<String, dynamic>)
            : null,
  );
}
