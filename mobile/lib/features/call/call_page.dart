// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:go_router/go_router.dart';

// import '../../core/config/app_routes.dart';
// import '../../core/theme/app_colors.dart';
// import '../../core/widgets/user_avatar.dart';
// import '../matchmaking/cubit/matchmaking_cubit.dart';
// import 'cubit/call_cubit.dart';
// import 'cubit/call_state.dart';

// class CallPage extends StatefulWidget {
//   const CallPage({super.key, required this.callId});

//   final String callId;

//   @override
//   State<CallPage> createState() => _CallPageState();
// }

// class _CallPageState extends State<CallPage> {
//   bool _started = false;
//   CallCubit? _callCubit;
//   MatchmakingCubit? _matchCubit;

//   @override
//   void initState() {
//     super.initState();
//     _callCubit = context.read<CallCubit>();
//     _matchCubit = context.read<MatchmakingCubit>();
//     Future.microtask(_ensureStarted);
//   }

//   Future<void> _ensureStarted() async {
//     if (_started) return;
//     _started = true;
//     final match = _matchCubit?.state.match;
//     if (match != null && match.callId == widget.callId) {
//       await _callCubit?.start(
//         callId: widget.callId,
//         role: match.role,
//         peer: match.peer,
//       );
//     } else {
//       final session = _callCubit?.state;
//       if (session?.phase == CallPhase.connecting) {
//         _callCubit?.reset();
//       }
//       _splashToEnd();
//     }
//   }

//   @override
//   void dispose() {
//     _callCubit?.reset();
//     super.dispose();
//   }

