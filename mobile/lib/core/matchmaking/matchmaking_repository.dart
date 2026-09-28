import '../../models/matchmaking.dart';
import '../network/api_client.dart';
import '../network/api_url.dart';

/// REST-only matchmaking repository. The start/cancel/status calls are durable
/// HTTP requests; realtime delivery (MATCH_FOUND, ...) arrives over WS and is
/// handled by [MatchmakingService].
class MatchmakingRepository {
  MatchmakingRepository(this._api);

  final ApiClient _api;

  Future<void> start(MatchFilters filters) async {
    await _api.post(APIURL.matchmakingStart, data: filters.toJson());
  }

  Future<void> cancel() async {
    await _api.post(APIURL.matchmakingCancel);
  }

  Future<MatchStatusResult> status() async {
    final data = await _api.post(APIURL.matchmakingStatus);
    return MatchStatusResult.fromJson((data as Map).cast<String, dynamic>());
  }
}
