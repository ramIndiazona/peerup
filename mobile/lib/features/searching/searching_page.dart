// import 'dart:async';

// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:go_router/go_router.dart';

// import '../../core/config/app_routes.dart';
// import '../../core/theme/app_colors.dart';
// import '../../core/widgets/user_avatar.dart';
// import '../../models/matchmaking.dart';
// import '../live/cubit/live_cubit.dart';
// import '../matchmaking/cubit/matchmaking_cubit.dart';
// import '../matchmaking/cubit/matchmaking_state.dart';
// import '../profile/bloc/profile_cubit.dart';

// class SearchingPage extends StatefulWidget {
//   const SearchingPage({super.key});

//   @override
//   State<SearchingPage> createState() => _SearchingPageState();
// }

// class _SearchingPageState extends State<SearchingPage>
//     with WidgetsBindingObserver, SingleTickerProviderStateMixin {
//   Timer? _ticker;
//   int _seconds = 0;
//   bool _navigated = false;
//   final _phaseTexts = [
//     'Looking for you a partner',
//     'Checking levels & goals',
//     'Almost there',
//   ];
//   MatchmakingCubit? _cubit;

//   late final AnimationController _rotationController;

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this);
//     _cubit = context.read<MatchmakingCubit>();
//     _rotationController = AnimationController(
//       vsync: this,
//       duration: const Duration(seconds: 3),
//     )..repeat();
//     _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
//       setState(() => _seconds++);
//     });

//     Future.microtask(() {
//       if (!mounted) return;
//       final state = _cubit!.state;
//       if (state.phase == MatchPhase.idle && state.error != null) {
//         WidgetsBinding.instance.addPostFrameCallback((_) {
//           if (!mounted) return;
//           ScaffoldMessenger.of(
//             context,
//           ).showSnackBar(SnackBar(content: Text(state.error!)));
//           context.pop();
//         });
//         return;
//       }
//       if (state.phase == MatchPhase.idle) {
//         // User reached /searching without an active search (deep link or
//         // app restart). Restore from backend status; do not duplicate.
//         final profile = context.read<ProfileCubit>().state;
//         final user = profile.valueOrNull;
//         unawaited(_cubit!.recover(MatchFilters.fromProfile(user)));
//       }
//     });
//   }

//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//     _ticker?.cancel();
//     _cleanup();
//     super.dispose();
//   }

//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     // App went to background while searching: don't leave a stale
//     // SEARCHING record on the backend.
//     if (state == AppLifecycleState.paused) {
//       if (_cubit?.state.isSearching ?? false) {
//         unawaited(_cubit!.cancel());
//         // Live presence stays on: the heartbeat keeps refreshing the server
//         // TTL, so the user remains live until they leave the app for good.
//       }
//     } else if (state == AppLifecycleState.resumed) {
//       if (_cubit?.state.phase != MatchPhase.searching &&
//           _cubit?.state.phase != MatchPhase.matched) {
//         _cubit?.reset();
//         WidgetsBinding.instance.addPostFrameCallback((_) {
//           if (mounted) context.pop();
//         });
//       }
//     }
//   }

//   Future<void> _cleanup() async {
//     final cubit = _cubit;
//     if (cubit == null) return;
//     // Only cancel when the user is still searching. If we matched and we
//     // are being replaced by the call screen, keep the match state intact.
//     if (cubit.state.isSearching) {
//       await cubit.cancel();
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);

//     return BlocListener<MatchmakingCubit, MatchState>(
//       listener: (context, next) {
//         if (_navigated) return;
//         if (next.phase == MatchPhase.matched && next.match != null) {
//           _navigated = true;
//           context.pushReplacement(
//             AppRoutes.call.replaceFirst(':callId', next.match!.callId),
//           );
//         } else if (next.phase == MatchPhase.idle && next.error != null) {
//           _navigated = true;
//           ScaffoldMessenger.of(
//             context,
//           ).showSnackBar(SnackBar(content: Text(next.error!)));
//           context.pop();
//         }
//       },
//       child: BlocBuilder<MatchmakingCubit, MatchState>(
//         builder: (context, match) {
//           final canceling = match.phase == MatchPhase.starting;

