import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:peerup/features/ai/ai_repository.dart';
import 'package:peerup/features/ai/bloc/ai_feedback_cubit.dart';
import 'package:peerup/features/auth/bloc/auth_cubit.dart';
import 'package:peerup/features/profile/bloc/public_profile_cubit.dart';
import 'package:peerup/features/profile/profile_repository.dart';
import 'package:peerup/features/tongue/tongue_twister_practice_page.dart';

import '../../features/ai/presentation/ai_chat_screen.dart';
import '../../features/ai/presentation/ai_feedback_screen.dart';
import '../../features/ai/presentation/ai_modes_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/call/call_end_screen.dart';
import '../../features/call/call_page.dart';
import '../../features/chat/bloc/chat_cubit.dart';
import '../../features/chat/chat_repository.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/friends/presentation/friends_screen.dart';
import '../../features/home/presentation/home_shell.dart';
import '../../features/home/presentation/match_home_screen.dart';
import '../../features/searching/searching_page.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../models/friend.dart';
import '../realtime/realtime_socket_service.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/premium/presentation/premium_screen.dart';
import '../../features/premium/subscription_repository.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/public_profile_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/subscription/bloc/subscription_bloc.dart';
import '../../features/subscription/presentation/subscription_screen.dart';
import '../config/app_routes.dart';

class AppRouter {
  AppRouter({required this.authCubit}) {
    router = _buildRouter();
  }

  final AuthCubit authCubit;
  late final GoRouter router;

  GoRouter _buildRouter() {
    return GoRouter(
      initialLocation: AppRoutes.splash,

      redirect: (context, state) {
        final auth = authCubit.state;

        final status = auth.status;
        final location = state.matchedLocation;

        debugPrint('ROUTER => status=$status, location=$location');

        if (status == AuthStatus.unknown) {
          if (location == AppRoutes.splash) {
            return null;
          }

          return AppRoutes.splash;
        }

        if (status == AuthStatus.loggedOut) {
          if (location == AppRoutes.login || location == AppRoutes.register) {
            return null;
          }
          return AppRoutes.login;
        }

        final needsOnboarding = auth.user?.onboardingCompleted != true;

        if (location == AppRoutes.splash ||
            location == AppRoutes.login ||
            location == AppRoutes.register) {
          if (needsOnboarding) {
            return AppRoutes.onboarding;
          }

          return AppRoutes.homeMatch;
        }

        // --------------------------------------------------
        // 4. ONBOARDING ALREADY COMPLETED
        // --------------------------------------------------

        if (location == AppRoutes.onboarding && !needsOnboarding) {
          return AppRoutes.homeMatch;
        }

        // --------------------------------------------------
        // 5. ONBOARDING IS REQUIRED
        // --------------------------------------------------

        if (location.startsWith('/home') && needsOnboarding) {
          return AppRoutes.onboarding;
        }

        return null;
      },

      routes: [
        // --------------------------------------------------
        // SPLASH
        // --------------------------------------------------
        GoRoute(
          path: AppRoutes.splash,
          name: 'splash',
          builder: (context, state) {
            return const SplashScreen();
          },
        ),

        // --------------------------------------------------
        // LOGIN
        // --------------------------------------------------
        GoRoute(
          path: AppRoutes.login,
          name: 'login',
          builder: (context, state) {
            return const LoginScreen();
          },
        ),

        // --------------------------------------------------
        // REGISTER
        // --------------------------------------------------
        GoRoute(
          path: AppRoutes.register,
          name: 'register',
          builder: (context, state) {
            return const RegisterScreen();
          },
        ),

        // --------------------------------------------------
        // ONBOARDING
        // --------------------------------------------------
        GoRoute(
          path: AppRoutes.onboarding,
          name: 'onboarding',
          builder: (context, state) {
            return const OnboardingScreen();
          },
        ),

        // --------------------------------------------------
        // HOME SHELL
        // --------------------------------------------------
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return HomeShell(navigationShell: navigationShell);
          },

          branches: [
            // ------------------------------------------------
            // MATCH
            // ------------------------------------------------
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.homeMatch,
                  name: 'homeMatch',
                  builder: (context, state) {
                    return const MatchHomeScreen();
                  },
                ),
              ],
            ),

