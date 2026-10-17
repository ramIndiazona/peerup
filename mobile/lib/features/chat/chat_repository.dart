import '../../core/network/api_client.dart';
import '../../core/network/api_url.dart';
import '../../models/chat.dart';

/// HTTP access to one-to-one conversations and messages.
///
/// Backend contract (verified against `backend/src/conversations/`):
///
///   1. Get or create a conversation with an accepted friend
///      POST /conversations      { "friendId": "friendUserId" }
///      200 {
///        "id": "conversationId",
///        "userAId": "uuid", "userBId": "uuid",
///        "userA": { "id": "uuid", "profile": { "name", "avatar" } },
///        "userB": { "id": "uuid", "profile": { "name", "avatar" } }
///      }
///
///      The id pair is normalized server-side (`[userId, friendId].sort()`),
///      so A→B and B→A resolve to the same row. Rejected for non-friends and
///      for blocked users (403).
///
///      NOTE: the request field is `friendId`, not `peerId`.
///
///   2. Paginated history (oldest→newest within a page)
///      GET /conversations/:id/messages?limit=50&before=ISO_DATE
///      200 [ { "id","conversationId","senderId","content","messageType",
///              "createdAt","readAt" }, ... ]
///
///      A bare JSON array; the newest page is returned when `before` is
///      omitted. Older pages are requested by passing the `createdAt` of the
///      oldest message already shown. `limit` is clamped to 1..100.
///
///   3. Persist a new message
///      POST /conversations/:id/messages   { "content": "hi" }
///      201 { "id","conversationId","senderId","content","messageType",
///            "createdAt","readAt" }
///
/// Real-time delivery is on the shared socket as `CHAT_MESSAGE` with the same
/// message object as the payload (see ChatCubit). Sending is done over HTTP so
/// the server assigns the canonical id and the same id de-duplicates the echo.

class ChatRepository {
  ChatRepository(this._api);

  final ApiClient _api;

  /// Server-side maximum page size accepted by the backend history endpoint.
  static const int maxPageSize = 100;

  Future<Conversation> getOrCreateConversation(String friendId) async {
    final data = await _api.post(
      APIURL.conversations,
      data: {'friendId': friendId},
    );
    final map = _asMap(data);

    // Tolerate an envelope ({ "conversation": {...} }) even though the
    // backend currently returns the Prisma row directly.
    final envelope = map['conversation'];
    final source = envelope is Map
        ? Map<String, dynamic>.from(envelope)
        : map;

    return Conversation.fromJson(source, peerId: friendId);
  }

  /// One page of history, oldest→newest.
  ///
  /// Omit [before] to fetch the newest page. To page further back, pass the
  /// `createdAt` of the oldest message currently rendered.
  Future<ChatHistoryPage> history(
    String conversationId, {
    int limit = 50,
    DateTime? before,
  }) async {
    final data = await _api.get(
      APIURL.conversationMessages(conversationId),
      query: {
        'limit': limit.clamp(1, maxPageSize),
        if (before != null) 'before': before.toUtc().toIso8601String(),
      },
    );
    return ChatHistoryPage.fromJson(
      _asMap(data, listKey: 'items'),
      conversationId: conversationId,
    );
  }

  Future<ChatMessage> sendMessage(String conversationId, String content) async {
    final data = await _api.post(
      APIURL.conversationMessages(conversationId),
      data: {'content': content},
    );
    final map = _asMap(data);
    final message = map['message'];
    if (message is Map) {
      return ChatMessage.fromJson(
        Map<String, dynamic>.from(message),
        fallbackConversationId: conversationId,
      );
    }
    return ChatMessage.fromJson(map, fallbackConversationId: conversationId);
  }

  Map<String, dynamic> _asMap(dynamic data, {String? listKey}) {
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is List && listKey != null) return {listKey: data};
    return <String, dynamic>{};
  }
}
