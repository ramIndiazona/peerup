import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/user_avatar.dart';
import '../../models/matchmaking.dart';
import '../live/cubit/live_cubit.dart';
import '../matchmaking/cubit/matchmaking_cubit.dart';
import '../matchmaking/cubit/matchmaking_state.dart';
import '../profile/bloc/profile_cubit.dart';

class SearchingPage extends StatefulWidget {
  const SearchingPage({super.key});

  @override
  State<SearchingPage> createState() => _SearchingPageState();
}

class _SearchingPageState extends State<SearchingPage>
    with WidgetsBindingObserver {
  Timer? _ticker;
  int _seconds = 0;
  bool _navigated = false;
  final _phaseTexts = [
    'Looking for you a partner',
    'Checking levels & goals',
    'Almost there',
  ];
  MatchmakingCubit? _cubit;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cubit = context.read<MatchmakingCubit>();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _seconds++);
    });

    Future.microtask(() {
      if (!mounted) return;
      final state = _cubit!.state;
      if (state.phase == MatchPhase.idle && state.error != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.error!)));
          context.pop();
        });
        return;
      }
      if (state.phase == MatchPhase.idle) {
        // User reached /searching without an active search (deep link or
        // app restart). Restore from backend status; do not duplicate.
        final profile = context.read<ProfileCubit>().state;
        final user = profile.valueOrNull;
        unawaited(_cubit!.recover(MatchFilters.fromProfile(user)));
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _cleanup();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App went to background while searching: don't leave a stale
    // SEARCHING record on the backend.
    if (state == AppLifecycleState.paused) {
      if (_cubit?.state.isSearching ?? false) {
        unawaited(_cubit!.cancel());
        // Live presence stays on: the heartbeat keeps refreshing the server
        // TTL, so the user remains live until they leave the app for good.
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_cubit?.state.phase != MatchPhase.searching &&
          _cubit?.state.phase != MatchPhase.matched) {
        _cubit?.reset();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.pop();
        });
      }
    }
  }

  Future<void> _cleanup() async {
    final cubit = _cubit;
    if (cubit == null) return;
    // Only cancel when the user is still searching. If we matched and we
    // are being replaced by the call screen, keep the match state intact.
    if (cubit.state.isSearching) {
      await cubit.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocListener<MatchmakingCubit, MatchState>(
      listener: (context, next) {
        if (_navigated) return;
        if (next.phase == MatchPhase.matched && next.match != null) {
          _navigated = true;
          context.pushReplacement(
            AppRoutes.call.replaceFirst(':callId', next.match!.callId),
          );
        } else if (next.phase == MatchPhase.idle && next.error != null) {
          _navigated = true;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(next.error!)));
          context.pop();
        }
      },
      child: BlocBuilder<MatchmakingCubit, MatchState>(
        builder: (context, match) {
          final canceling = match.phase == MatchPhase.starting;

          return PopScope(
            canPop: !canceling,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) return;
            },
            child: Scaffold(
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      const Spacer(flex: 2),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 200,
                            height: 200,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: 1),
                              duration: const Duration(milliseconds: 1200),
                              curve: Curves.easeInOut,
                              builder:
                                  (context, value, child) => DecoratedBox(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: SweepGradient(
                                        startAngle: 0,
                                        endAngle: 6.2832 * value,
                                        colors: const [
                                          AppColors.primary,
                                          AppColors.accent,
                                          AppColors.primary,
                                        ],
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: ColoredBox(
                                        color: theme.scaffoldBackgroundColor,
                                        child: child,
                                      ),
                                    ),
                                  ),
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                          ),
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${_seconds ~/ 60}:${(_seconds % 60).toString().padLeft(2, '0')}',
                                  style: theme.textTheme.headlineMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _phaseTexts[_seconds % _phaseTexts.length],
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      if (match.match != null)
                        Column(
                          children: [
                            UserAvatar(
                              url: match.match!.peer.avatar,
                              name: match.match!.peer.name,
                              radius: 36,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Matched with ${match.match!.peer.name}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        )
                      else ...[
                        Text(
                          'Searching with ${context.watch<LiveCubit>().state.otherCount} people live now',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Levels, interests and goals are matched for better conversations.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                      const Spacer(flex: 2),
                      OutlinedButton.icon(
                        onPressed:
                            canceling
                                ? null
                                : () {
                                  _cubit?.cancel();
                                  context.pop();
                                },
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Cancel search'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
