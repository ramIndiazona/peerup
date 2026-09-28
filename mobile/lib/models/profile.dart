import 'enums.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.role,
    required this.status,
    required this.isBanned,
    required this.profile,
    required this.subscriptionPlan,
    this.phone,
    this.createdAt,
  });

  final String id;
  final String email;
  final String? phone;
  final UserRole role;
  final UserStatus status;
  final bool isBanned;
  final DateTime? createdAt;
  final ProfileDetails profile;
  final SubscriptionPlan subscriptionPlan;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    email: json['email'] as String,
    phone: json['phone'] as String?,
    role: UserRole.fromApi(json['role'] as String?),
    status: UserStatus.fromApi(json['status'] as String?),
    isBanned: json['isBanned'] == true,
    createdAt: _dt(json['createdAt']),
    profile: ProfileDetails.fromJson(
      ((json['profile'] as Map?) ?? const {}).cast<String, dynamic>(),
    ),
    subscriptionPlan: SubscriptionPlan.fromApi(json['subscription'] as String?),
  );

  static DateTime? _dt(dynamic v) => v is String ? DateTime.tryParse(v) : null;
}

class ProfileDetails {
  const ProfileDetails({
    this.id,
    this.name = '',
    this.avatar,
    this.gender = Gender.preferNotToSay,
    this.dateOfBirth,
    this.country,
    this.nativeLanguage = 'English',
    this.learningLanguage = 'English',
    this.englishLevel = EnglishLevel.b1,
    this.bio,
    this.conversationGoals = const [],
    this.interests = const [],
    this.showAge = false,
    this.showGender = true,
    this.onboardingCompleted = false,
  });

  final String? id;
  final String name;
  final String? avatar;
  final Gender gender;
  final DateTime? dateOfBirth;
  final String? country;
  final String nativeLanguage;
  final String learningLanguage;
  final EnglishLevel englishLevel;
  final String? bio;
  final List<String> conversationGoals;
  final List<String> interests;
  final bool showAge;
  final bool showGender;
  final bool onboardingCompleted;

  factory ProfileDetails.fromJson(Map<String, dynamic> json) => ProfileDetails(
    id: json['id'] as String?,
    name: json['name'] as String? ?? '',
    avatar: json['avatar'] as String?,
    gender: Gender.fromApi(json['gender'] as String?),
    dateOfBirth:
        json['dateOfBirth'] is String
            ? DateTime.tryParse(json['dateOfBirth'] as String)
            : null,
    country: json['country'] as String?,
    nativeLanguage: json['nativeLanguage'] as String? ?? 'English',
    learningLanguage: json['learningLanguage'] as String? ?? 'English',
    englishLevel: EnglishLevel.fromApi(json['englishLevel'] as String?),
    bio: json['bio'] as String?,
    conversationGoals:
        (json['conversationGoals'] as List?)?.cast<String>() ?? const [],
    interests: (json['interests'] as List?)?.cast<String>() ?? const [],
    showAge: json['showAge'] == true,
    showGender: json['showGender'] != false,
    onboardingCompleted: json['onboardingCompleted'] == true,
  );

  int? get age =>
      dateOfBirth == null
          ? null
          : DateTime.now().difference(dateOfBirth!).inDays ~/ 365;

  String? get dateOfBirthParam =>
      dateOfBirth?.toIso8601String().split('T').first;

  ProfileDetails copyWith({
    String? name,
    String? avatar,
    Gender? gender,
    DateTime? dateOfBirth,
    String? country,
    String? nativeLanguage,
    String? learningLanguage,
    EnglishLevel? englishLevel,
    String? bio,
    List<String>? conversationGoals,
    List<String>? interests,
    bool? showAge,
    bool? showGender,
    bool? onboardingCompleted,
  }) {
    return ProfileDetails(
      id: id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      country: country ?? this.country,
      nativeLanguage: nativeLanguage ?? this.nativeLanguage,
      learningLanguage: learningLanguage ?? this.learningLanguage,
      englishLevel: englishLevel ?? this.englishLevel,
      bio: bio ?? this.bio,
      conversationGoals: conversationGoals ?? this.conversationGoals,
      interests: interests ?? this.interests,
      showAge: showAge ?? this.showAge,
      showGender: showGender ?? this.showGender,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }
}

class PublicProfile {
  const PublicProfile({
    required this.id,
    required this.name,
    required this.interests,
    required this.conversationGoals,
    this.avatar,
    this.englishLevel = EnglishLevel.b1,
    this.nativeLanguage = 'English',
    this.country,
    this.bio,
    this.gender,
    this.yearsOld,
  });

  final String id;
  final String name;
  final String? avatar;
  final EnglishLevel englishLevel;
  final String nativeLanguage;
  final String? country;
  final String? bio;
  final Gender? gender;
  final int? yearsOld;
  final List<String> interests;
  final List<String> conversationGoals;

  factory PublicProfile.fromJson(Map<String, dynamic> json) => PublicProfile(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    avatar: json['avatar'] as String?,
    englishLevel: EnglishLevel.fromApi(json['englishLevel'] as String?),
    nativeLanguage: json['nativeLanguage'] as String? ?? 'English',
    country: json['country'] as String?,
    bio: json['bio'] as String?,
    gender: Gender.fromApi(json['gender'] as String?),
    yearsOld: (json['yearsOld'] as num?)?.toInt(),
    interests: (json['interests'] as List?)?.cast<String>() ?? const [],
    conversationGoals:
        (json['conversationGoals'] as List?)?.cast<String>() ?? const [],
  );
}

class Interest {
  const Interest({
    required this.id,
    required this.name,
    this.category = 'general',
  });

  final String id;
  final String name;
  final String category;

  factory Interest.fromJson(Map<String, dynamic> json) => Interest(
    id: json['id'] as String,
    name: json['name'] as String,
    category: json['category'] as String? ?? 'general',
  );
}
