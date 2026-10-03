// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:go_router/go_router.dart';

// import '../../core/call/call_repository.dart';
// import '../../core/config/app_routes.dart';
// import '../../core/theme/app_colors.dart';
// import '../../core/widgets/loading_button.dart';
// import '../../models/enums.dart';
// import '../matchmaking/cubit/matchmaking_cubit.dart';
// import '../profile/profile_repository.dart';
// import 'cubit/call_cubit.dart';
// import 'cubit/call_state.dart';

// class CallEndScreen extends StatefulWidget {
//   const CallEndScreen({super.key});

//   @override
//   State<CallEndScreen> createState() => _CallEndScreenState();
// }

// class _CallEndScreenState extends State<CallEndScreen> {
//   final bool _busy = false;

//   @override
//   void initState() {
//     super.initState();
//     Future.microtask(() {
//       if (!mounted) return;
//       context.read<CallCubit>().reset();
//     });
//   }

//   Future<void> _goHome() async {
//     context.read<MatchmakingCubit>().reset();
//     context.go(AppRoutes.homeMatch);
//   }

//   Future<void> _showReportSheet() async {
//     final match = context.read<MatchmakingCubit>().state.match;
//     final peer = match?.peer;
//     if (peer == null) return;
//     await showModalBottomSheet<void>(
//       context: context,
//       isScrollControlled: true,
//       builder:
//           (context) => _ReportSheet(peerId: peer.id, callId: match!.callId),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);

//     return BlocBuilder<CallCubit, CallState>(
//       builder: (context, state) {
//         return Scaffold(
//           body: SafeArea(
//             child: Padding(
//               padding: const EdgeInsets.all(28),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.stretch,
//                 children: [
//                   const SizedBox(height: 40),
//                   Icon(
//                     Icons.check_circle_rounded,
//                     size: 64,
//                     color: AppColors.success,
//                   ),
//                   const SizedBox(height: 16),
//                   Text(
//                     'Call finished',
//                     textAlign: TextAlign.center,
//                     style: theme.textTheme.headlineSmall?.copyWith(
//                       fontWeight: FontWeight.w800,
//                     ),
//                   ),
//                   const SizedBox(height: 8),
//                   Text(
//                     'Nice job staying in the conversation. Keep practicing!',
//                     textAlign: TextAlign.center,
//                     style: theme.textTheme.bodyMedium?.copyWith(
//                       color: theme.colorScheme.outline,
//                     ),
//                   ),
//                   const SizedBox(height: 28),
//                   Card(
//                     child: Padding(
//                       padding: const EdgeInsets.all(18),
//                       child: Row(
//                         children: [
//                           Icon(
//                             Icons.timer_outlined,
//                             color: theme.colorScheme.primary,
//                           ),
//                           const SizedBox(width: 12),
//                           Text(
//                             'Call duration',
//                             style: theme.textTheme.bodyMedium?.copyWith(
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                           const Spacer(),
//                           Text(
//                             _format(state.elapsedSeconds),
//                             style: theme.textTheme.titleMedium?.copyWith(
//                               fontWeight: FontWeight.w800,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 12),
//                   Card(
//                     child: Padding(
//                       padding: const EdgeInsets.all(18),
//                       child: Row(
//                         children: [
//                           Icon(
//                             Icons.translate_rounded,
//                             color: theme.colorScheme.primary,
//                           ),
//                           const SizedBox(width: 12),
//                           Text(
//                             'Daily practice streak grows',
//                             style: theme.textTheme.bodyMedium?.copyWith(
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                           const Spacer(),
//                           const Icon(Icons.trending_up_rounded),
//                         ],
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 28),
//                   const Spacer(),
//                   OutlinedButton.icon(
//                     onPressed: _busy ? null : _showReportSheet,
//                     icon: const Icon(Icons.flag_outlined),
//                     label: const Text('Report the peer'),
//                     style: OutlinedButton.styleFrom(
//                       foregroundColor: AppColors.danger,
//                     ),
//                   ),
//                   const SizedBox(height: 12),
//                   LoadingButton(label: 'Back to home', onPressed: _goHome),
//                   const SizedBox(height: 16),
//                 ],
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }

//   String _format(int seconds) {
//     final m = (seconds ~/ 60).toString().padLeft(2, '0');
//     final s = (seconds % 60).toString().padLeft(2, '0');
//     return '$m:$s';
//   }
// }

// class _ReportSheet extends StatefulWidget {
//   const _ReportSheet({required this.peerId, required this.callId});

//   final String peerId;
//   final String callId;

//   @override
//   State<_ReportSheet> createState() => _ReportSheetState();
// }

// class _ReportSheetState extends State<_ReportSheet> {
//   ReportReason? _reason;
//   final _description = TextEditingController();
//   bool _busy = false;

//   @override
//   void dispose() {
//     _description.dispose();
//     super.dispose();
//   }

