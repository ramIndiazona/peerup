import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app.dart';
import 'core/auth/auth_repository.dart';
import 'core/auth/auth_service.dart';
import 'core/auth/token_manager.dart';
import 'core/call/call_repository.dart';
import 'core/call/call_service.dart';
import 'core/call/webrtc_service.dart';
import 'core/live/live_presence_repository.dart';
import 'core/live/live_presence_service.dart';
import 'core/matchmaking/matchmaking_repository.dart';
import 'core/matchmaking/matchmaking_service.dart';
import 'core/network/api_client.dart';
import 'core/realtime/realtime_socket_service.dart';
import 'core/router/app_router.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/theme_cubit.dart';
import 'features/ai/ai_repository.dart';
import 'features/ai/bloc/ai_catalog_cubit.dart';
import 'features/ai/bloc/ai_session_cubit.dart';
import 'features/auth/bloc/auth_cubit.dart';
import 'features/call/cubit/call_cubit.dart';
import 'features/live/cubit/live_cubit.dart';
import 'features/matchmaking/cubit/matchmaking_cubit.dart';
import 'features/notifications/bloc/notifications_cubit.dart';
import 'features/notifications/notifications_repository.dart';
import 'features/premium/bloc/premium_cubit.dart';
import 'features/premium/subscription_repository.dart';
import 'features/profile/bloc/profile_cubit.dart';
import 'features/profile/profile_repository.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();


  final tokens = TokenStorage();
  final tokenManager = TokenManager(storage: tokens);
  final apiClient = ApiClient(tokens: tokenManager);
  final realtime = RealtimeSocketService(tokens: tokenManager);
  final webRtc = WebRtcService();

  final authRepository = AuthRepository(apiClient);
  final authService = AuthService(repo: authRepository, tokens: tokenManager);
  final profileRepository = ProfileRepository(apiClient);
  final aiRepository = AIRepository(apiClient);
  final livePresenceRepository = LivePresenceRepository(apiClient);
  final livePresenceService = LivePresenceService(
    socket: realtime,
    repo: livePresenceRepository,
  );
  final matchmakingRepository = MatchmakingRepository(apiClient);
  final matchmakingService = MatchmakingService(
    socket: realtime,
    repo: matchmakingRepository,
    live: livePresenceService,
  );
  final callRepository = CallRepository(apiClient);
  final callService = CallService(
    socket: realtime,
    repo: callRepository,
    webRtc: webRtc,
  );
  final notificationsRepository = NotificationsRepository(apiClient);
  final subscriptionRepository = SubscriptionRepository(apiClient);

  final authCubit = AuthCubit(auth: authService);
  final themeCubit = ThemeCubit();
  final liveCubit = LiveCubit(service: livePresenceService);
  final matchmakingCubit = MatchmakingCubit(service: matchmakingService);
  final callCubit = CallCubit(call: callService);
  final router = AppRouter(authCubit: authCubit).router;

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<ApiClient>.value(value: apiClient),
        RepositoryProvider<TokenStorage>.value(value: tokens),
        RepositoryProvider<TokenManager>.value(value: tokenManager),
        RepositoryProvider<RealtimeSocketService>.value(value: realtime),
        RepositoryProvider<WebRtcService>.value(value: webRtc),
        RepositoryProvider<AuthRepository>.value(value: authRepository),
        RepositoryProvider<AuthService>.value(value: authService),
        RepositoryProvider<ProfileRepository>.value(value: profileRepository),
        RepositoryProvider<AIRepository>.value(value: aiRepository),
        RepositoryProvider<LivePresenceRepository>.value(
          value: livePresenceRepository,
        ),
        RepositoryProvider<LivePresenceService>.value(
          value: livePresenceService,
        ),
        RepositoryProvider<MatchmakingRepository>.value(
          value: matchmakingRepository,
        ),
        RepositoryProvider<MatchmakingService>.value(value: matchmakingService),
        RepositoryProvider<CallRepository>.value(value: callRepository),
        RepositoryProvider<CallService>.value(value: callService),
        RepositoryProvider<NotificationsRepository>.value(
          value: notificationsRepository,
        ),
        RepositoryProvider<SubscriptionRepository>.value(
          value: subscriptionRepository,
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: authCubit),
          BlocProvider.value(value: themeCubit),
          BlocProvider(
            create: (_) => ProfileCubit(profileRepository: profileRepository),
          ),
          BlocProvider<LiveCubit>.value(value: liveCubit),
          BlocProvider<MatchmakingCubit>.value(value: matchmakingCubit),
          BlocProvider<CallCubit>.value(value: callCubit),
          BlocProvider(create: (_) => AISessionCubit(repo: aiRepository)),
          BlocProvider(create: (_) => AICatalogCubit(repo: aiRepository)),
          BlocProvider(
            create: (_) => NotificationsCubit(repo: notificationsRepository),
          ),
          BlocProvider(
            create: (_) => PremiumCubit(repo: subscriptionRepository),
          ),
        ],
        child: PeerUpApp(
          router: router,
          authCubit: authCubit,
          themeCubit: themeCubit,
        ),
      ),
    ),
  );
}
