import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/realtime/realtime_connection_state.dart';
import '../../../core/realtime/realtime_event.dart';
import '../../../core/realtime/realtime_event_bus.dart';
import '../../../models/chat.dart';
import '../chat_repository.dart';

enum ChatStatus { initial, loading, loaded, error }

class ChatState extends Equatable {
  const ChatState({
    this.status = ChatStatus.initial,
    this.messages = const [],
    this.conversationId,
    this.error,
    this.sending = false,
    this.connected = false,
    this.hasMore = false,
    this.loadingOlder = false,
  });

  final ChatStatus status;
  final List<ChatMessage> messages;
  final String? conversationId;
  final Object? error;

  /// True while a send is in flight (disables the composer to prevent
  /// accidental duplicate sends).
  final bool sending;

  /// Socket connection state, surfaced to the UI as a connection banner.
  final bool connected;

  /// True when older messages exist above the currently loaded window.
  final bool hasMore;

  /// True while an older history page is being fetched.
  final bool loadingOlder;

  bool get isInitial => status == ChatStatus.initial;
  bool get isLoading => status == ChatStatus.loading;
  bool get isLoaded => status == ChatStatus.loaded;
  bool get hasError => status == ChatStatus.error;
  bool get isEmpty => status == ChatStatus.loaded && messages.isEmpty;

  ChatState copyWith({
    ChatStatus? status,
    List<ChatMessage>? messages,
    String? conversationId,
    Object? error,
    bool? sending,
    bool? connected,
    bool? hasMore,
    bool? loadingOlder,
    bool clearError = false,
  }) {
    return ChatState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      conversationId: conversationId ?? this.conversationId,
      error: clearError ? null : (error ?? this.error),
      sending: sending ?? this.sending,
      connected: connected ?? this.connected,
      hasMore: hasMore ?? this.hasMore,
      loadingOlder: loadingOlder ?? this.loadingOlder,
    );
  }

  @override
  List<Object?> get props => [
    status,
    messages,
    conversationId,
    error,
    sending,
    connected,
    hasMore,
    loadingOlder,
  ];
}

/// Owns one-to-one chat for a single friend.
///
/// Lifecycle:
///   open()  -> resolve conversation (REST) -> load history (REST)
///           -> subscribe to CHAT_MESSAGE on the shared socket
///   send()  -> persist via REST, reconcile the optimistic echo by id
///   reconnect -> reload history to load anything missed while offline
///
/// The shared socket used by live/matchmaking/calls is reused; this cubit
/// only adds/removes its own named-event subscription.
class ChatCubit extends Cubit<ChatState> {
  ChatCubit({
    required ChatRepository repo,
    required this.friendId,
    required RealtimeEventBus? socket,
    String? currentUserId,
  }) : _repo = repo,
       _socket = socket,
       _currentUserId = currentUserId,
       super(const ChatState()) {
    final bus = _socket;
    if (bus != null) {
      bus.subscribe(messageEvent);
      _eventsSub = bus.serverEvents.listen(_onServerEvent);
      _connectionSub = bus.connectionStateStream.listen(_onConnection);
      _connected = bus.connectionState == RealtimeConnectionState.connected;
      if (_connected) emit(state.copyWith(connected: true));
    }
  }

  /// Event name emitted by the NestJS backend after a message is persisted
  /// (`ConversationsService.sendMessage`). Delivered to both the sender and
  /// the recipient as a raw message object.
  static const String messageEvent = 'CHAT_MESSAGE';

  /// Page size used for the initial load and for "load earlier messages".
  static const int pageSize = 50;

  final ChatRepository _repo;
  final RealtimeEventBus? _socket;
  final String friendId;
  final String? _currentUserId;

  StreamSubscription<RealtimeRawEvent>? _eventsSub;
  StreamSubscription<RealtimeConnectionState>? _connectionSub;

  bool _connected = false;
  int _localSeq = 0;

  String? get currentUserId => _currentUserId;

  Conversation? _conversation;

  Conversation? get conversation => _conversation;

