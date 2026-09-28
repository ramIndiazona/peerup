import '../../core/network/api_client.dart';
import '../../core/network/api_url.dart';
import '../../models/ai.dart';

class AIRepository {
  AIRepository(this._api);

  final ApiClient _api;

  Future<List<AICharacter>> listCharacters({bool premium = false}) async {
    final data = await _api.get(
      APIURL.aiCharacters,
      query: {if (premium) 'premium': 'true'},
    );
    return ((data as Map)['characters'] as List)
        .map((e) => AICharacter.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  // Future<List<String>> listScenarios() async {
  //   final data = await _api.get(APIURL.aiScenarios);
  //   return ((data as Map)['scenarios'] as List).cast<String>();
  // }

  Future<List<String>> listScenarios() async {
    final data = await _api.get(APIURL.aiScenarios);

    if (data is! Map) {
      throw const FormatException(
        'Invalid AI scenarios response: expected an object',
      );
    }

    final scenarios = data['scenarios'];

    if (scenarios == null) {
      return const [];
    }

    if (scenarios is! List) {
      throw FormatException(
        'Invalid AI scenarios response: expected a List, '
        'got ${scenarios.runtimeType}',
      );
    }

    return scenarios
        .whereType<String>()
        .where((item) => item.trim().isNotEmpty)
        .toList();
  }

  Future<AIStartResult> startSession({
    String? characterId,
    String? scenario,
  }) async {
    final data = await _api.post(
      APIURL.aiSessions,
      data: {
        if (characterId != null) 'characterId': characterId,
        if (scenario != null) 'scenario': scenario,
      },
    );
    return AIStartResult.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<String> sendMessage(
    String sessionId, {
    String? text,
    String? audioBase64,
    String? mime,
    int? durationSeconds,
  }) async {
    final data = await _api.post(
      APIURL.aiSessionMessage(sessionId),
      data: {
        if (text != null && text.isNotEmpty) 'text': text,
        if (audioBase64 != null) 'audioBase64': audioBase64,
        if (mime != null) 'mime': mime,
        if (durationSeconds != null) 'durationSeconds': durationSeconds,
      },
    );
    return ((data as Map)['reply'] as String?) ?? '';
  }

  Future<void> endSession(String sessionId) async {
    await _api.post(APIURL.aiSessionEnd(sessionId));
  }

  Future<dynamic> getFeedback(String sessionId) async {
    return _api.get(APIURL.aiSessionFeedback(sessionId));
  }
}