//   void _splashToEnd() {
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (mounted) context.pushReplacement(AppRoutes.callEnd);
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return BlocListener<CallCubit, CallState>(
//       listener: (context, call) {
//         if (call.phase == CallPhase.ended || call.phase == CallPhase.failed) {
//           context.pushReplacement(AppRoutes.callEnd);
//         }
//       },
//       child: BlocBuilder<CallCubit, CallState>(
//         builder: (context, call) {
//           final match = context.read<MatchmakingCubit>().state.match;
//           final peerName = match?.peer.name ?? 'Partner';

//           return Scaffold(
//             body: Container(
//               decoration: const BoxDecoration(
//                 gradient: LinearGradient(
//                   begin: Alignment.topCenter,
//                   end: Alignment.bottomCenter,
//                   colors: [AppColors.bgDark, Color(0xFF24243A)],
//                 ),
//               ),
//               child: SafeArea(
//                 child: Padding(
//                   padding: const EdgeInsets.all(28),
//                   child: Column(
//                     children: [
//                       Text(
//                         call.phase == CallPhase.connected
//                             ? 'Connected'
//                             : call.phase == CallPhase.reconnecting
//                             ? 'Reconnecting...'
//                             : 'Connecting…',
//                         style: TextStyle(
//                           color: Colors.white.withValues(alpha: 0.7),
//                           fontSize: 13,
//                           fontWeight: FontWeight.w600,
//                           letterSpacing: 0.5,
//                         ),
//                       ),
//                       const Spacer(),
//                       UserAvatar(
//                         url: match?.peer.avatar,
//                         name: peerName,
//                         radius: 52,
//                       ),
//                       const SizedBox(height: 16),
//                       Text(
//                         peerName,
//                         style: const TextStyle(
//                           color: Colors.white,
//                           fontSize: 24,
//                           fontWeight: FontWeight.w800,
//                         ),
//                       ),
//                       const SizedBox(height: 8),
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           if (call.phase != CallPhase.connected) ...[
//                             const SizedBox(
//                               width: 14,
//                               height: 14,
//                               child: CircularProgressIndicator(
//                                 color: Colors.white70,
//                                 strokeWidth: 2,
//                               ),
//                             ),
//                             const SizedBox(width: 8),
//                           ],
//                           Text(
//                             _format(call.elapsedSeconds),
//                             style: TextStyle(
//                               color: Colors.white.withValues(alpha: 0.85),
//                               fontSize: 18,
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                         ],
//                       ),
//                       if (call.phase == CallPhase.connecting)
//                         Padding(
//                           padding: const EdgeInsets.only(top: 8),
//                           child: Text(
//                             'Waiting for the peer to answer…',
//                             textAlign: TextAlign.center,
//                             style: TextStyle(
//                               color: Colors.white.withValues(alpha: 0.6),
//                               fontSize: 13,
//                             ),
//                           ),
//                         ),
//                       const Spacer(),
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           _ActionButton(
//                             icon:
//                                 call.muted
//                                     ? Icons.mic_off_rounded
//                                     : Icons.mic_rounded,
//                             color: call.muted ? Colors.white : Colors.white24,
//                             iconColor:
//                                 call.muted ? Colors.black87 : Colors.white,
//                             // The local track stays live while recovering,
//                             // so mute keeps working during a reconnection.
//                             onTap:
//                                 call.phase == CallPhase.connecting
//                                     ? null
//                                     : () =>
//                                         context.read<CallCubit>().toggleMute(),
//                           ),
//                           const SizedBox(width: 32),
//                           _ActionButton(
//                             icon: Icons.call_end_rounded,
//                             color: AppColors.danger,
//                             iconColor: Colors.white,
//                             onTap: () => context.read<CallCubit>().hangUp(),
//                           ),
//                         ],
//                       ),
//                       const SizedBox(height: 24),

//                       const Spacer(),

//                       if (call.phase == CallPhase.connected) ...[
//                         _CallDurationProgress(
//                           elapsedSeconds: call.elapsedSeconds,
//                         ),
//                         const SizedBox(height: 28),
//                       ],

//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           _ActionButton(
//                             icon:
//                                 call.muted
//                                     ? Icons.mic_off_rounded
//                                     : Icons.mic_rounded,
//                             color: call.muted ? Colors.white : Colors.white24,
//                             iconColor:
//                                 call.muted ? Colors.black87 : Colors.white,
//                             onTap:
//                                 call.phase == CallPhase.connecting
//                                     ? null
//                                     : () =>
//                                         context.read<CallCubit>().toggleMute(),
//                           ),
//                           const SizedBox(width: 32),
//                           _ActionButton(
//                             icon: Icons.call_end_rounded,
//                             color: AppColors.danger,
//                             iconColor: Colors.white,
//                             onTap: () => context.read<CallCubit>().hangUp(),
//                           ),
//                         ],
//                       ),
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

//   String _format(int seconds) {
//     final m = (seconds ~/ 60).toString().padLeft(2, '0');
//     final s = (seconds % 60).toString().padLeft(2, '0');
//     return '$m:$s';
//   }
// }

// class _ActionButton extends StatelessWidget {
//   const _ActionButton({
//     required this.icon,
//     required this.color,
//     required this.iconColor,
//     this.onTap,
//   });

//   final IconData icon;
//   final Color color;
//   final Color iconColor;
//   final VoidCallback? onTap;

//   @override
//   Widget build(BuildContext context) {
//     return InkWell(
//       customBorder: const CircleBorder(),
//       onTap: onTap,
//       child: Ink(
//         width: 68,
//         height: 68,
//         decoration: BoxDecoration(color: color, shape: BoxShape.circle),
//         child: Icon(icon, color: iconColor, size: 30),
//       ),
//     );
//   }
// }

// class _CallDurationProgress extends StatelessWidget {
//   const _CallDurationProgress({required this.elapsedSeconds});

//   final int elapsedSeconds;

//   static const int maxDisplaySeconds = 30 * 60;

//   @override
//   Widget build(BuildContext context) {
//     final progress = (elapsedSeconds / maxDisplaySeconds).clamp(0.0, 1.0);

//     return Column(
//       children: [
//         SizedBox(
//           height: 28,
//           child: Stack(
//             alignment: Alignment.center,
//             children: [
//               Positioned(
//                 left: 0,
//                 right: 0,
//                 child: Container(
//                   height: 5,
//                   decoration: BoxDecoration(
//                     color: Colors.white.withValues(alpha: 0.12),
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                 ),
//               ),

//               Positioned(
//                 left: 0,
//                 right: 0,
//                 child: FractionallySizedBox(
//                   alignment: Alignment.centerLeft,
//                   widthFactor: progress,
//                   child: Container(
//                     height: 5,
//                     decoration: BoxDecoration(
//                       color: AppColors.primary,
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                   ),
//                 ),
//               ),

