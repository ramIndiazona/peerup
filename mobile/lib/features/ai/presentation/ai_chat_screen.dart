// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:flutter_tts/flutter_tts.dart';
// import 'package:go_router/go_router.dart';

// import '../../../core/config/app_routes.dart';
// import '../../../core/widgets/loading_button.dart';
// import '../bloc/ai_session_cubit.dart';

// class AIChatScreen extends StatefulWidget {
//   const AIChatScreen({super.key});

//   @override
//   State<AIChatScreen> createState() => _AIChatScreenState();
// }

// class _AIChatScreenState extends State<AIChatScreen> {
//   final _input = TextEditingController();
//   final _scroll = ScrollController();
//   final FlutterTts _tts = FlutterTts();

//   bool _ended = false;

//   // Prevent the same AI message from being spoken multiple times.
//   String? _lastSpokenMessage;

//   @override
//   void initState() {
//     super.initState();

//     _initTts();

//     // Check initial message after the screen is rendered.
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (!mounted) return;

//       _speakLatestAIMessage(context.read<AISessionCubit>().state);
//     });
//   }

//   Future<void> _initTts() async {
//     await _tts.setLanguage('en-US');
//     await _tts.setSpeechRate(0.48);
//     await _tts.setPitch(1.0);
//     await _tts.setVolume(1.0);

//     // Optional but useful for iOS.
//     await _tts.awaitSpeakCompletion(true);
//   }

//   @override
//   void dispose() {
//     _tts.stop();
//     _input.dispose();
//     _scroll.dispose();
//     super.dispose();
//   }

//   void _scrollToBottom() {
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (_scroll.hasClients) {
//         _scroll.animateTo(
//           _scroll.position.maxScrollExtent,
//           duration: const Duration(milliseconds: 250),
//           curve: Curves.easeOut,
//         );
//       }
//     });
//   }

//   /// Speaks the latest AI message.
//   ///
//   /// User messages are NEVER spoken.
//   Future<void> _speakLatestAIMessage(AISessionControllerState state) async {
//     if (!mounted) return;

//     if (state.messages.isEmpty) return;

//     final latestMessage = state.messages.last;

//     // Never speak user's message.
//     if (latestMessage.fromUser) return;

//     final text = latestMessage.text.trim();

//     if (text.isEmpty) return;

//     // Don't speak the same message again.
//     if (_lastSpokenMessage == text) return;

//     _lastSpokenMessage = text;

//     await _speakAIMessage(text);
//   }

//   /// Speak ONLY AI response.
//   Future<void> _speakAIMessage(String text) async {
//     final cleanText = text.trim();

//     if (cleanText.isEmpty) return;

//     // Stop previous speech.
//     await _tts.stop();

//     await _tts.speak(cleanText);
//   }

//   Future<void> _send() async {
//     final text = _input.text.trim();

//     if (text.isEmpty) return;

//     _input.clear();

//     final cubit = context.read<AISessionCubit>();

//     // User message is NOT spoken.
//     await cubit.send(text);

//     if (!mounted) return;

//     _scrollToBottom();

//     // The BlocConsumer listener will speak the new AI message.
//   }

//   Future<void> _end() async {
//     if (_ended) return;

//     _ended = true;

//     // Stop AI voice when ending the session.
//     await _tts.stop();

//     final sessionId = context.read<AISessionCubit>().state.sessionId;

//     await context.read<AISessionCubit>().endAndGetSessionId();

//     if (!mounted) return;

//     if (sessionId != null) {
//       context.pushReplacement(
//         AppRoutes.aiFeedback.replaceFirst(':sessionId', sessionId),
//       );
//     } else {
//       context.pushReplacement(AppRoutes.homeAi);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);

//     return BlocConsumer<AISessionCubit, AISessionControllerState>(
//       listener: (context, state) {
//         // Whenever Cubit receives a new state,
//         // check whether a new AI message needs to be spoken.
//         _speakLatestAIMessage(state);

//         _scrollToBottom();
//       },

//       builder: (context, state) {
//         // =========================
//         // NO ACTIVE SESSION
//         // =========================
//         if (state.sessionId == null) {
//           return Scaffold(
//             body: SafeArea(
//               child: Padding(
//                 padding: const EdgeInsets.all(28),
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   crossAxisAlignment: CrossAxisAlignment.stretch,
//                   children: [
//                     const Icon(Icons.smart_toy_outlined, size: 56),

//                     const SizedBox(height: 16),

//                     const Text(
//                       'No active practice session. '
//                       'Choose a character to start.',
//                       textAlign: TextAlign.center,
//                     ),

//                     const SizedBox(height: 20),

//                     LoadingButton(
//                       label: 'Back to AI Practice',
//                       onPressed: () {
//                         context.read<AISessionCubit>().reset();

//                         context.pushReplacement(AppRoutes.homeAi);
//                       },
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           );
//         }

//         return Scaffold(
//           appBar: AppBar(
//             title: const Text('Practice'),

//             actions: [
//               TextButton(
//                 onPressed: state.busy ? null : _end,
//                 child: const Text('End & feedback'),
//               ),
//             ],
//           ),

