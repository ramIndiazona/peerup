import '../../models/call.dart';
import '../network/api_client.dart';
import '../network/api_url.dart';

class CallRepository {
  CallRepository(this._api);

  final ApiClient _api;

  Future<CallDetails> getCall(String callId) async {
    final data = await _api.get(APIURL.callDetails(callId));
    return CallDetails.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<void> endCall(String callId) async {
    await _api.post(APIURL.callEnd(callId));
  }

  Future<void> reportCall(
    String callId, {
    required String reason,
    String? description,
  }) async {
    await _api.post(
      APIURL.callReport(callId),
      data: {
        'reason': reason,
        if (description != null && description.isNotEmpty)
          'description': description,
      },
    );
  }
}