//   Future<void> _submit() async {
//     if (_reason == null) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text('Please choose a reason')));
//       return;
//     }
//     setState(() => _busy = true);
//     try {
//       if (widget.callId.isNotEmpty) {
//         await context.read<CallRepository>().reportCall(
//           widget.callId,
//           reason: _reason!.api,
//           description: _description.text,
//         );
//       } else {
//         await context.read<ProfileRepository>().reportUser(
//           widget.peerId,
//           reason: _reason!.api,
//           description: _description.text,
//         );
//       }
//       if (!mounted) return;
//       Navigator.of(context).pop();
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Report submitted. Thank you.')),
//       );
//     } on Exception catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text('Failed to submit: $e')));
//     } finally {
//       if (mounted) setState(() => _busy = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     return Padding(
//       padding: EdgeInsets.only(
//         left: 24,
//         right: 24,
//         top: 24,
//         bottom: MediaQuery.of(context).viewInsets.bottom + 24,
//       ),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         crossAxisAlignment: CrossAxisAlignment.stretch,
//         children: [
//           Text(
//             'Report this conversation',
//             style: theme.textTheme.titleLarge?.copyWith(
//               fontWeight: FontWeight.w800,
//             ),
//           ),
//           const SizedBox(height: 6),
//           Text(
//             'Our moderation team reviews every report.',
//             style: theme.textTheme.bodyMedium?.copyWith(
//               color: theme.colorScheme.outline,
//             ),
//           ),
//           const SizedBox(height: 18),
//           Wrap(
//             spacing: 8,
//             runSpacing: 8,
//             children:
//                 ReportReason.values
//                     .map(
//                       (r) => ChoiceChip(
//                         label: Text(r.label),
//                         selected: _reason == r,
//                         onSelected: (_) => setState(() => _reason = r),
//                       ),
//                     )
//                     .toList(),
//           ),
//           const SizedBox(height: 14),
//           TextField(
//             controller: _description,
//             maxLines: 3,
//             maxLength: 1000,
//             decoration: const InputDecoration(
//               labelText: 'Anything else? (optional)',
//               alignLabelWithHint: true,
//             ),
//           ),
//           const SizedBox(height: 8),
//           LoadingButton(
//             label: 'Submit report',
//             loading: _busy,
//             onPressed: _submit,
//           ),
//         ],
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/call/call_repository.dart';
import '../../core/config/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/loading_button.dart';
import '../../models/enums.dart';
import '../matchmaking/cubit/matchmaking_cubit.dart';
import '../profile/profile_repository.dart';
import 'cubit/call_cubit.dart';
import 'cubit/call_state.dart';

class CallEndScreen extends StatefulWidget {
  const CallEndScreen({super.key});

  @override
  State<CallEndScreen> createState() => _CallEndScreenState();
}

class _CallEndScreenState extends State<CallEndScreen> {
  final Set<String> _selectedFeedback = {};

  bool _addToFriends = false;