//           body: SafeArea(
//             child: Column(
//               children: [
//                 // =========================
//                 // CHAT MESSAGES
//                 // =========================
//                 Expanded(
//                   child: ListView.builder(
//                     controller: _scroll,
//                     padding: const EdgeInsets.all(16),
//                     itemCount: state.messages.length,
//                     itemBuilder: (context, i) {
//                       final message = state.messages[i];

//                       return _Bubble(message: message);
//                     },
//                   ),
//                 ),

//                 // =========================
//                 // ERROR
//                 // =========================
//                 if (state.error != null)
//                   Padding(
//                     padding: const EdgeInsets.symmetric(horizontal: 16),
//                     child: Text(
//                       state.error!,
//                       style: TextStyle(
//                         color: theme.colorScheme.error,
//                         fontSize: 12,
//                       ),
//                     ),
//                   ),

//                 // =========================
//                 // INPUT
//                 // =========================
//                 Padding(
//                   padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
//                   child: Row(
//                     children: [
//                       Expanded(
//                         child: TextField(
//                           controller: _input,
//                           textInputAction: TextInputAction.send,

//                           onSubmitted: (_) => _send(),

//                           decoration: const InputDecoration(
//                             hintText: 'Type your message…',
//                             isDense: true,
//                           ),
//                         ),
//                       ),

//                       const SizedBox(width: 8),

//                       IconButton.filled(
//                         onPressed: state.busy ? null : _send,

//                         icon:
//                             state.busy
//                                 ? const SizedBox(
//                                   width: 18,
//                                   height: 18,
//                                   child: CircularProgressIndicator(
//                                     strokeWidth: 2,
//                                   ),
//                                 )
//                                 : const Icon(Icons.send_rounded),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
// }

// // ============================================================
// // CHAT BUBBLE
// // ============================================================

// class _Bubble extends StatelessWidget {
//   const _Bubble({required this.message});

//   final ChatMessage message;

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);

//     final mine = message.fromUser;

//     return Align(
//       alignment: mine ? Alignment.centerRight : Alignment.centerLeft,

//       child: Container(
//         margin: const EdgeInsets.symmetric(vertical: 6),

//         padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),

//         constraints: const BoxConstraints(maxWidth: 300),

//         decoration: BoxDecoration(
//           color: mine ? theme.colorScheme.primary : theme.colorScheme.surface,

//           borderRadius: BorderRadius.only(
//             topLeft: const Radius.circular(16),
//             topRight: const Radius.circular(16),

//             bottomLeft: Radius.circular(mine ? 16 : 4),

//             bottomRight: Radius.circular(mine ? 4 : 16),
//           ),

//           border:
//               mine ? null : Border.all(color: theme.colorScheme.outlineVariant),
//         ),

//         child: Text(
//           message.text,

//           style: TextStyle(
//             color: mine ? Colors.white : theme.colorScheme.onSurface,

//             height: 1.35,
//           ),
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flutter_tts/flutter_tts.dart';

import 'package:go_router/go_router.dart';

import '../../../core/config/app_routes.dart';

import '../../../core/widgets/loading_button.dart';

