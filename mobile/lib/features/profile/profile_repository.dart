import '../../core/network/api_client.dart';
import '../../core/network/api_url.dart';
import '../../models/call.dart';
import '../../models/profile.dart';

class ProfileRepository {
  ProfileRepository(this._api);

  final ApiClient _api;

  Future<UserProfile> getMe() async {
    final data = await _api.get(APIURL.usersMe);
    return UserProfile.fromJson(
      ((data as Map)['user'] as Map).cast<String, dynamic>(),
    );
  }

  Future<UserProfile> updateProfile(Map<String, dynamic> patch) async {
    final data = await _api.patch(APIURL.usersMe, data: patch);
    return UserProfile.fromJson(
      ((data as Map)['user'] as Map).cast<String, dynamic>(),
    );
  }

  Future<List<Interest>> listInterests() async {
    final data = await _api.get(APIURL.usersInterests);
    return (data as List)
        .map((e) => Interest.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<PublicProfile> getPublicProfile(String userId) async {
    final data = await _api.get(APIURL.userPublic(userId));
    return PublicProfile.fromJson(
      ((data as Map)['profile'] as Map).cast<String, dynamic>(),
    );
  }

  Future<String> uploadAvatarWithBase64(
    String base64, {
    String contentType = 'image/jpeg',
  }) async {
    final data = await _api.post(
      APIURL.avatarUpload,
      data: {'base64': base64, 'contentType': contentType},
    );
    final map = (data as Map).cast<String, dynamic>();
    if (map['success'] != true || map['url'] == null) {
      throw ApiErrorException(map['message'] as String? ?? 'Upload failed');
    }
    return map['url'] as String;
  }

  Future<void> blockUser(String userId) async {
    await _api.post(APIURL.blockUser(userId), data: {'source': 'PROFILE'});
  }

  Future<void> unblockUser(String userId) async {
    await _api.delete(APIURL.blockUser(userId));
  }

  Future<List<BlockedUser>> listBlocks() async {
    final data = await _api.get(APIURL.listBlocks);
    return (data as Map)['blocks']
        .map((e) => BlockedUser.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> reportUser(
    String userId, {
    required String reason,
    String? description,
  }) async {
    await _api.post(
      APIURL.reportUser(userId),
      data: {
        'reason': reason,
        if (description != null && description.isNotEmpty)
          'description': description,
      },
    );
  }
}

class ApiErrorException implements Exception {
  const ApiErrorException(this.message);
  final String message;
}
