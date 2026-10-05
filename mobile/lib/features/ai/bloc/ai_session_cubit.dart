import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/ai.dart';
import '../ai_repository.dart';

class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
  });

  /// Stable per-session id. Used to guarantee an AI message is only ever
  /// spoken once (see Practice TTS).
  final int id;
  final String sender;
  final String text;

  bool get fromUser => sender == 'user';

  @override
  List<Object?> get props => [id, sender, text];
}

class AISessionControllerState extends Equatable {
  const AISessionControllerState({
    this.sessionId,
    this.messages = const [],
    this.busy = false,
    this.error,
    this.character,
    this.scenario,
    this.startedAt,
  });

  final String? sessionId;
  final List<ChatMessage> messages;
  final bool busy;
  final String? error;

  /// Character currently selected for this practice session (if any).
  final AICharacter? character;

  /// Scenario currently selected for this practice session (if any).
  final String? scenario;

  /// When the current session was created, used for the real session duration.
  final DateTime? startedAt;

  AISessionControllerState copyWith({
    String? sessionId,
    List<ChatMessage>? messages,
    bool? busy,
    String? error,
    AICharacter? character,
    String? scenario,
    DateTime? startedAt,
  }) => AISessionControllerState(
    sessionId: sessionId ?? this.sessionId,
    messages: messages ?? this.messages,
    busy: busy ?? this.busy,
    error: error ?? this.error,
    character: character ?? this.character,
    scenario: scenario ?? this.scenario,
    startedAt: startedAt ?? this.startedAt,
  );

  @override
  List<Object?> get props => [
    sessionId,
    messages,
    busy,
    error,
    character?.id,
    scenario,
    startedAt,
  ];
}

class AISessionCubit extends Cubit<AISessionControllerState> {
  AISessionCubit({required AIRepository repo})
    : _repo = repo,
      super(const AISessionControllerState());

  final AIRepository _repo;

  int _messageId = 0;

  ChatMessage _message(String sender, String text) =>
      ChatMessage(id: ++_messageId, sender: sender, text: text);

  /// Always starts a brand new session.
  ///
  /// The backend creates a fresh session per call and does not return previous
  /// transcripts, so no history is ever loaded here either.
  Future<void> start({
    String? characterId,
    String? scenario,
    List<AICharacter> characters = const [],
  }) async {
    _messageId = 0;

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

    final greeting =
        'Hi! I\'m ${character?.name ?? 'your partner'}. '
        'Let\'s practice ${scenario ?? character?.scenario ?? 'conversation'} '
        'together. How are you today?';

    emit(
      AISessionControllerState(
        sessionId: result.session.id,
        messages: [_message('assistant', greeting)],
        busy: false,
        character: character,
        scenario: scenario ?? character?.scenario,
        startedAt: result.session.startedAt,
      ),
    );
  }

  Future<void> send(String text) async {
    final sessionId = state.sessionId;
    if (sessionId == null || text.trim().isEmpty || state.busy) return;
    emit(
      state.copyWith(
        messages: [...state.messages, _message('user', text.trim())],
        busy: true,
        error: null,
      ),
    );
    try {
      final reply = await _repo.sendMessage(sessionId, text: text.trim());
      emit(
        state.copyWith(
          messages: [...state.messages, _message('assistant', reply)],
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
    _messageId = 0;
    emit(const AISessionControllerState());
  }
}