            // ------------------------------------------------
            // AI
            // ------------------------------------------------
            // StatefulShellBranch(
            //   routes: [
            //     GoRoute(
            //       path: AppRoutes.homeAi,
            //       name: 'homeAi',
            //       builder: (context, state) {
            //         return const AIModesScreen();
            //       },
            //     ),
            //   ],
            // ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.tongueTwisters,
                  name: 'tongueTwisters',
                  builder: (context, state) {
                    return const TongueTwisterPracticePage();
                  },
                ),
              ],
            ),

            // ------------------------------------------------
            // PROFILE
            // ------------------------------------------------
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.homeProfile,
                  name: 'homeProfile',
                  builder: (context, state) {
                    return const ProfileScreen();
                  },
                ),
              ],
            ),
          ],
        ),

        // --------------------------------------------------
        // SEARCHING
        // --------------------------------------------------
        GoRoute(
          path: AppRoutes.searching,
          name: 'searching',
          builder: (context, state) {
            return const SearchingPage();
          },
        ),

        // --------------------------------------------------
        // CALL
        // --------------------------------------------------
        GoRoute(
          path: AppRoutes.call,
          name: 'call',
          builder: (context, state) {
            return CallPage(callId: state.pathParameters['callId'] ?? '');
          },
        ),

        // --------------------------------------------------
        // CALL END
        // --------------------------------------------------
        GoRoute(
          path: AppRoutes.callEnd,
          name: 'callEnd',
          builder: (context, state) {
            return const CallEndScreen();
          },
        ),

        // --------------------------------------------------
        // PUBLIC PROFILE
        // --------------------------------------------------
        GoRoute(
          path: AppRoutes.publicProfile,
          name: 'publicProfile',
          builder: (context, state) {
            final userId = state.pathParameters['id'] ?? '';
            return BlocProvider(
              create:
                  (_) => PublicProfileCubit(
                    userId: userId,
                    profileRepository: context.read<ProfileRepository>(),
                  ),
              child: PublicProfileScreen(userId: userId),
            );
          },
        ),

        // --------------------------------------------------
        // PREMIUM
        // --------------------------------------------------
        GoRoute(
          path: AppRoutes.premium,
          name: 'premium',
          builder: (context, state) {
            return const PremiumScreen();
          },
        ),

        // --------------------------------------------------
        // SUBSCRIPTION (Razorpay Premium purchase flow)
        // --------------------------------------------------
        GoRoute(
          path: AppRoutes.subscription,
          name: 'subscription',
          builder: (context, state) {
            return BlocProvider(
              create:
                  (_) => SubscriptionBloc(
                    repo: context.read<SubscriptionRepository>(),
                  ),
              child: const SubscriptionScreen(),
            );
          },
        ),

        // --------------------------------------------------
        // NOTIFICATIONS
        // --------------------------------------------------
        GoRoute(
          path: AppRoutes.notifications,
          name: 'notifications',
          builder: (context, state) {
            return const NotificationsScreen();
          },
        ),

        // --------------------------------------------------
        // FRIENDS (Messages)
        // --------------------------------------------------
        GoRoute(
          path: AppRoutes.friends,
          name: 'friends',
          builder: (context, state) {
            return const FriendsScreen();
          },
        ),

        // --------------------------------------------------
        // CHAT (one-to-one with a friend)
        // --------------------------------------------------
        GoRoute(
          path: AppRoutes.chat,
          name: 'chat',
          builder: (context, state) {
            final friendId = state.pathParameters['friendId'] ?? '';
            final friend = state.extra is Friend ? state.extra as Friend : null;
            return BlocProvider(
              create:
                  (_) => ChatCubit(
                    repo: context.read<ChatRepository>(),
                    friendId: friendId,
                    socket: context.read<RealtimeSocketService>(),
                    currentUserId: authCubit.state.user?.id,
                  ),
              child: ChatScreen(friendId: friendId, friend: friend),
            );
          },
        ),

        // --------------------------------------------------
        // SETTINGS
        // --------------------------------------------------
        GoRoute(
          path: AppRoutes.settings,
          name: 'settings',
          builder: (context, state) {
            return const SettingsScreen();
          },
        ),

        // --------------------------------------------------
        // EDIT PROFILE
        // --------------------------------------------------
        GoRoute(
          path: AppRoutes.editProfile,
          name: 'editProfile',
          builder: (context, state) {
            return const EditProfileScreen();
          },
        ),

        // --------------------------------------------------
        // AI CHAT
        // --------------------------------------------------
        GoRoute(
          path: AppRoutes.aiChat,
          name: 'aiChat',
          builder: (context, state) {
            return const AIChatScreen();
          },
        ),

        // --------------------------------------------------
        // AI FEEDBACK
        // --------------------------------------------------
        GoRoute(
          path: AppRoutes.aiFeedback,
          name: 'aiFeedback',
          builder: (context, state) {
            final sessionId = state.pathParameters['sessionId'] ?? '';
            return BlocProvider(
              create:
                  (_) => AIFeedbackCubit(
                    sessionId: sessionId,
                    repo: context.read<AIRepository>(),
                  ),
              child: AIFeedbackScreen(sessionId: sessionId),
            );
          },
        ),
      ],
    );
  }
}
