class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String onboarding = '/onboarding';

  static const String homeMatch = '/home/match';
  static const String homeAi = '/home/ai';
  static const String homeProfile = '/home/profile';

  static const String searching = '/searching';
  static const String call = '/call/:callId';
  static const String callEnd = '/call-end';

  static const String publicProfile = '/profile/:id';
  static const String premium = '/premium';
  static const String notifications = '/notifications';
  static const String settings = '/settings';
  static const String editProfile = '/edit-profile';

  static const String aiChat = '/ai/chat';
  static const String aiFeedback = '/ai/feedback/:sessionId';

  static const String practice = '/practice';
  static const String practiceSession = '/practice/session';
  static const String practiceFeedback = '/practice/feedback/:sessionId';
}
