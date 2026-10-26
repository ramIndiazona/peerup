import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:peerup/core/config/app_routes.dart';
import 'package:peerup/core/widgets/user_avatar.dart';
import 'package:peerup/features/call/cubit/call_cubit.dart';
import 'package:peerup/features/call/cubit/call_state.dart';
import 'package:peerup/features/friends/bloc/friends_cubit.dart';
import 'package:peerup/features/matchmaking/cubit/matchmaking_cubit.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:peerup/core/config/app_routes.dart';
import 'package:peerup/features/call/cubit/call_cubit.dart';
import 'package:peerup/features/call/cubit/call_state.dart';
import 'package:peerup/features/matchmaking/cubit/matchmaking_cubit.dart';

class CallEndScreen extends StatefulWidget {
  const CallEndScreen({super.key});

  @override
  State<CallEndScreen> createState() => _CallEndScreenState();
}

class _CallEndScreenState extends State<CallEndScreen> {
  // Colors matched to MatchHomeScreen's dark theme.
  static const Color primary = Color(0xFF9B8CFF);
  static const Color backgroundColor = Color(0xFF0B1020);
  static const Color surfaceColor = Color(0xFF151B30);
  static const Color textColor = Color(0xFFF5F6FF);
  static const Color mutedColor = Color(0xFF9AA5C4);
  static const Color borderColor = Color(0xFF303951);
  static const Color selectedColor = Color(0xFF252143);
  static const Color premiumColor = Color(0xFFFFD28B);

  final Set<String> _selectedFeedback = {};

  String? _selectedReaction;
  bool _addToFriends = false;
  bool _isSubmitting = false;

  final List<_FeedbackOption> _feedbackOptions = const [
    _FeedbackOption('Friendly', Icons.sentiment_satisfied_alt),
    _FeedbackOption('Excellent speaker', Icons.record_voice_over),
    _FeedbackOption('Good listener', Icons.hearing),
    _FeedbackOption('Easy to talk to', Icons.chat_bubble_outline),
    _FeedbackOption('Helpful', Icons.volunteer_activism),
    _FeedbackOption('Funny', Icons.sentiment_satisfied),
    _FeedbackOption('Confident speaker', Icons.mic_none),
    _FeedbackOption('Great conversation', Icons.star_border),
  ];

  bool get _hasSelection =>
      _selectedReaction != null ||
      _selectedFeedback.isNotEmpty ||
      _addToFriends;

