import '../../core/network/api_client.dart';
import '../../core/network/api_url.dart';
import '../../models/friend.dart';

/// Read access to the current user's accepted friendships.
///
/// Backend contract (currently MISSING in the NestJS backend — documented as
/// a requirement):
///
///   GET /friends?page=1&limit=50
///   200 {
///     "items": [
///       {
///         "id": "friendUserId",
///         "name": "Alex",
///         "avatar": "avatar_03",
///         "online": true,
///         "lastMessage": { "content": "hey", "createdAt": "..." }
///       }
///     ],
///     "total": 1
///   }
///
/// Only ACCEPTED friendships may be returned. Pending (sent or received)
/// requests must never appear here. The parser also accepts the
/// `{ user: { id, profile: { name, avatar } } }` envelope used by the
/// existing `friend-requests/*` endpoints.

class FriendsRepository {
  FriendsRepository(this._api);

  final ApiClient _api;

  Future<FriendsPage> list({
    int page = 1,
    int limit = 50,
    String? currentUserId,
  }) async {
    final data = await _api.get(
      APIURL.friendsList,
      query: {'page': page, 'limit': limit},
    );
    final map =
        data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    if (data is List) {
      return FriendsPage.fromJson({
        'items': data,
      }, currentUserId: currentUserId);
    }
    return FriendsPage.fromJson(map, currentUserId: currentUserId);
  }

  Future<dynamic> sendFriendRequest({
    required String receiverId,
    required String? reaction,
    required List<String> feedback,
    required bool addToFriends,
    required bool connectAgain,
  }) async {
    return _api.post(
      APIURL.addfriends,
      data: {
        'receiverId': receiverId,
        'reaction': reaction,
        'feedback': feedback,
        'addToFriends': addToFriends,
        'connectAgain': connectAgain,
      },
    );
  }
}
