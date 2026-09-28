import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

  void _splashToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pushReplacement(AppRoutes.callEnd);
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

          return Scaffold(
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.bgDark, Color(0xFF24243A)],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      Text(
                        call.phase == CallPhase.connected
                            ? 'Connected'
                            : 'Connecting…',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      UserAvatar(
                        url: match?.peer.avatar,
                        name: peerName,
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (call.phase != CallPhase.connected) ...[
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                color: Colors.white70,
                                strokeWidth: 2,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            _format(call.elapsedSeconds),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
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
                      Row(
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
                                call.phase == CallPhase.connected
                                    ? () =>
                                        context.read<CallCubit>().toggleMute()
                                    : null,
                          ),
                          const SizedBox(width: 32),
                          _ActionButton(
                            icon: Icons.call_end_rounded,
                            color: AppColors.danger,
                            iconColor: Colors.white,
                            onTap: () => context.read<CallCubit>().hangUp(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
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

  String _format(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
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