  @override
  Widget build(BuildContext context) {
    final peer = context.watch<MatchmakingCubit>().state.match?.peer;
    final match = context.read<MatchmakingCubit>().state.match;

    final callState = context.watch<CallCubit>().state;
    final elapsedSeconds = callState.elapsedSeconds;
    final peerName = match?.peer.name ?? 'Partner';
    final bio = match?.peer.bio ?? 'Partner';
    return Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: backgroundColor,
        colorScheme: Theme.of(context).colorScheme.copyWith(
          brightness: Brightness.dark,
          primary: primary,
          surface: surfaceColor,
        ),
        textTheme: Theme.of(
          context,
        ).textTheme.apply(bodyColor: textColor, displayColor: textColor),
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: BlocBuilder<CallCubit, CallState>(
            builder: (context, state) {
              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 6),

                          Center(
                            child: _buildProfileImage(
                              match?.peer.avatar,
                              peerName,
                            ),
                          ),

                          // CallProfile(
                          //   url: match?.peer.avatar,
                          //   name: peerName,
                          //   bio: bio,
                          //   radius: 52,
                          // ),
                          const SizedBox(height: 24),

                          const Text(
                            'Call ended',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            peer?.name ?? 'Your conversation partner',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: textColor,
                            ),
                          ),

                          // Center(
                          //   child: Container(
                          //     padding: const EdgeInsets.symmetric(
                          //       horizontal: 18,
                          //       vertical: 12,
                          //     ),
                          //     decoration: BoxDecoration(
                          //       color: surfaceColor,
                          //       borderRadius: BorderRadius.circular(30),
                          //       border: Border.all(color: borderColor),
                          //     ),
                          //     child: Row(
                          //       mainAxisSize: MainAxisSize.min,
                          //       children: [
                          //         const Icon(
                          //           Icons.access_time,
                          //           color: primary,
                          //           size: 20,
                          //         ),
                          //         const SizedBox(width: 10),

                          //         Text(
                          //           'Call duration: '
                          //           '${_formatDuration(elapsedSeconds)}',
                          //           style: const TextStyle(
                          //             fontSize: 15,
                          //             fontWeight: FontWeight.w600,
                          //             color: textColor,
                          //           ),
                          //         ),
                          //       ],
                          //     ),
                          //   ),
                          // ),
                          const SizedBox(height: 36),

                          const Text(
                            'Would you like to connect again?',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          _buildFriendToggle(name: peer?.name ?? 'this person'),

                          const SizedBox(height: 20),

                          _buildReactionButtons(),

                          const SizedBox(height: 28),

                          const SizedBox(height: 18),

                          Wrap(
                            spacing: 10,
                            runSpacing: 12,
                            alignment: WrapAlignment.center,
                            children:
                                _feedbackOptions
                                    .map(_buildFeedbackChip)
                                    .toList(),
                          ),

                          const SizedBox(height: 28),
                        ],
                      ),
                    ),
                  ),

                  _buildBottomActions(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImage(String? avatar, String? name) {
    final initials =
        name != null && name.trim().isNotEmpty
            ? name.trim()[0].toUpperCase()
            : '?';

    return Container(
      width: 112,
      height: 112,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selectedColor,
        border: Border.all(color: primary.withValues(alpha: 0.45), width: 2),
      ),
      child: ClipOval(
        child:
            avatar != null && avatar.trim().isNotEmpty
                ? Image.network(
                  avatar,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _fallbackAvatar(initials),
                )
                : _fallbackAvatar(initials),
      ),
    );
  }

  Widget _fallbackAvatar(String initials) {
    return Container(
      color: selectedColor,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: primary,
          fontSize: 42,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildReactionButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildReactionButton(
            label: 'Like',
            value: 'like',
            icon: Icons.thumb_up_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildReactionButton(
            label: 'Dislike',
            value: 'dislike',
            icon: Icons.thumb_down_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildReactionButton({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final selected = _selectedReaction == value;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedReaction = selected ? null : value;
          });
        },
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 50,
          decoration: BoxDecoration(
            color: selected ? selectedColor : surfaceColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? primary : borderColor,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 27, color: selected ? primary : mutedColor),
              SizedBox(width: 20),
              Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? primary : textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackChip(_FeedbackOption option) {
    final selected = _selectedFeedback.contains(option.label);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () {
          setState(() {
            if (selected) {
              _selectedFeedback.remove(option.label);
            } else {
              _selectedFeedback.add(option.label);
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? selectedColor : surfaceColor,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: selected ? primary : borderColor,
              width: selected ? 1.1 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                option.icon,
                size: 19,
                color: selected ? primary : mutedColor,
              ),
              const SizedBox(width: 8),
              Text(
                option.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? primary : textColor,
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 6),
                const Icon(Icons.check_circle, size: 17, color: primary),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFriendToggle({required String name}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _addToFriends ? selectedColor : surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _addToFriends ? primary : borderColor,
          width: _addToFriends ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              color: selectedColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_add_alt_1, color: primary, size: 25),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Talk again in the future?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _addToFriends
                      ? 'Connect with $name.'
                      : 'Add this person to your friends.',
                  style: const TextStyle(fontSize: 13, color: mutedColor),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _addToFriends,
            activeTrackColor: primary,

            onChanged: (value) {
              setState(() {
                _addToFriends = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        color: backgroundColor,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton(
              onPressed:
                  _hasSelection && !_isSubmitting ? _submitFeedback : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                disabledBackgroundColor: surfaceColor,
                foregroundColor: backgroundColor,
                disabledForegroundColor: mutedColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child:
                  _isSubmitting
                      ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: backgroundColor,
                        ),
                      )
                      : const Text(
                        'Submit feedback',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _isSubmitting ? null : _skip,
            child: const Text(
              'Skip and go home',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: mutedColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Future<void> _submitFeedback() async {
  //   if (!_hasSelection || _isSubmitting) return;

  //   setState(() {
  //     _isSubmitting = true;
  //   });

  //   try {

  //     if (!mounted) return;

  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(
  //         content: Text(
  //           'Feedback selected. Connect the API to save your response.',
  //         ),
  //       ),
  //     );
  //   } catch (error) {
  //     if (!mounted) return;

  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Unable to submit feedback: $error')),
  //     );
  //   } finally {
  //     if (mounted) {
  //       setState(() {
  //         _isSubmitting = false;
  //       });
  //     }
  //   }
  // }

  Future<void> _submitFeedback() async {
    if (!_hasSelection || _isSubmitting) return;

    final match = context.read<MatchmakingCubit>().state.match;
    final receiverId = match?.peer.id;

    if (receiverId == null || receiverId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to identify your conversation partner.'),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final response = await context.read<FriendsCubit>().submitCallFeedback(
        receiverId: receiverId,
        reaction: _selectedReaction,
        feedback: _selectedFeedback.toList(),
        addToFriends: _addToFriends,
        connectAgain: false,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response is Map && response['message'] is String
                ? response['message'] as String
                : 'Feedback submitted successfully.',
          ),
        ),
      );

      context.read<MatchmakingCubit>().reset();
      context.go(AppRoutes.homeMatch);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to submit feedback: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _skip() {
    context.read<MatchmakingCubit>().reset();
    context.go(AppRoutes.homeMatch);
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${remainingSeconds.toString().padLeft(2, '0')}';
  }
}

class _FeedbackOption {
  final String label;
  final IconData icon;

  const _FeedbackOption(this.label, this.icon);
}
