import 'enums.dart';

/// A sanitized public summary of a user currently live, as delivered by the
/// server in the LIVE_USERS payload. Never contains credentials or private
/// profile data.
class LiveUser {
  const LiveUser({
    required this.id,
    required this.name,
    required this.interests,
    required this.nativeLanguage,
    required this.learningLanguage,
    this.avatar,
    this.englishLevel = EnglishLevel.b1,
    this.status = UserStatus.available,
  });

  final String id;
  final String name;
  final String? avatar;
  final EnglishLevel englishLevel;
  final String nativeLanguage;
  final String learningLanguage;
  final List<String> interests;
  final UserStatus status;

  factory LiveUser.fromJson(Map<String, dynamic> json) => LiveUser(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    avatar: json['avatar'] as String?,
    englishLevel: EnglishLevel.fromApi(json['englishLevel'] as String?),
    nativeLanguage: json['nativeLanguage'] as String? ?? 'English',
    learningLanguage: json['learningLanguage'] as String? ?? 'English',
    interests: (json['interests'] as List?)?.cast<String>() ?? const [],
    status: UserStatus.fromApi(json['status'] as String?),
  );
}