  /// Resolve the conversation, load history and subscribe to realtime updates.
  Future<void> open() async {
    emit(state.copyWith(status: ChatStatus.loading, clearError: true));
    try {
      final conversation = await _repo.getOrCreateConversation(friendId);
      _conversation = conversation;

      final history = await _repo.history(conversation.id, limit: pageSize);
      final messages = _merge(history.items);
      emit(
        state.copyWith(
          status: ChatStatus.loaded,
          conversationId: conversation.id,
          messages: messages,
          hasMore: history.items.length >= pageSize,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(status: ChatStatus.error, error: e));
    }
  }

  Future<void> retry() => open();

  /// Reload the persisted history (used after reconnect).
  Future<void> reloadHistory() async {
    final conversationId = state.conversationId;
    if (conversationId == null) return;
    try {
      final history = await _repo.history(conversationId, limit: pageSize);
      if (isClosed) return;
      emit(
        state.copyWith(
          messages: _merge(history.items),
          status: ChatStatus.loaded,
          // Keep `hasMore` true if a full first page is already showing;
          // it is only cleared once a short (or empty) older page comes back.
          hasMore: state.hasMore || history.items.length >= pageSize,
        ),
      );
    } catch (e) {
      debugPrint('[CHAT] history reload failed: $e');
    }
  }

  /// Fetch the page of messages older than everything currently shown.
  Future<void> loadOlder() async {
    final conversationId = state.conversationId;
    if (conversationId == null || state.loadingOlder || !state.hasMore) return;
    if (state.messages.isEmpty) return;

    final before = state.messages.first.createdAt;

    emit(state.copyWith(loadingOlder: true, clearError: true));
    try {
      final page = await _repo.history(
        conversationId,
        limit: pageSize,
        before: before,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          messages: _merge(page.items),
          loadingOlder: false,
          hasMore: page.items.length >= pageSize,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(loadingOlder: false, error: e));
    }
  }

  /// Persist [text] as a new message from the current user.
  ///
  /// Not retried automatically: the POST is not idempotent, so a failure is
  /// surfaced to the user instead of risking a duplicate message.
  Future<void> send(String text) async {
    final content = text.trim();
    final conversationId = state.conversationId;
    if (content.isEmpty || conversationId == null || state.sending) return;
    if (_currentUserId == null) {
      emit(state.copyWith(error: 'Session expired. Please sign in again.'));
      return;
    }

    final optimistic = ChatMessage(
      id: 'local-${_localSeq++}',
      conversationId: conversationId,
      senderId: _currentUserId,
      content: content,
      createdAt: DateTime.now(),
      pending: true,
    );

    emit(
      state.copyWith(
        messages: [...state.messages, optimistic],
        sending: true,
        clearError: true,
      ),
    );

    try {
      final server = await _repo.sendMessage(conversationId, content);
      if (isClosed) return;
      emit(state.copyWith(messages: _merge([server]), sending: false));
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          messages: [
            for (final m in state.messages)
              m.id == optimistic.id
                  ? m.copyWith(pending: false, failed: true)
                  : m,
          ],
          sending: false,
          error: e,
        ),
      );
    }
  }

  /// Remove a failed optimistic message (user chose to discard it).
  void discardFailed(String id) {
    final next = state.messages.where((m) => m.id != id).toList();
    if (next.length == state.messages.length) return;
    emit(state.copyWith(messages: next));
  }

  void _onServerEvent(RealtimeRawEvent event) {
    if (event.name != messageEvent) return;

    final raw = event.data['message'] ?? event.data;
    if (raw is! Map) return;

    final ChatMessage message;
    try {
      message = ChatMessage.fromJson(
        Map<String, dynamic>.from(raw),
        fallbackConversationId: state.conversationId,
      );
    } catch (e) {
      debugPrint('[CHAT] message parse error: $e');
      return;
    }

    if (message.id.isEmpty) return;

    // Ignore events for other conversations (the socket is shared app-wide).
    final activeId = state.conversationId;
    if (activeId != null &&
        message.conversationId.isNotEmpty &&
        message.conversationId != activeId) {
      return;
    }

    // Ignore messages that belong to neither side of this conversation.
    final peerMatches =
        message.senderId == friendId || message.senderId == _currentUserId;
    if (!peerMatches) return;

    final merged = _merge([message]);
    if (merged.length == state.messages.length &&
        !_replacesPending(state.messages, merged)) {
      return;
    }
    emit(state.copyWith(messages: merged, status: ChatStatus.loaded));
  }

  void _onConnection(RealtimeConnectionState connection) {
    final connected = connection == RealtimeConnectionState.connected;
    if (connected == _connected) return;
    _connected = connected;
    if (isClosed) return;
    emit(state.copyWith(connected: connected));
    if (connected) {
      unawaited(reloadHistory());
    }
  }

  /// Merge incoming messages into the current list:
  ///   * de-duplicate by id,
  ///   * replace a matching optimistic message with its server copy,
  ///   * otherwise append,
  /// keeping chronological order.
  List<ChatMessage> _merge(List<ChatMessage> incoming) {
    final result = [...state.messages];

    for (final message in incoming) {
      final existingIndex = result.indexWhere(
        (m) => m.id.isNotEmpty && m.id == message.id,
      );
      if (existingIndex >= 0) {
        result[existingIndex] = message;
        continue;
      }

      // Reconcile an optimistic echo (same sender + content) with the row the
      // backend just persisted, instead of appending a duplicate.
      final pendingIndex = result.indexWhere(
        (m) =>
            m.pending &&
            m.senderId == message.senderId &&
            m.content == message.content,
      );
      if (pendingIndex >= 0) {
        result[pendingIndex] = message;
        continue;
      }

      result.add(message);
    }

    result.sort((a, b) {
      final byTime = a.createdAt.compareTo(b.createdAt);
      if (byTime != 0) return byTime;
      // Tie-break with the id so ordering is stable when the server clock
      // returns the same millisecond for several rows.
      return a.id.compareTo(b.id);
    });
    return result;
  }

  bool _replacesPending(List<ChatMessage> before, List<ChatMessage> after) {
    if (after.length != before.length) return true;
    for (var i = 0; i < after.length; i++) {
      if (after[i].id != before[i].id) return true;
    }
    return false;
  }

  @override
  Future<void> close() async {
    _socket?.unsubscribe(messageEvent);
    await _eventsSub?.cancel();
    await _connectionSub?.cancel();
    return super.close();
  }
}