//               Align(
//                 alignment: Alignment.centerLeft,
//                 child: Transform.translate(
//                   offset: Offset(progress * 0, 0),
//                   child: Container(
//                     width: 12,
//                     height: 12,
//                     decoration: BoxDecoration(
//                       color: AppColors.primary,
//                       shape: BoxShape.circle,
//                       border: Border.all(color: Colors.white, width: 2),
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),

//         const SizedBox(height: 2),

//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             _Milestone(
//               value: '1',
//               label: '2 mins',
//               active: elapsedSeconds >= 120,
//             ),
//             _Milestone(
//               value: '5',
//               label: '5 mins',
//               active: elapsedSeconds >= 300,
//             ),
//             _Milestone(
//               value: '30',
//               label: '15 mins',
//               active: elapsedSeconds >= 900,
//             ),
//             _Milestone(
//               value: '60',
//               label: '30 mins',
//               active: elapsedSeconds >= 1800,
//             ),
//           ],
//         ),

//         const SizedBox(height: 18),

//         Text(
//           '${_format(elapsedSeconds)} / Unlimited',
//           style: const TextStyle(
//             color: Colors.white,
//             fontSize: 22,
//             fontWeight: FontWeight.w700,
//           ),
//         ),
//       ],
//     );
//   }

//   static String _format(int seconds) {
//     final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
//     final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');

//     return '$minutes:$remainingSeconds';
//   }
// }

// class _Milestone extends StatelessWidget {
//   const _Milestone({
//     required this.value,
//     required this.label,
//     required this.active,
//   });

