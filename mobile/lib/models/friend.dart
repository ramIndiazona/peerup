/// A single accepted friendship as presented to the UI.
///
/// The parser is intentionally forgiving about the exact backend envelope so
/// that it works with whichever accepted-friends contract the backend team
/// settles on. Resolution order for the counterpart identity:
///
///   1. `{ user | friend | otherUser: { id, profile: { name, avatar } } }`
///   2. `{ sender, receiver }` friendship rows (the entry whose id differs
///      from the current user is used)
///   3. the object itself (`{ id, name, avatar }`)
class Friend {
  const Friend({
    required this.id,
    required this.name,
    this.avatar,
    this.online = false,
    this.lastMessagePreview,
    this.lastMessageAt,
  });

  /// The friend's user id (never the current user's id).
  final String id;
  final String name;
  final String? avatar;
  final bool online;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;

  Friend copyWith({
    String? name,
    String? avatar,
    bool? online,
    String? lastMessagePreview,
    DateTime? lastMessageAt,
  }) {
    return Friend(
      id: id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      online: online ?? this.online,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    );
  }

  factory Friend.fromJson(Map<String, dynamic> json, {String? currentUserId}) {
    final profile = _resolveProfileSource(json, currentUserId);
    final nested = profile['profile'];

    String? readName() {
      if (profile['name'] is String) return profile['name'] as String;
      if (nested is Map && nested['name'] is String) {
        return nested['name'] as String;
      }
      return null;
    }

    String? readAvatar() {
      if (profile['avatar'] is String) return profile['avatar'] as String;
      if (nested is Map && nested['avatar'] is String) {
        return nested['avatar'] as String;
      }
      return null;
    }

    return Friend(
      id: (profile['id'] ?? profile['userId'] ?? json['id'] ?? '').toString(),
      name: readName() ?? 'Unknown',
      avatar: readAvatar(),
      online: _readOnline(json, profile),
      lastMessagePreview: _readLastMessagePreview(json),
      lastMessageAt: _readLastMessageAt(json),
    );
  }

  static Map<String, dynamic> _resolveProfileSource(
    Map<String, dynamic> json,
    String? currentUserId,
  ) {
    for (final key in const ['user', 'friend', 'otherUser', 'peer']) {
      final value = json[key];
      if (value is Map) return Map<String, dynamic>.from(value);
    }

    final sender = json['sender'];
    final receiver = json['receiver'];
    if (sender is Map || receiver is Map) {
      final senderMap =
          sender is Map ? Map<String, dynamic>.from(sender) : null;
      final receiverMap =
          receiver is Map ? Map<String, dynamic>.from(receiver) : null;

      if (currentUserId != null) {
        if (senderMap != null && senderMap['id'] != currentUserId) {
          return senderMap;
        }
        if (receiverMap != null && receiverMap['id'] != currentUserId) {
          return receiverMap;
        }
      }
      return senderMap ?? receiverMap ?? json;
    }

    return json;
  }

  static bool _readOnline(
    Map<String, dynamic> root,
    Map<String, dynamic> profile,
  ) {
    // for (final source in [profile, root]) {
    //   final online = source['online'] ?? source['isOnline'];
    //   if (online is bool) return online;
    //   final status = source['status'];
    //   if (status is String) {
    //     return status.toUpperCase() != 'OFFLINE';
    //   }
    // }

    for (final source in [profile, root]) {
      final value = source['online'] ?? source['isOnline'];

      if (value is bool) return value;
      if (value is num) return value == 1;

      if (value is String) {
        final normalized = value.toLowerCase();

        if (normalized == 'online' || normalized == 'true') {
          return true;
        }

        if (normalized == 'offline' || normalized == 'false') {
          return false;
        }
      }
    }
    return false;
  }

  static String? _readLastMessagePreview(Map<String, dynamic> json) {
    final last = json['lastMessage'];
    if (last is Map) {
      final content = last['content'] ?? last['text'];
      if (content is String && content.isNotEmpty) return content;
    }
    final preview = json['lastMessagePreview'];
    if (preview is String && preview.isNotEmpty) return preview;
    return null;
  }

  static DateTime? _readLastMessageAt(Map<String, dynamic> json) {
    final last = json['lastMessage'];
    if (last is Map && last['createdAt'] is String) {
      return DateTime.tryParse(last['createdAt'] as String);
    }
    if (json['lastMessageAt'] is String) {
      return DateTime.tryParse(json['lastMessageAt'] as String);
    }
    return null;
  }
}

/// Paginated friends response.
class FriendsPage {
  const FriendsPage({required this.items, required this.total});

  final List<Friend> items;
  final int total;

  factory FriendsPage.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    final raw = json['items'] ?? json['friends'] ?? json['data'];
    final items = raw is List ? raw : const [];
    return FriendsPage(
      items:
          items
              .whereType<Map>()
              .map(
                (e) => Friend.fromJson(
                  e.cast<String, dynamic>(),
                  currentUserId: currentUserId,
                ),
              )
              .toList(),
      total: (json['total'] as num?)?.toInt() ?? items.length,
    );
  }
}
