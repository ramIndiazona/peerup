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
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.smart_toy_outlined, size: 56),

                    const SizedBox(height: 16),

                    const Text(
                      'No active practice session. '
                      'Choose a character to start.',
                      textAlign: TextAlign.center,
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
          appBar: AppBar(
            title: const Text('Practice'),

            actions: [
              TextButton(
                onPressed: state.busy ? null : _end,
                child: const Text('End & feedback'),
              ),
            ],
          ),

          body: SafeArea(
            child: Column(
              children: [
                // =========================
                // CHAT MESSAGES
                // =========================
                Expanded(
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: state.messages.length,
                    itemBuilder: (context, i) {
                      final message = state.messages[i];

                      return _Bubble(message: message);
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

                // =========================
                // INPUT
                // =========================
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _input,
                          textInputAction: TextInputAction.send,

                          onSubmitted: (_) => _send(),

                          decoration: const InputDecoration(
                            hintText: 'Type your message…',
                            isDense: true,
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      IconButton.filled(
                        onPressed: state.busy ? null : _send,

                        icon:
                            state.busy
                                ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ),
              ],
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

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final mine = message.fromUser;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,

      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),

        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),

        constraints: const BoxConstraints(maxWidth: 300),

        decoration: BoxDecoration(
          color: mine ? theme.colorScheme.primary : theme.colorScheme.surface,

          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),

            bottomLeft: Radius.circular(mine ? 16 : 4),

            bottomRight: Radius.circular(mine ? 4 : 16),
          ),

          border:
              mine ? null : Border.all(color: theme.colorScheme.outlineVariant),
        ),

        child: Text(
          message.text,

          style: TextStyle(
            color: mine ? Colors.white : theme.colorScheme.onSurface,

            height: 1.35,
          ),
        ),
      ),
    );
  }
}