//   final String value;
//   final String label;
//   final bool active;

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text(
//               value,
//               style: TextStyle(
//                 color:
//                     active
//                         ? Colors.white
//                         : Colors.white.withValues(alpha: 0.75),
//                 fontSize: 14,
//                 fontWeight: FontWeight.w700,
//               ),
//             ),
//             const SizedBox(width: 3),
//             Icon(
//               Icons.emoji_events_rounded,
//               size: 15,
//               color:
//                   active ? Colors.amber : Colors.white.withValues(alpha: 0.45),
//             ),
//           ],
//         ),
//         const SizedBox(height: 4),
//         Text(
//           label,
//           style: TextStyle(
//             color: Colors.white.withValues(alpha: 0.75),
//             fontSize: 11,
//             fontWeight: FontWeight.w500,
//           ),
//         ),
//       ],
//     );
//   }
// }
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/user_avatar.dart';
import '../matchmaking/cubit/matchmaking_cubit.dart';
import 'cubit/call_cubit.dart';
import 'cubit/call_state.dart';

class CallPage extends StatefulWidget {
  const CallPage({super.key, required this.callId});

  final String callId;

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  bool _started = false;

  CallCubit? _callCubit;
  MatchmakingCubit? _matchCubit;

  @override
  void initState() {
    super.initState();

    _callCubit = context.read<CallCubit>();
    _matchCubit = context.read<MatchmakingCubit>();

    Future.microtask(_ensureStarted);
  }

  Future<void> _ensureStarted() async {
    if (_started) return;

    _started = true;

    final match = _matchCubit?.state.match;

    if (match != null && match.callId == widget.callId) {
      await _callCubit?.start(
        callId: widget.callId,
        role: match.role,
        peer: match.peer,
      );
    } else {
      final session = _callCubit?.state;

      if (session?.phase == CallPhase.connecting) {
        _callCubit?.reset();
      }

      _splashToEnd();
    }
  }

  @override
  void dispose() {
    _callCubit?.reset();
    super.dispose();
  }

  void _splashToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.pushReplacement(AppRoutes.callEnd);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CallCubit, CallState>(
      listener: (context, call) {
        if (call.phase == CallPhase.ended || call.phase == CallPhase.failed) {
          context.pushReplacement(AppRoutes.callEnd);
        }
      },
      child: BlocBuilder<CallCubit, CallState>(
        builder: (context, call) {
          final match = context.read<MatchmakingCubit>().state.match;

          final peerName = match?.peer.name ?? 'Partner';
          final bio = match?.peer.bio ?? 'Partner';

          return Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,

                      decoration: const BoxDecoration(
                        // gradient: LinearGradient(
                        //   begin: Alignment.topCenter,
                        //   end: Alignment.bottomCenter,
                        //   colors: [AppColors.bgDark, Color(0xFF24243A)],
                        // ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
                        child: Column(
                          children: [
                            Text(
                              call.phase == CallPhase.connected
                                  ? 'Connected'
                                  : call.phase == CallPhase.reconnecting
                                  ? 'Reconnecting...'
                                  : 'Connecting…',
                              style: TextStyle(
                                color: Colors.black.withValues(alpha: 0.7),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const Spacer(),
                            CallProfile(
                              url: match?.peer.avatar,
                              name: peerName,
                              bio: bio,
                              radius: 52,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              peerName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),

                            if (call.phase != CallPhase.connected)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      color: Colors.white70,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _format(call.elapsedSeconds),
                                    style: TextStyle(
                                      color: Colors.black.withValues(
                                        alpha: 0.85,
                                      ),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),

                            if (call.phase == CallPhase.connecting)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Waiting for the peer to answer…',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 13,
                                  ),
                                ),
                              ),

                            const Spacer(),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ==================================================
                  // BOTTOM DURATION PANEL
                  // ==================================================
                  if (call.phase == CallPhase.connected)
                    Container(
                      width: double.infinity,
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(28, 22, 28, 28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _CallDurationProgress(
                            elapsedSeconds: call.elapsedSeconds,
                          ),

                          const SizedBox(height: 28),
                          Text(
                            '${_format(call.elapsedSeconds)} / Unlimited',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 34),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Message
                              _CallCircleButton(
                                size: 40,
                                icon: Icons.chat_rounded,
                                iconColor: const Color(0xFF666666),
                                backgroundColor: Colors.white,
                                borderColor: const Color(0xFF777777),
                                showNotification: false,
                                onTap: () {},
                              ),

                              _CallCircleButton(
                                size: 40,
                                icon: Icons.call_end_rounded,
                                iconColor: Colors.white,
                                backgroundColor: AppColors.danger,
                                onTap: () {
                                  context.read<CallCubit>().hangUp();
                                },
                              ),

                              //
                              _AudioRouteButton(size: 40),
                            ],
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      color: const Color(0xFF24243A),
                      padding: const EdgeInsets.only(top: 12, bottom: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _ActionButton(
                            icon:
                                call.muted
                                    ? Icons.mic_off_rounded
                                    : Icons.mic_rounded,
                            color: call.muted ? Colors.white : Colors.white24,
                            iconColor:
                                call.muted ? Colors.black87 : Colors.white,
                            onTap:
                                call.phase == CallPhase.connecting
                                    ? null
                                    : () {
                                      context.read<CallCubit>().toggleMute();
                                    },
                          ),
                          const SizedBox(width: 32),
                          _ActionButton(
                            icon: Icons.call_end_rounded,
                            color: AppColors.danger,
                            iconColor: Colors.white,
                            onTap: () {
                              context.read<CallCubit>().hangUp();
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _format(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');

    final secs = (seconds % 60).toString().padLeft(2, '0');

    return '$minutes:$secs';
  }
}

class _CallDurationProgress extends StatefulWidget {
  const _CallDurationProgress({required this.elapsedSeconds});

  final int elapsedSeconds;

  @override
  State<_CallDurationProgress> createState() => _CallDurationProgressState();
}

class _CallDurationProgressState extends State<_CallDurationProgress>
    with SingleTickerProviderStateMixin {
  static const int maxSeconds = 30 * 60;

  late final AnimationController _trophyAnimation;

  int _lastCompletedMilestone = 0;
  int _animatingMilestone = -1;

  final List<int> _milestoneSeconds = const [2 * 60, 5 * 60, 15 * 60, 30 * 60];

  final List<String> _numbers = const ['1', '5', '30', '60'];

  final List<String> _times = const ['2mins', '5 mins', '15 mins', '30 mins'];

  @override
  void initState() {
    super.initState();

    _trophyAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _checkMilestone(widget.elapsedSeconds);
  }

  @override
  void didUpdateWidget(covariant _CallDurationProgress oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.elapsedSeconds != widget.elapsedSeconds) {
      _checkMilestone(widget.elapsedSeconds);
    }
  }

  void _checkMilestone(int seconds) {
    int completed = 0;

    for (int i = 0; i < _milestoneSeconds.length; i++) {
      if (seconds >= _milestoneSeconds[i]) {
        completed = i + 1;
      }
    }

    if (completed > _lastCompletedMilestone) {
      _lastCompletedMilestone = completed;

      _playTrophyAnimation(completed - 1);
    }
  }

  Future<void> _playTrophyAnimation(int index) async {
    if (!mounted) return;

    setState(() {
      _animatingMilestone = index;
    });

    await _trophyAnimation.forward(from: 0);

    if (!mounted) return;

    setState(() {
      _animatingMilestone = -1;
    });
  }

  @override
  void dispose() {
    _trophyAnimation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (widget.elapsedSeconds / maxSeconds).clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          height: 45,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;

              // Purple dot position.
              final progressX = width * progress;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 20,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F0F0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  Positioned(
                    left: 0,
                    top: 20,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      width: progressX.clamp(0.0, width),
                      height: 6,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6266D8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  // MOVING PURPLE DOT
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    left: (progressX - 10).clamp(0.0, width - 20),
                    top: 18,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFF6266D8),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),

                  // ==================================================
                  // TROPHY 1
                  // ==================================================
                  _buildMilestone(width: width, index: 0, position: 0.04),

                  // ==================================================
                  // TROPHY 5
                  // ==================================================
                  _buildMilestone(width: width, index: 1, position: 0.34),

                  // ==================================================
                  // TROPHY 30
                  // ==================================================
                  _buildMilestone(width: width, index: 2, position: 0.67),

                  // ==================================================
                  // TROPHY 60
                  // ==================================================
                  _buildMilestone(width: width, index: 3, position: 0.94),
                ],
              );
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _DurationLabel(text: _times[0]),
            _DurationLabel(text: _times[1]),
            _DurationLabel(text: _times[2]),
            _DurationLabel(text: _times[3]),
          ],
        ),
      ],
    );
  }

  Widget _buildMilestone({
    required double width,
    required int index,
    required double position,
  }) {
    final completed = widget.elapsedSeconds >= _milestoneSeconds[index];

    final isAnimating = _animatingMilestone == index;

    final x = width * position;

    return Positioned(
      left: x - 27,
      top: 10,
      child: _TrophyMilestone(
        number: _numbers[index],
        completed: completed,
        animate: isAnimating,
        controller: _trophyAnimation,
      ),
    );
  }
}

// ================================================================
// TROPHY MILESTONE
// ================================================================

class _TrophyMilestone extends StatelessWidget {
  const _TrophyMilestone({
    required this.number,
    required this.completed,
    required this.animate,
    required this.controller,
  });

  final String number;
  final bool completed;
  final bool animate;
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    if (!animate) {
      return _buildContainer(scale: 1, opacity: 1, glow: 0);
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final value = controller.value;

        // ----------------------------------------------------------
        // SCALE
        // ----------------------------------------------------------

        double scale;

        if (value < 0.35) {
          scale = 1 + (value / 0.35) * 0.35;
        } else {
          scale = 1.35 - ((value - 0.35) / 0.65) * 0.35;
        }

        // ----------------------------------------------------------
        // FADE
        // ----------------------------------------------------------

        double opacity;

        if (value < 0.55) {
          opacity = 1;
        } else {
          opacity = 1 - ((value - 0.55) / 0.45);
        }

        // ----------------------------------------------------------
        // GLOW
        // ----------------------------------------------------------

        final glow = (1 - value).clamp(0.0, 1.0);

        return _buildContainer(
          scale: scale,
          opacity: opacity.clamp(0.0, 1.0),
          glow: glow,
        );
      },
    );
  }

  Widget _buildContainer({
    required double scale,
    required double opacity,
    required double glow,
  }) {
    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: 34,
          height: 22,

          // ========================================================
          // WHITE TROPHY CONTAINER
          // This sits directly ON the progress line.
          // ========================================================
          decoration: BoxDecoration(
            color:
                completed
                    ? Color.fromARGB(255, 205, 206, 249)
                    : Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(18),

            boxShadow: [
              if (glow > 0)
                BoxShadow(
                  color: const Color(0xFFFFA726).withValues(alpha: glow * 0.45),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
            ],
          ),

          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Number
                Text(
                  number,
                  style: TextStyle(
                    color: completed ? Colors.black : Colors.black,
                    fontSize: 8,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(width: 4),

                // Trophy
                Icon(
                  Icons.emoji_events_rounded,
                  size: 8,
                  color: const Color(0xFFFFA726),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================
// TIME LABEL
// ================================================================

class _DurationLabel extends StatelessWidget {
  const _DurationLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.black,
        fontSize: 8,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}
// ================================================================
// ANIMATED TROPHY
// ================================================================

class _AnimatedTrophy extends StatelessWidget {
  const _AnimatedTrophy({
    required this.number,
    required this.completed,
    required this.animate,
    required this.controller,
  });

  final String number;
  final bool completed;
  final bool animate;
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    if (!animate) {
      return _normalTrophy();
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final value = controller.value;

        // ----------------------------------------------------------
        // Scale animation
        // 1.0 → 1.45 → 1.0
        // ----------------------------------------------------------
        double scale;

        if (value < 0.35) {
          scale = 1.0 + ((value / 0.35) * 0.45);
        } else {
          scale = 1.45 - (((value - 0.35) / 0.65) * 0.45);
        }

        // ----------------------------------------------------------
        // Fade animation
        // ----------------------------------------------------------
        double opacity;

        if (value < 0.55) {
          opacity = 1.0;
        } else {
          opacity = 1.0 - ((value - 0.55) / 0.45);
        }

        // ----------------------------------------------------------
        // Glow
        // ----------------------------------------------------------
        final glow = (1 - value).clamp(0.0, 1.0);

        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: scale,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xFFFFA726,
                    ).withValues(alpha: glow * 0.55),
                    blurRadius: 10 + (glow * 10),
                    spreadRadius: glow * 2,
                  ),
                ],
              ),
              child: _normalTrophy(),
            ),
          ),
        );
      },
    );
  }

  Widget _normalTrophy() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          number,
          style: const TextStyle(
            color: Color(0xFF555555),
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 3),
        Icon(
          Icons.emoji_events_rounded,
          size: 17,
          color: completed ? const Color(0xFFFFA726) : const Color(0xFFBDBDBD),
        ),
      ],
    );
  }
}