//           return PopScope(
//             canPop: !canceling,
//             onPopInvokedWithResult: (didPop, _) {
//               if (!didPop) return;
//             },
//             child: Scaffold(
//               body: SafeArea(
//                 child: Padding(
//                   padding: const EdgeInsets.all(28),
//                   child: Column(
//                     children: [
//                       const Spacer(flex: 2),
//                       Stack(
//                         alignment: Alignment.center,
//                         children: [
//                           // SizedBox(
//                           //   width: 200,
//                           //   height: 200,
//                           //   child: TweenAnimationBuilder<double>(
//                           //     tween: Tween(begin: 0, end: 1),
//                           //     duration: const Duration(milliseconds: 1200),
//                           //     curve: Curves.easeInOut,
//                           //     builder:
//                           //         (context, value, child) => DecoratedBox(
//                           //           decoration: BoxDecoration(
//                           //             shape: BoxShape.circle,
//                           //             gradient: SweepGradient(
//                           //               startAngle: 0,
//                           //               endAngle: 6.2832 * value,
//                           //               colors: const [
//                           //                 AppColors.primary,
//                           //                 AppColors.accent,
//                           //                 AppColors.primary,
//                           //               ],
//                           //             ),
//                           //           ),
//                           //           child: Padding(
//                           //             padding: const EdgeInsets.all(10),
//                           //             // child: ColoredBox(
//                           //             //   color: theme.scaffoldBackgroundColor,
//                           //             //   child: child,
//                           //             // ),
//                           //           ),
//                           //         ),
//                           //     child: const Center(
//                           //       //  child: CircularProgressIndicator(),
//                           //     ),
//                           //   ),
//                           // ),
//                           SizedBox(
//                             width: 200,
//                             height: 200,
//                             child: AnimatedBuilder(
//                               animation: _rotationController,
//                               builder: (context, child) {
//                                 return DecoratedBox(
//                                   decoration: BoxDecoration(
//                                     shape: BoxShape.circle,
//                                     gradient: SweepGradient(
//                                       transform: GradientRotation(
//                                         _rotationController.value *
//                                             2 *
//                                             3.141592653589793,
//                                       ),
//                                       colors: const [
//                                         AppColors.primary,
//                                         AppColors.accent,
//                                         AppColors.primary,
//                                       ],
//                                     ),
//                                   ),
//                                   child: Padding(
//                                     padding: const EdgeInsets.all(10),
//                                     // child: DecoratedBox(
//                                     //   decoration: BoxDecoration(
//                                     //     shape: BoxShape.circle,
//                                     //     color:
//                                     //         Theme.of(
//                                     //           context,
//                                     //         ).scaffoldBackgroundColor,
//                                     //   ),
//                                     // ),
//                                   ),
//                                 );
//                               },
//                             ),
//                           ),
//                           Center(
//                             child: Column(
//                               mainAxisSize: MainAxisSize.min,
//                               children: [
//                                 Text(
//                                   '${_seconds ~/ 60}:${(_seconds % 60).toString().padLeft(2, '0')}',
//                                   style: theme.textTheme.headlineMedium
//                                       ?.copyWith(
//                                         fontWeight: FontWeight.w800,
//                                         color: Colors.white,
//                                       ),
//                                 ),
//                                 const SizedBox(height: 4),
//                                 Text(
//                                   _phaseTexts[_seconds % _phaseTexts.length],
//                                   style: theme.textTheme.bodySmall?.copyWith(
//                                     color: Colors.white,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ],
//                       ),
//                       const SizedBox(height: 32),
//                       if (match.match != null)
//                         Column(
//                           children: [
//                             UserAvatar(
//                               url: match.match!.peer.avatar,
//                               name: match.match!.peer.name,
//                               radius: 36,
//                             ),
//                             const SizedBox(height: 10),
//                             Text(
//                               'Matched with ${match.match!.peer.name}',
//                               style: theme.textTheme.titleMedium?.copyWith(
//                                 fontWeight: FontWeight.w700,
//                               ),
//                             ),
//                           ],
//                         )
//                       else ...[
//                         Text(
//                           'Searching with ${context.watch<LiveCubit>().state.otherCount} people live now',
//                           style: theme.textTheme.bodyMedium?.copyWith(
//                             color: theme.colorScheme.outline,
//                           ),
//                         ),
//                         const SizedBox(height: 4),
//                         Text(
//                           'Levels, interests and goals are matched for better conversations.',
//                           textAlign: TextAlign.center,
//                           style: theme.textTheme.bodySmall?.copyWith(
//                             color: theme.colorScheme.outline,
//                           ),
//                         ),
//                       ],
//                       const Spacer(flex: 2),
//                       OutlinedButton.icon(
//                         onPressed:
//                             canceling
//                                 ? null
//                                 : () {
//                                   _cubit?.cancel();
//                                   context.pop();
//                                 },
//                         icon: const Icon(Icons.close_rounded),
//                         label: const Text('Cancel search'),
//                         style: OutlinedButton.styleFrom(
//                           foregroundColor: AppColors.danger,
//                         ),
//                       ),
//                       const SizedBox(height: 16),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }
// }

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
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  Timer? _ticker;
  int _seconds = 0;
  bool _navigated = false;

  final List<String> _phaseTexts = const [
    'Looking for a partner',
    'Checking levels & goals',
    'Almost there',
  ];

  MatchmakingCubit? _cubit;
  late final AnimationController _rotationController;

  static const Color _background = Color(0xFF0B1020);
  static const Color _surface = Color(0xFF151B30);
  static const Color _primary = Color(0xFF9B8CFF);
  static const Color _mainText = Color(0xFFF5F6FF);
  static const Color _secondaryText = Color(0xFF9AA5C4);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cubit = context.read<MatchmakingCubit>();

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
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
        // Restore backend status if the user entered this page without
        // an active search. Do not create a duplicate search.
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
    _rotationController.dispose();
    _cleanup();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      if (_cubit?.state.isSearching ?? false) {
        unawaited(_cubit!.cancel());
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
    // Keep the match state if this page is replaced by the call screen.
    if (cubit.state.isSearching) await cubit.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final theme = baseTheme.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _background,
      colorScheme: baseTheme.colorScheme.copyWith(
        brightness: Brightness.dark,
        primary: _primary,
        surface: _surface,
        outline: _secondaryText,
      ),
      textTheme: baseTheme.textTheme.apply(
        bodyColor: _mainText,
        displayColor: _mainText,
      ),
    );

    return Theme(
      data: theme,
      child: BlocListener<MatchmakingCubit, MatchState>(
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
                backgroundColor: _background,
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
                              child: AnimatedBuilder(
                                animation: _rotationController,
                                builder: (context, child) {
                                  return DecoratedBox(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: SweepGradient(
                                        transform: GradientRotation(
                                          _rotationController.value *
                                              2 *
                                              3.141592653589793,
                                        ),
                                        colors: [
                                          _primary,
                                          _primary.withValues(alpha: 0.35),
                                          _primary,
                                        ],
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      // child: DecoratedBox(
                                      //   decoration: const BoxDecoration(
                                      //     shape: BoxShape.circle,
                                      //     color: _background,
                                      //   ),
                                      //   child: const SizedBox.expand(),
                                      // ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${_seconds ~/ 60}:${(_seconds % 60).toString().padLeft(2, '0')}',
                                    style: theme.textTheme.headlineMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: _mainText,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Waiting time',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: _secondaryText,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _phaseTexts[_seconds % _phaseTexts.length],
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: _secondaryText,
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
                                  color: _mainText,
                                ),
                              ),
                            ],
                          )
                        else ...[
                          Text(
                            'Searching with ${context.watch<LiveCubit>().state.otherCount} people live now',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: _secondaryText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Levels, interests and goals are matched for better conversations.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: _secondaryText,
                            ),
                          ),
                        ],
                        const Spacer(flex: 2),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
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
                              side: BorderSide(
                                color: AppColors.danger.withValues(alpha: 0.65),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
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
      ),
    );
  }
}