import '../bloc/ai_session_cubit.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final _input = TextEditingController();

  final _scroll = ScrollController();

  final FlutterTts _tts = FlutterTts();

  bool _ended = false;

  // Prevent the same AI message from being spoken multiple times.

  String? _lastSpokenMessage;

  @override
  void initState() {
    super.initState();

    _initTts();

    // Check initial message after the screen is rendered.

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _speakLatestAIMessage(context.read<AISessionCubit>().state);
    });
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');

    await _tts.setSpeechRate(0.48);

    await _tts.setPitch(1.0);

    await _tts.setVolume(1.0);

    // Optional but useful for iOS.

    await _tts.awaitSpeakCompletion(true);
  }

  @override
  void dispose() {
    _tts.stop();

    _input.dispose();

    _scroll.dispose();

    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,

          duration: const Duration(milliseconds: 250),

          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Speaks the latest AI message.

  ///

  /// User messages are NEVER spoken.

  Future<void> _speakLatestAIMessage(AISessionControllerState state) async {
    if (!mounted) return;

    if (state.messages.isEmpty) return;

    final latestMessage = state.messages.last;

    // Never speak user's message.

    if (latestMessage.fromUser) return;

    final text = latestMessage.text.trim();

    if (text.isEmpty) return;

    // Don't speak the same message again.

    if (_lastSpokenMessage == text) return;

    _lastSpokenMessage = text;

    await _speakAIMessage(text);
  }

  /// Speak ONLY AI response.

  Future<void> _speakAIMessage(String text) async {
    final cleanText = text.trim();

    if (cleanText.isEmpty) return;

    // Stop previous speech.

    await _tts.stop();

    await _tts.speak(cleanText);
  }

  Future<void> _send() async {
    final text = _input.text.trim();

    if (text.isEmpty) return;

    _input.clear();

    final cubit = context.read<AISessionCubit>();

    // User message is NOT spoken.

    await cubit.send(text);

    if (!mounted) return;

    _scrollToBottom();

    // The BlocConsumer listener will speak the new AI message.
  }

  Future<void> _end() async {
    if (_ended) return;

    _ended = true;

    // Stop AI voice when ending the session.

    await _tts.stop();

    final sessionId = context.read<AISessionCubit>().state.sessionId;

    await context.read<AISessionCubit>().endAndGetSessionId();

    if (!mounted) return;

    if (sessionId != null) {
      context.pushReplacement(
        AppRoutes.aiFeedback.replaceFirst(':sessionId', sessionId),
      );
    } else {
      context.pushReplacement(AppRoutes.homeAi);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocConsumer<AISessionCubit, AISessionControllerState>(
      listener: (context, state) {
        // Whenever Cubit receives a new state,

        // check whether a new AI message needs to be spoken.

        _speakLatestAIMessage(state);

        _scrollToBottom();
      },

      builder: (context, state) {
        // =========================

        // NO ACTIVE SESSION

        // =========================

        if (state.sessionId == null) {
          return Scaffold(
            backgroundColor: const Color(0xFF0B1020),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(28),

                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,

                  crossAxisAlignment: CrossAxisAlignment.stretch,

                  children: [
                    const Icon(
                      Icons.smart_toy_outlined,
                      size: 56,
                      color: Color(0xFF9B8CFF),
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'No active practice session. '
                      'Choose a character to start.',

                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFF5F6FF),
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 20),

                    LoadingButton(
                      label: 'Back to AI Practice',

                      onPressed: () {
                        context.read<AISessionCubit>().reset();

                        context.pushReplacement(AppRoutes.homeAi);
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFF0B1020),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0B1020),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            titleSpacing: 20,
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Practice',
                  style: TextStyle(
                    color: Color(0xFFF5F6FF),
                    fontWeight: FontWeight.w700,
                    fontSize: 19,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Practice your English conversation',
                  style: TextStyle(
                    color: Color(0xFF9AA5C4),
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: TextButton.icon(
                  onPressed: state.busy ? null : _end,
                  icon: const Icon(Icons.stop_circle_outlined, size: 17),
                  label: const Text('End'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFFA5B5),
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF0B1020),
                    Color(0xFF10162A),
                    Color(0xFF0B1020),
                  ],
                ),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      controller: _scroll,

                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                      itemCount:
                          state.messages.isEmpty ? 1 : state.messages.length,
                      itemBuilder: (context, i) {
                        if (state.messages.isEmpty) {
                          return const _ConversationWelcome();
                        }
                        return _Bubble(message: state.messages[i]);
                      },
                    ),
                  ),

                  // =========================

                  // ERROR

                  // =========================
                  if (state.error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),

                      child: Text(
                        state.error!,

                        style: TextStyle(
                          color: theme.colorScheme.error,

                          fontSize: 12,
                        ),
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF151B30),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.10),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF9B8CFF).withOpacity(0.08),
                            blurRadius: 24,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _input,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _send(),
                              style: const TextStyle(
                                color: Color(0xFFF5F6FF),
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Write your reply…',
                                hintStyle: TextStyle(
                                  color: const Color(
                                    0xFF9AA5C4,
                                  ).withOpacity(0.8),
                                ),
                                filled: false,
                                isDense: true,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 48,
                            height: 48,
                            child: IconButton(
                              onPressed: state.busy ? null : _send,
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFF9B8CFF),
                                foregroundColor: const Color(0xFF0B1020),
                                disabledBackgroundColor: const Color(
                                  0xFF343951,
                                ),
                                shape: const CircleBorder(),
                                padding: EdgeInsets.zero,
                              ),
                              icon:
                                  state.busy
                                      ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF0B1020),
                                        ),
                                      )
                                      : const Icon(
                                        Icons.send_rounded,
                                        size: 23,
                                      ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ============================================================

// CHAT BUBBLE

// ============================================================

class _ConversationWelcome extends StatelessWidget {
  const _ConversationWelcome();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 30, bottom: 12),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF151B30).withOpacity(0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.09)),
      ),
      child: const Column(
        children: [
          CircleAvatar(
            radius: 29,
            backgroundColor: Color(0x269B8CFF),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFFB5A9FF),
              size: 28,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Let’s start a conversation',
            style: TextStyle(
              color: Color(0xFFF5F6FF),
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Send a message below. Your AI partner will reply and speak the response aloud.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF9AA5C4),
              height: 1.5,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final mine = message.fromUser;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,

      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),

        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),

        constraints: const BoxConstraints(maxWidth: 300),

        decoration: BoxDecoration(
          color: mine ? const Color(0xFF7566D9) : const Color(0xFF151B30),

          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),

            topRight: const Radius.circular(16),

            bottomLeft: Radius.circular(mine ? 16 : 4),

            bottomRight: Radius.circular(mine ? 4 : 16),
          ),

          border: Border.all(
            color:
                mine
                    ? const Color(0xFF9B8CFF).withOpacity(0.45)
                    : Colors.white.withOpacity(0.09),
          ),
        ),

        child: Text(
          message.text,

          style: TextStyle(
            color: const Color(0xFFF5F6FF),
            fontSize: 14,

            height: 1.35,
          ),
        ),
      ),
    );
  }
}