class _CallCircleButton extends StatelessWidget {
  const _CallCircleButton({
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.size = 76,
    this.backgroundColor = Colors.white,
    this.borderColor,
    this.showNotification = false,
  });

  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final Color? borderColor;
  final double size;
  final bool showNotification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
              border:
                  borderColor != null
                      ? Border.all(color: borderColor!, width: 1.5)
                      : null,
            ),
            child: Icon(icon, color: iconColor, size: size * 0.42),
          ),

          if (showNotification)
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                width: 21,
                height: 21,
                decoration: const BoxDecoration(
                  color: Color(0xFFE85B64),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.iconColor,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Ink(
        width: 68,
        height: 68,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: 30),
      ),
    );
  }
}

class _AudioRouteButton extends StatefulWidget {
  const _AudioRouteButton({this.size = 40});

  final double size;

  @override
  State<_AudioRouteButton> createState() => _AudioRouteButtonState();
}

class _AudioRouteButtonState extends State<_AudioRouteButton> {
  Timer? _routeTimer;

  List<MediaDeviceInfo> _audioOutputs = [];

  MediaDeviceInfo? _bluetoothDevice;

  bool _isBluetoothActive = false;

  /// True when user manually selected phone audio.
  bool _userSelectedPhone = false;

  /// Used to detect a newly connected Bluetooth device.
  String? _lastBluetoothDeviceId;

