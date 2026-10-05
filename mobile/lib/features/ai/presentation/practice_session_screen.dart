import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_button.dart';
import '../bloc/ai_session_cubit.dart';
import '../services/ai_tts_service.dart';
import 'widgets/ai_character_stage.dart';

/// Main Practice screen.
///
/// The AI character is the focus of the screen: it is displayed large on top
/// and the conversation flows underneath it. Only AI messages are spoken with
/// TTS; user messages are never spoken.
class PracticeSessionScreen extends StatefulWidget {
  const PracticeSessionScreen({super.key});

  @override
  State<PracticeSessionScreen> createState() => _PracticeSessionScreenState();
}

class _PracticeSessionScreenState extends State<PracticeSessionScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  /// Guards duplicate speech: an AI message is spoken exactly once, even if
  /// the bloc emits several times for the same message.
  int? _lastSpokenId;

  /// True while the character is being animated because TTS is playing.
  bool _speaking = false;

  bool _ended = false;

  /// Lazy holder so TTS is only created when this screen needs it.
  _PracticeSpeech? _speech;

  @override
  void initState() {
    super.initState();
    _speech = _PracticeSpeech(
      onStateChanged: (speaking) {
        if (!mounted) return;
        setState(() => _speaking = speaking);
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _speakLatest(context.read<AISessionCubit>().state);
    });
  }

  @override
  void dispose() {
    _speech?.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Speaks the latest AI message if it has not been spoken yet.
  Future<void> _speakLatest(AISessionControllerState state) {
    if (state.messages.isEmpty) return Future<void>.value();
    final latest = state.messages.last;

    // User messages are NEVER spoken.
    if (latest.fromUser) return Future<void>.value();

    if (latest.id == _lastSpokenId) return Future<void>.value();

    _lastSpokenId = latest.id;

    return _speech!.speak(latest.text);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;

    _input.clear();
    await context.read<AISessionCubit>().send(text);
  }

  Future<void> _end() async {
    if (_ended) return;
    _ended = true;

    // Stop audio + animation before leaving the screen.
    await _speech?.stop();
    if (!mounted) return;
    setState(() => _speaking = false);

    final cubit = context.read<AISessionCubit>();
    final sessionId = cubit.state.sessionId;
    await cubit.endAndGetSessionId();

    if (!mounted) return;

    if (sessionId == null) {
      context.go(AppRoutes.homeAi);
      return;
    }

    context.pushReplacement(
      AppRoutes.practiceFeedback.replaceFirst(':sessionId', sessionId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocConsumer<AISessionCubit, AISessionControllerState>(
      listener: (context, state) {
        // Speech is driven by bloc emissions, never by widget rebuilds.
        unawaited(_speakLatest(state));
        _scrollToBottom();
      },
      builder: (context, state) {
        if (state.sessionId == null) {
          return _NoSessionView(onBack: () => context.go(AppRoutes.practice));
        }

        final stage = _stage(state);

        return Scaffold(
          backgroundColor: AppColors.bgLight,
          appBar: AppBar(
            backgroundColor: AppColors.bgLight,
            title: const Text('Practice'),
            actions: [
              IconButton(
                tooltip: 'End practice',
                onPressed: state.busy ? null : _end,
                icon: const Icon(Icons.stop_circle_outlined),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                // =========================
                // CHARACTER STAGE
                // =========================
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: AICharacterStage(
                    character: state.character,
                    state: stage,
                    size: 190,
                  ),
                ),

                // =========================
                // CONVERSATION
                // =========================
                Expanded(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: state.messages.length,
                      itemBuilder:
                          (context, i) =>
                              _MessageBubble(message: state.messages[i]),
                    ),
                  ),
                ),

                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Text(
                      state.error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
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
                            hintText: 'Type your answer…',
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(18),
                              ),
                            ),
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
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: LoadingButton(
                label: 'End Practice',
                isFilled: false,
                onPressed: state.busy ? null : _end,
              ),
            ),
          ),
        );
      },
    );
  }

  AICharacterState _stage(AISessionControllerState state) {
    if (_speaking) return AICharacterState.speaking;
    if (state.busy) return AICharacterState.thinking;
    return AICharacterState.idle;
  }
}

class _NoSessionView extends StatelessWidget {
  const _NoSessionView({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(backgroundColor: AppColors.bgLight),
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
                'No active practice session. Choose a character to start.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              LoadingButton(label: 'Back to Practice', onPressed: onBack),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bridges [AITtsService] with the screen: reports when playback starts and
/// stops so the character animation follows real TTS progress.
class _PracticeSpeech {
  _PracticeSpeech({required this.onStateChanged}) {
    _tts.onError = (Object error) {
      // TTS failure must never break Practice; the text stays visible.
    };
  }

  final void Function(bool speaking) onStateChanged;
  final AITtsService _tts = AITtsService();

  bool _cancelled = false;

  Future<void> speak(String text) async {
    if (_cancelled) return;
    await _tts.init();
    if (_cancelled) return;

    onStateChanged(true);
    try {
      await _tts.speak(text);
    } finally {
      if (!_cancelled) onStateChanged(false);
    }
  }

  Future<void> stop() async {
    _cancelled = true;
    onStateChanged(false);
    await _tts.stop();
  }

  void dispose() {
    _cancelled = true;
    unawaited(_tts.stop());
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mine = message.fromUser;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: mine ? AppColors.primary : AppColors.bgLight,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
        ),
        child: Text(
          message.text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: mine ? Colors.white : theme.colorScheme.onSurface,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}
