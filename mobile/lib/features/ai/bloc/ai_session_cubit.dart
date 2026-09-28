import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/ai.dart';
import '../ai_repository.dart';

class ChatMessage extends Equatable {
  const ChatMessage({required this.sender, required this.text});

  final String sender;
  final String text;

  bool get fromUser => sender == 'user';

  @override
  List<Object?> get props => [sender, text];
}

class AISessionControllerState extends Equatable {
  const AISessionControllerState({
    this.sessionId,
    this.messages = const [],
    this.busy = false,
    this.error,
  });

  final String? sessionId;
  final List<ChatMessage> messages;
  final bool busy;
  final String? error;

  AISessionControllerState copyWith({
    String? sessionId,
    List<ChatMessage>? messages,
    bool? busy,
    String? error,
  }) => AISessionControllerState(
    sessionId: sessionId ?? this.sessionId,
    messages: messages ?? this.messages,
    busy: busy ?? this.busy,
    error: error ?? this.error,
  );

  @override
  List<Object?> get props => [sessionId, messages, busy, error];
}

class AISessionCubit extends Cubit<AISessionControllerState> {
  AISessionCubit({required AIRepository repo})
    : _repo = repo,
      super(const AISessionControllerState());

  final AIRepository _repo;

  Future<void> start({
    String? characterId,
    String? scenario,
    List<AICharacter> characters = const [],
  }) async {
    final result = await _repo.startSession(
      characterId: characterId,
      scenario: scenario,
    );
    AICharacter? character;
    for (final c in characters) {
      if (c.id == result.session.characterId) {
        character = c;
        break;
      }
    }
    final shown =
        result.session.transcript.isEmpty && !result.resumed
            ? [
              if (result.session.characterId != null)
                ChatMessage(
                  sender: 'assistant',
                  text:
                      'Hi! I\'m ${character?.name ?? 'your partner'}. Let\'s '
                      'practice ${character?.scenario ?? 'conversation'} '
                      'together. How are you today?',
                ),
            ]
            : result.session.transcript
                .map((t) {
                  final map = t is Map ? t : null;
                  if (map == null) return null;
                  return ChatMessage(
                    sender: map['role'] as String? ?? 'assistant',
                    text: map['content'] as String? ?? '',
                  );
                })
                .whereType<ChatMessage>()
                .toList();
    emit(
      AISessionControllerState(
        sessionId: result.session.id,
        messages: shown,
        busy: false,
      ),
    );
  }

  Future<void> send(String text) async {
    final sessionId = state.sessionId;
    if (sessionId == null || text.trim().isEmpty || state.busy) return;
    emit(
      state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage(sender: 'user', text: text.trim()),
        ],
        busy: true,
        error: null,
      ),
    );
    try {
      final reply = await _repo.sendMessage(sessionId, text: text.trim());
      emit(
        state.copyWith(
          messages: [
            ...state.messages,
            ChatMessage(sender: 'assistant', text: reply),
          ],
          busy: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(busy: false, error: '$e'));
    }
  }

  Future<void> endAndGetSessionId() async {
    final sessionId = state.sessionId;
    if (sessionId != null) {
      try {
        await _repo.endSession(sessionId);
      } on Exception {
        // best effort
      }
    }
  }

  void reset() {
    emit(const AISessionControllerState());
  }
}
