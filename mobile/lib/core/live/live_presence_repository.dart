import '../network/api_client.dart';
import '../network/api_url.dart';

class LivePresenceRepository {
  LivePresenceRepository(this._api);

  final ApiClient _api;

  Future<void> liveStart() async {
    await _api.post(APIURL.liveStart);
  }

  Future<void> liveStop() async {
    await _api.post(APIURL.liveStop);
  }

  Future<int> liveCount() async {
    final data = await _api.get(APIURL.liveCount);
    return ((data as Map)['count'] as num?)?.toInt() ?? 0;
  }
}
