import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/realtime/realtime_socket_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_cubit.dart';
import 'features/auth/bloc/auth_cubit.dart';
import 'features/call/cubit/call_cubit.dart';
import 'features/live/cubit/live_cubit.dart';
import 'features/matchmaking/cubit/matchmaking_cubit.dart';

class PeerUpApp extends StatefulWidget {
  const PeerUpApp({
    super.key,
    required this.router,
    required this.authCubit,
    required this.themeCubit,
  });

  final GoRouter router;
  final AuthCubit authCubit;
  final ThemeCubit themeCubit;

  @override
  State<PeerUpApp> createState() => _PeerUpAppState();
}

class _PeerUpAppState extends State<PeerUpApp> {
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: widget.authCubit),
        BlocProvider.value(value: widget.themeCubit),
      ],
      child: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          debugPrint('AUTH CHANGED: ${state.status}');
          if (state.status == AuthStatus.loggedOut) 
          {
           
            context.read<RealtimeSocketService>().disconnect();
            context.read<LiveCubit>().reset();
            context.read<MatchmakingCubit>().reset();
            context.read<CallCubit>().reset();
          }
          widget.router.refresh();
        },
        child: BlocBuilder<ThemeCubit, AppThemeMode>(
          builder: (context, mode) {
            return MaterialApp.router(
              title: 'PeerUp',
              debugShowCheckedModeBanner: false,
              theme: buildLightTheme(),
              darkTheme: buildDarkTheme(),
              themeMode:
                  mode == AppThemeMode.dark ? ThemeMode.dark : ThemeMode.light,
              routerConfig: widget.router,
            );
          },
        ),
      ),
    );
  }
}