  final List<_FeedbackOption> _feedbackOptions = const [
    _FeedbackOption(
      id: 'friendly',
      label: 'Friendly',
      icon: Icons.sentiment_satisfied_alt_rounded,
    ),
    _FeedbackOption(
      id: 'excellent_speaker',
      label: 'Excellent speaker',
      icon: Icons.record_voice_over_rounded,
    ),
    _FeedbackOption(
      id: 'good_listener',
      label: 'Good listener',
      icon: Icons.hearing_rounded,
    ),
    _FeedbackOption(
      id: 'easy_to_talk',
      label: 'Easy to talk to',
      icon: Icons.chat_bubble_outline_rounded,
    ),
    _FeedbackOption(
      id: 'helpful',
      label: 'Helpful',
      icon: Icons.volunteer_activism_rounded,
    ),
    _FeedbackOption(
      id: 'funny',
      label: 'Funny',
      icon: Icons.emoji_emotions_outlined,
    ),
    _FeedbackOption(
      id: 'confident_speaker',
      label: 'Confident speaker',
      icon: Icons.mic_none_rounded,
    ),
    _FeedbackOption(
      id: 'great_conversation',
      label: 'Great conversation',
      icon: Icons.star_outline_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      if (!mounted) return;
      context.read<CallCubit>().reset();
    });
  }

  Future<void> _goHome() async {
    context.read<MatchmakingCubit>().reset();
    context.go(AppRoutes.homeMatch);
  }

  Future<void> _showReportSheet() async {
    final match = context.read<MatchmakingCubit>().state.match;
    final peer = match?.peer;

    if (peer == null) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => _ReportSheet(peerId: peer.id, callId: match!.callId),
    );
  }

  void _toggleFeedback(String id) {
    setState(() {
      if (_selectedFeedback.contains(id)) {
        _selectedFeedback.remove(id);
      } else {
        _selectedFeedback.add(id);
      }
    });
  }

  void _toggleAddFriend() {
    setState(() {
      _addToFriends = !_addToFriends;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<CallCubit, CallState>(
      builder: (context, state) {
        final match = context.read<MatchmakingCubit>().state.match;
        final peer = match?.peer;

        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ======================================================
                  // SUCCESS ICON
                  // ======================================================
                  const SizedBox(height: 8),

                  Center(
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        size: 38,
                        color: AppColors.success,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'Call finished',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'Nice job staying in the conversation!',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.black54,
                    ),
                  ),

                  // ======================================================
                  // PEER
                  // ======================================================
                  if (peer != null) ...[
                    const SizedBox(height: 22),

                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: const Color(0xFFF0F0F0),
                            backgroundImage:
                                peer.avatar != null && peer.avatar!.isNotEmpty
                                    ? NetworkImage(peer.avatar!)
                                    : null,
                            child:
                                peer.avatar == null || peer.avatar!.isEmpty
                                    ? Text(
                                      peer.name.isNotEmpty
                                          ? peer.name[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF666666),
                                      ),
                                    )
                                    : null,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            peer.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ======================================================
                  // CALL DURATION
                  // ======================================================
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F8FA),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.10),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.timer_outlined,
                            size: 20,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Call duration',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          _format(state.elapsedSeconds),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ======================================================
                  // FEEDBACK TITLE
                  // ======================================================
                  const Text(
                    'How was your conversation?',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    'Select everything that describes your conversation.',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),

                  const SizedBox(height: 16),

                  // ======================================================
                  // MULTI SELECT FEEDBACK
                  // ======================================================
                  Wrap(
                    spacing: 9,
                    runSpacing: 10,
                    children:
                        _feedbackOptions.map((option) {
                          final selected = _selectedFeedback.contains(
                            option.id,
                          );

                          return _FeedbackChip(
                            option: option,
                            selected: selected,
                            onTap: () {
                              _toggleFeedback(option.id);
                            },
                          );
                        }).toList(),
                  ),

                  const SizedBox(height: 28),

                  // ======================================================
                  // ADD FRIEND
                  // ======================================================
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F8FA),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            _addToFriends
                                ? AppColors.primary
                                : Colors.transparent,
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.10,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _addToFriends
                                    ? Icons.person_add_rounded
                                    : Icons.people_outline_rounded,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Talk again in the future?',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'Add this person to your friends.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: _addToFriends,
                              activeColor: AppColors.primary,
                              onChanged: (_) {
                                _toggleAddFriend();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ======================================================
                  // REPORT
                  // ======================================================
                  OutlinedButton.icon(
                    onPressed: _showReportSheet,
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('Report the peer'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: BorderSide(
                        color: AppColors.danger.withValues(alpha: 0.5),
                      ),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ======================================================
                  // BACK HOME
                  // ======================================================
                  LoadingButton(label: 'Back to home', onPressed: _goHome),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _format(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');

    return '$m:$s';
  }
}

// ======================================================================
// FEEDBACK OPTION
// ======================================================================

class _FeedbackOption {
  const _FeedbackOption({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final IconData icon;
}

// ======================================================================
// FEEDBACK CHIP
// ======================================================================

class _FeedbackChip extends StatelessWidget {
  const _FeedbackChip({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _FeedbackOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color:
              selected
                  ? AppColors.primary.withValues(alpha: 0.10)
                  : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFE0E0E0),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              option.icon,
              size: 17,
              color: selected ? AppColors.primary : const Color(0xFF666666),
            ),
            const SizedBox(width: 7),
            Text(
              option.label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.primary : const Color(0xFF444444),
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 5),
              Icon(Icons.check_rounded, size: 15, color: AppColors.primary),
            ],
          ],
        ),
      ),
    );
  }
}

// ======================================================================
// REPORT SHEET
// ======================================================================

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.peerId, required this.callId});

  final String peerId;
  final String callId;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  ReportReason? _reason;

  final _description = TextEditingController();

  bool _busy = false;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reason == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please choose a reason')));
      return;
    }

    setState(() => _busy = true);

    try {
      if (widget.callId.isNotEmpty) {
        await context.read<CallRepository>().reportCall(
          widget.callId,
          reason: _reason!.api,
          description: _description.text,
        );
      } else {
        await context.read<ProfileRepository>().reportUser(
          widget.peerId,
          reason: _reason!.api,
          description: _description.text,
        );
      }

      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted. Thank you.')),
      );
    } on Exception catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to submit: $e')));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Report this conversation',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'Our moderation team reviews every report.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),

          const SizedBox(height: 18),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                ReportReason.values
                    .map(
                      (r) => ChoiceChip(
                        label: Text(r.label),
                        selected: _reason == r,
                        onSelected: (_) {
                          setState(() {
                            _reason = r;
                          });
                        },
                      ),
                    )
                    .toList(),
          ),

          const SizedBox(height: 14),

          TextField(
            controller: _description,
            maxLines: 3,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Anything else? (optional)',
              alignLabelWithHint: true,
            ),
          ),

          const SizedBox(height: 8),

          LoadingButton(
            label: 'Submit report',
            loading: _busy,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
