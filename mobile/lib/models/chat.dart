/// One persisted chat message.
///
/// Mirrors the Prisma `Message` row written by the NestJS
/// `ConversationsService`. The legacy `DirectMessage` model uses a `text`
/// column, so `text` is still accepted as a fallback when parsing.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.readAt,
    this.pending = false,
    this.failed = false,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final DateTime? readAt;

  /// True while an optimistic local echo has not yet been confirmed by the
  /// backend. Never treated as delivered until the server row arrives.
  final bool pending;

  /// True when sending failed and the message will not be retried
  /// automatically (non-idempotent send).
  final bool failed;

  bool get isRead => readAt != null;

  ChatMessage copyWith({DateTime? readAt, bool? pending, bool? failed}) {
    return ChatMessage(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      content: content,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
      pending: pending ?? this.pending,
      failed: failed ?? this.failed,
    );
  }

  factory ChatMessage.fromJson(
    Map<String, dynamic> json, {
    String? fallbackConversationId,
  }) {
    final content = json['content'] ?? json['text'] ?? '';
    return ChatMessage(
      id: (json['id'] ?? '').toString(),
      conversationId:
          (json['conversationId'] ?? fallbackConversationId ?? '').toString(),
      senderId: (json['senderId'] ?? '').toString(),
      content: content is String ? content : content.toString(),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      readAt:
          json['readAt'] is String
              ? DateTime.tryParse(json['readAt'] as String)
              : null,
    );
  }
}

/// A one-to-one conversation returned by the backend.
///
/// `POST /conversations` returns the raw Prisma row:
///
/// ```json
/// {
///   "id": "...", "userAId": "uuid", "userBId": "uuid",
///   "userA": { "id": "uuid", "profile": { "name": "...", "avatar": "..." } },
///   "userB": { "id": "uuid", "profile": { "name": "...", "avatar": "..." } }
/// }
/// ```
///
/// There is no `peerId` field on the wire, so the peer (the *other* user) is
/// resolved from [peerId] — the friend this conversation was opened for — or,
/// failing that, from [currentUserId] by elimination.
class Conversation {
  const Conversation({
    required this.id,
    required this.peerId,
    this.peerName,
    this.peerAvatar,
  });

  final String id;
  final String peerId;
  final String? peerName;
  final String? peerAvatar;

  factory Conversation.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
    String? peerId,
  }) {
    final envelope = _asMap(json['peer'] ?? json['user'] ?? json['otherUser']);
    final envelopeProfile = _asMap(envelope?['profile']);

    final participant = _resolveParticipant(
      json,
      currentUserId: currentUserId,
      peerId: peerId,
    );
    final participantProfile = _asMap(participant?['profile']);

    final resolvedPeerId =
        peerId ??
        json['peerId'] ??
        participant?['id'] ??
        envelope?['id'] ??
        json['userId'] ??
        '';

    String? name;
    String? avatar;
    if (participant != null) {
      name = (participant['name'] ?? participantProfile?['name'])?.toString();
      avatar =
          (participant['avatar'] ?? participantProfile?['avatar'])?.toString();
    } else {
      name = (json['peerName'] ?? envelope?['name'] ?? envelopeProfile?['name'])
          ?.toString();
      avatar =
          (json['peerAvatar'] ??
                  envelope?['avatar'] ??
                  envelopeProfile?['avatar'])
              ?.toString();
    }

    return Conversation(
      id: (json['id'] ?? '').toString(),
      peerId: resolvedPeerId.toString(),
      peerName: name,
      peerAvatar: avatar,
    );
  }

  /// Pick `userB` if it is the peer (or, when only `currentUserId` is known,
  /// the participant who is not the current user).
  static Map<String, dynamic>? _resolveParticipant(
    Map<String, dynamic> json, {
    String? currentUserId,
    String? peerId,
  }) {
    final userA = _asMap(json['userA']);
    final userB = _asMap(json['userB']);
    if (userA == null || userB == null) return null;

    if (peerId != null) {
      if (userA['id'] == peerId) return userA;
      if (userB['id'] == peerId) return userB;
    }
    if (currentUserId != null) {
      return userA['id'] == currentUserId ? userB : userA;
    }
    return null;
  }

  static Map<String, dynamic>? _asMap(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : null;
}

/// One page of message history.
///
/// The backend answers `GET /conversations/:id/messages` with a **bare JSON
/// array** ordered oldest→newest; [ChatRepository] wraps it as `items` before
/// handing it to this parser. `total` falls back to the page size because the
/// backend exposes a `before` cursor rather than a total count.
class ChatHistoryPage {
  const ChatHistoryPage({required this.items, required this.total});

  final List<ChatMessage> items;
  final int total;

  factory ChatHistoryPage.fromJson(
    Map<String, dynamic> json, {
    String? conversationId,
  }) {
    final raw = json['items'] ?? json['messages'] ?? json['data'];
    final list = raw is List ? raw : const [];
    return ChatHistoryPage(
      items:
          list
              .whereType<Map>()
              .map(
                (e) => ChatMessage.fromJson(
                  e.cast<String, dynamic>(),
                  fallbackConversationId: conversationId,
                ),
              )
              .toList(),
      total: (json['total'] as num?)?.toInt() ?? list.length,
    );
  }
}
