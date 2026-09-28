enum UserRole {
  user('USER'),
  moderator('MODERATOR'),
  admin('ADMIN');

  const UserRole(this.api);
  final String api;

  static UserRole fromApi(String? v) => UserRole.values.firstWhere(
    (e) => e.api == v,
    orElse: () => UserRole.user,
  );
}

enum UserStatus {
  available('AVAILABLE'),
  searching('SEARCHING'),
  matched('MATCHED'),
  connecting('CONNECTING'),
  inCall('IN_CALL'),
  offline('OFFLINE');

  const UserStatus(this.api);
  final String api;

  static UserStatus fromApi(String? v) => UserStatus.values.firstWhere(
    (e) => e.api == v,
    orElse: () => UserStatus.offline,
  );
}

enum Gender {
  male('MALE', 'Male'),
  female('FEMALE', 'Female'),
  nonBinary('NON_BINARY', 'Non-binary'),
  preferNotToSay('PREFER_NOT_TO_SAY', 'Prefer not to say');

  const Gender(this.api, this.label);
  final String api;
  final String label;

  static Gender fromApi(String? v) => Gender.values.firstWhere(
    (e) => e.api == v,
    orElse: () => Gender.preferNotToSay,
  );
}

enum EnglishLevel {
  a1('A1'),
  a2('A2'),
  b1('B1'),
  b2('B2'),
  c1('C1'),
  c2('C2');

  const EnglishLevel(this.api);
  final String api;

  static EnglishLevel fromApi(String? v) => EnglishLevel.values.firstWhere(
    (e) => e.api == v,
    orElse: () => EnglishLevel.b1,
  );
}

enum MatchType {
  random('RANDOM', 'Random'),
  similarLevel('SIMILAR_LEVEL', 'Similar level'),
  interview('INTERVIEW', 'Interview prep'),
  business('BUSINESS', 'Business English'),
  casual('CASUAL', 'Casual chat');

  const MatchType(this.api, this.label);
  final String api;
  final String label;

  static MatchType fromApi(String? v) => MatchType.values.firstWhere(
    (e) => e.api == v,
    orElse: () => MatchType.random,
  );
}

enum CallStatus {
  matched('MATCHED'),
  signaling('SIGNALING'),
  connecting('CONNECTING'),
  connected('CONNECTED'),
  ended('ENDED'),
  failed('FAILED'),
  cancelled('CANCELLED');

  const CallStatus(this.api);
  final String api;

  static CallStatus fromApi(String? v) => CallStatus.values.firstWhere(
    (e) => e.api == v,
    orElse: () => CallStatus.matched,
  );
}

enum CallEndReason {
  userHangup('USER_HANGUP'),
  userDisconnected('USER_DISCONNECTED'),
  peerDisconnected('PEER_DISCONNECTED'),
  callTimeout('CALL_TIMEOUT'),
  signalingFailed('SIGNALING_FAILED'),
  matchTimeout('MATCH_TIMEOUT'),
  moderatorNa('MODERATOR_NA'),
  system('SYSTEM');

  const CallEndReason(this.api);
  final String api;

  static CallEndReason fromApi(String? v) => CallEndReason.values.firstWhere(
    (e) => e.api == v,
    orElse: () => CallEndReason.system,
  );
}

enum ReportReason {
  harassment('HARASSMENT', 'Harassment'),
  abusiveLanguage('ABUSIVE_LANGUAGE', 'Abusive language'),
  spam('SPAM', 'Spam'),
  inappropriateBehavior('INAPPROPRIATE_BEHAVIOR', 'Inappropriate behavior'),
  fakeProfile('FAKE_PROFILE', 'Fake profile'),
  other('OTHER', 'Other');

  const ReportReason(this.api, this.label);
  final String api;
  final String label;

  static ReportReason fromApi(String? v) => ReportReason.values.firstWhere(
    (e) => e.api == v,
    orElse: () => ReportReason.other,
  );
}

enum SubscriptionPlan {
  free('FREE', 'Free'),
  premium('PREMIUM', 'Premium');

  const SubscriptionPlan(this.api, this.label);
  final String api;
  final String label;

  static SubscriptionPlan fromApi(String? v) => SubscriptionPlan.values
      .firstWhere((e) => e.api == v, orElse: () => SubscriptionPlan.free);
}

enum SubscriptionStatusEnum {
  active('ACTIVE'),
  inactive('INACTIVE'),
  canceled('CANCELED'),
  pastDue('PAST_DUE');

  const SubscriptionStatusEnum(this.api);
  final String api;

  static SubscriptionStatusEnum fromApi(String? v) =>
      SubscriptionStatusEnum.values.firstWhere(
        (e) => e.api == v,
        orElse: () => SubscriptionStatusEnum.inactive,
      );
}

enum NotificationTypeEnum {
  subscription('SUBSCRIPTION'),
  system('SYSTEM'),
  reminder('REMINDER'),
  streak('STREAK');

  const NotificationTypeEnum(this.api);
  final String api;

  static NotificationTypeEnum fromApi(String? v) => NotificationTypeEnum.values
      .firstWhere((e) => e.api == v, orElse: () => NotificationTypeEnum.system);
}
