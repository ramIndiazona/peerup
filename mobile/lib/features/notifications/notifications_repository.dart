import '../../core/network/api_client.dart';
import '../../core/network/api_url.dart';
import '../../models/app_notification.dart';

class NotificationsRepository {
  NotificationsRepository(this._api);

  final ApiClient _api;

  Future<NotificationListResult> list({int page = 1, int limit = 20}) async {
    final data = await _api.get(
      APIURL.notificationsList,
      query: {'page': page, 'limit': limit},
    );
    return NotificationListResult.fromJson(
      (data as Map).cast<String, dynamic>(),
    );
  }

  Future<void> markRead(String id) async {
    await _api.patch(APIURL.notificationMarkRead(id));
  }

  Future<void> registerDeviceToken(String token, String platform) async {
    await _api.post(
      APIURL.notificationsDeviceToken,
      data: {'token': token, 'platform': platform},
    );
  }
}
