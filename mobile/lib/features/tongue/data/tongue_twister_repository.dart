import 'package:peerup/core/network/api_client.dart';
import 'package:peerup/core/network/api_url.dart';

import '../../../models/tongue_twister.dart';

class TongueTwisterRepository {
  TongueTwisterRepository(this._api);

  final ApiClient _api;

  Future<List<TongueTwister>> fetchTongueTwisters() async {
    final response = await _api.get(APIURL.tongueTwisters);

    // Your API returns a List directly, not a Dio Response.
    final dynamic responseData = response;

    final List<dynamic> items;

    if (responseData is List) {
      items = responseData;
    } else if (responseData is Map && responseData['data'] is List) {
      items = responseData['data'] as List<dynamic>;
    } else {
      throw Exception(
        'Unexpected tongue twisters response: '
        '${responseData.runtimeType}',
      );
    }

    return items.map((item) {
      return TongueTwister.fromJson(Map<String, dynamic>.from(item as Map));
    }).toList();
  }
}
