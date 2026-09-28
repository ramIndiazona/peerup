class APIURL {
  APIURL._();

  static const String authRegister = 'auth/register';
  static const String authLogin = 'auth/login';
  static const String authLogout = 'auth/logout';
  static const String authRefresh = 'auth/refresh';

  static const String usersMe = 'users/me';
  static const String usersInterests = 'users/interests';
  static String userPublic(String userId) => 'users/$userId';

  static const String avatarUpload = 'storage/avatar';

  static String blockUser(String userId) => 'blocks/$userId';
  static const String listBlocks = 'blocks';
  static String reportUser(String userId) => 'blocks/$userId/report';

  static const String matchmakingStart = 'matchmaking/start';
  static const String matchmakingCancel = 'matchmaking/cancel';
  static const String matchmakingStatus = 'matchmaking/status';

  static const String liveStart = 'live/start';
  static const String liveStop = 'live/stop';
  static const String liveCount = 'live/count';

  static const String notificationsList = 'notifications';
  static String notificationMarkRead(String id) => 'notifications/$id/read';
  static const String notificationsDeviceToken = 'notifications/device-token';

  static const String subscriptionsMe = 'subscriptions/me';
  static const String subscriptionsUsage = 'subscriptions/usage';
  static const String subscriptionsPurchase = 'subscriptions/purchase';
  static const String subscriptionsCancel = 'subscriptions/cancel';

  static String callDetails(String callId) => 'calls/$callId';
  static String callEnd(String callId) => 'calls/$callId/end';
  static String callReport(String callId) => 'calls/$callId/report';

  static const String aiCharacters = 'ai/characters';
  static const String aiScenarios = 'ai/scenarios';
  static const String aiSessions = 'ai/sessions';
  static String aiSessionMessage(String sessionId) =>
      'ai/sessions/$sessionId/message';
  static String aiSessionEnd(String sessionId) => 'ai/sessions/$sessionId/end';
  static String aiSessionFeedback(String sessionId) =>
      'ai/sessions/$sessionId/feedback';
}