  @override
  void initState() {
    super.initState();

    _refreshAudioRoutes();

    // Check periodically because Bluetooth can connect/disconnect
    // while the call is already running.
    _routeTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _refreshAudioRoutes(),
    );
  }

  @override
  void dispose() {
    _routeTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshAudioRoutes() async {
    try {
      final outputs = await Helper.audiooutputs;

      if (!mounted) return;

      final bluetooth = _findBluetooth(outputs);

      setState(() {
        _audioOutputs = outputs;
        _bluetoothDevice = bluetooth;
      });

      if (bluetooth == null) {
        if (_isBluetoothActive) {
          setState(() {
            _isBluetoothActive = false;
            _lastBluetoothDeviceId = null;
          });
        }

        return;
      }

      final isNewBluetoothDevice = bluetooth.deviceId != _lastBluetoothDeviceId;

      _lastBluetoothDeviceId = bluetooth.deviceId;

      // Automatically switch to Bluetooth when it becomes available.
      if (isNewBluetoothDevice && !_isBluetoothActive) {
        await _switchToBluetooth(bluetooth);
      }
    } catch (e) {
      debugPrint('[AUDIO] Failed to get audio outputs: $e');
    }
  }

  MediaDeviceInfo? _findBluetooth(List<MediaDeviceInfo> outputs) {
    for (final device in outputs) {
      final text = '${device.label} ${device.deviceId}'.toLowerCase();

      if (text.contains('bluetooth') ||
          text.contains('airpods') ||
          text.contains('wireless') ||
          text.contains('headset')) {
        return device;
      }
    }

    return null;
  }

  Future<void> _switchToBluetooth(MediaDeviceInfo device) async {
    try {
      await Helper.selectAudioOutput(device.deviceId);

      if (!mounted) return;

      setState(() {
        _isBluetoothActive = true;
        _userSelectedPhone = false;
      });

      debugPrint('[AUDIO] Switched to Bluetooth: ${device.label}');
    } catch (e) {
      debugPrint('[AUDIO] Bluetooth switch failed: $e');
    }
  }

  Future<void> _switchToPhone() async {
    try {
      // Speakerphone OFF = phone/receiver audio route.
      await Helper.setSpeakerphoneOn(false);

      if (!mounted) return;

      setState(() {
        _isBluetoothActive = false;
        _userSelectedPhone = true;
      });

      debugPrint('[AUDIO] Switched to phone audio');
    } catch (e) {
      debugPrint('[AUDIO] Phone audio switch failed: $e');
    }
  }

  Future<void> _toggleAudioRoute() async {
    final bluetooth = _bluetoothDevice;

    if (bluetooth == null) {
      // No Bluetooth available.
      // Keep phone audio.
      await _switchToPhone();
      return;
    }

    if (_isBluetoothActive) {
      // Bluetooth -> Phone
      await _switchToPhone();
    } else {
      // Phone -> Bluetooth
      await _switchToBluetooth(bluetooth);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool bluetoothAvailable = _bluetoothDevice != null;

    final IconData icon =
        _isBluetoothActive && bluetoothAvailable
            ? Icons.bluetooth_rounded
            : Icons.mic_rounded;

    return _CallCircleButton(
      size: widget.size,
      icon: icon,
      iconColor: const Color(0xFF666666),
      backgroundColor: Colors.white,
      borderColor: const Color(0xFF777777),
      onTap: _toggleAudioRoute,
    );
  }
}
