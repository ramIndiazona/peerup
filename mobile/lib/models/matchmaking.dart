import 'enums.dart';
import 'profile.dart';

class MatchFilters {
  const MatchFilters({
    this.language,
    this.level,
    this.preferredLevel,
    this.interests,
    this.genderPreference,
    this.goal,
    this.matchType,
  });

  final String? language;
  final String? level;
  final String? preferredLevel;
  final List<String>? interests;
  final String? genderPreference;
  final String? goal;
  final String? matchType;

  static MatchFilters fromProfile(UserProfile? user) {
    final p = user?.profile;
    return MatchFilters(
      language:
          (p?.learningLanguage.isNotEmpty ?? false)
              ? p!.learningLanguage
              : 'English',
      level: p?.englishLevel.api,
      interests: (p?.interests ?? const []).isEmpty ? null : p!.interests,
      goal:
          (p?.conversationGoals ?? const []).isEmpty
              ? null
              : p!.conversationGoals.first,
      matchType: 'random',
    );
  }

  Map<String, dynamic> toJson() => {
    if (language != null) 'language': language,
    if (level != null) 'level': level,
    if (preferredLevel != null) 'preferredLevel': preferredLevel,
    if (interests != null && interests!.isNotEmpty) 'interests': interests,
    if (genderPreference != null) 'genderPreference': genderPreference,
    if (goal != null) 'goal': goal,
    if (matchType != null) 'matchType': matchType,
  };

  MatchFilters copyWith({
    String? language,
    String? level,
    String? preferredLevel,
    List<String>? interests,
    String? genderPreference,
    String? goal,
    String? matchType,
  }) => MatchFilters(
    language: language ?? this.language,
    level: level ?? this.level,
    preferredLevel: preferredLevel ?? this.preferredLevel,
    interests: interests ?? this.interests,
    genderPreference: genderPreference ?? this.genderPreference,
    goal: goal ?? this.goal,
    matchType: matchType ?? this.matchType,
  );
}

class MatchStatusResult {
  const MatchStatusResult({
    required this.status,
    required this.searching,
    this.filters,
    this.callId,
    this.role,
    this.peer,
  });

  final UserStatus status;
  final bool searching;
  final Map<String, dynamic>? filters;
  final String? callId;
  final String? role;
  final PublicProfile? peer;

  factory MatchStatusResult.fromJson(Map<String, dynamic> json) =>
      MatchStatusResult(
        status: UserStatus.fromApi(json['status'] as String?),
        searching: json['searching'] == true,
        filters:
            json['filters'] is Map
                ? Map<String, dynamic>.from(json['filters'] as Map)
                : null,
        callId: json['callId'] as String?,
        role: json['role'] as String?,
        peer:
            json['peer'] is Map
                ? PublicProfile.fromJson(
                  Map<String, dynamic>.from(json['peer'] as Map),
                )
                : null,
      );
}
