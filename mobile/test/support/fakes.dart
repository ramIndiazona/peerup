import 'dart:async';

import 'package:dio/dio.dart';
import 'package:peerup/core/auth/token_manager.dart';
import 'package:peerup/core/network/api_client.dart';
import 'package:peerup/core/realtime/realtime_connection_state.dart';
import 'package:peerup/core/realtime/realtime_event.dart';
import 'package:peerup/core/realtime/realtime_event_bus.dart';
import 'package:peerup/core/storage/token_storage.dart';

/// In-memory [TokenStorage] so tests never touch the platform keychain.
class FakeTokenStorage extends TokenStorage {
  String? access;
  String? refresh;
  String? user;

  @override
  Future<String?> get accessToken async => access;

  @override
  Future<String?> get refreshToken async => refresh;

  @override
  Future<String?> get cachedUser async => user;

  @override
  Future<bool> hasSession() async => access != null;

  @override
  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    this.access = access;
    this.refresh = refresh;
  }

  @override
  Future<void> saveUser(String json) async => user = json;

  @override
  Future<void> clear() async {
    access = null;
    refresh = null;
    user = null;
  }
}

/// A record of one HTTP call made through [StubApiClient].
class ApiCall {
  ApiCall(this.method, this.path, {this.query, this.data});

  final String method;
  final String path;
  final Map<String, dynamic>? query;
  final dynamic data;
}

/// [ApiClient] whose HTTP verbs are replaced by in-test handlers.
///
/// Used to exercise repositories (including their JSON parsing) with zero
/// network access.
class StubApiClient extends ApiClient {
  StubApiClient() : super(tokens: TokenManager(storage: FakeTokenStorage()));

  final List<ApiCall> calls = [];

  Future<dynamic> Function(String path, Map<String, dynamic>? query)? onGet;
  Future<dynamic> Function(String path, dynamic data)? onPost;
  Future<dynamic> Function(String path, dynamic data)? onPatch;
  Future<dynamic> Function(String path, dynamic data)? onDelete;

  int countOf(String method) => calls.where((c) => c.method == method).length;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    Options? options,
  }) {
    calls.add(ApiCall('GET', path, query: query));
    final handler = onGet;
    if (handler == null) {
      throw StateError('No onGet handler for $path');
    }
    return handler(path, query);
  }

  @override
  Future<dynamic> post(String path, {dynamic data, Options? options}) {
    calls.add(ApiCall('POST', path, data: data));
    final handler = onPost;
    if (handler == null) {
      throw StateError('No onPost handler for $path');
    }
    return handler(path, data);
  }

  @override
  Future<dynamic> patch(String path, {dynamic data, Options? options}) {
    calls.add(ApiCall('PATCH', path, data: data));
    final handler = onPatch;
    if (handler == null) {
      throw StateError('No onPatch handler for $path');
    }
    return handler(path, data);
  }

  @override
  Future<dynamic> delete(String path, {dynamic data, Options? options}) {
    calls.add(ApiCall('DELETE', path, data: data));
    final handler = onDelete;
    if (handler == null) {
      throw StateError('No onDelete handler for $path');
    }
    return handler(path, data);
  }
}

/// Controllable [RealtimeEventBus] for BLoC tests.
class FakeRealtimeBus implements RealtimeEventBus {
  final StreamController<RealtimeRawEvent> _serverEvents =
      StreamController<RealtimeRawEvent>.broadcast();
  final StreamController<RealtimeConnectionState> _connection =
      StreamController<RealtimeConnectionState>.broadcast();

  RealtimeConnectionState _state = RealtimeConnectionState.disconnected;

  final List<String> subscribed = [];
  final List<String> unsubscribed = [];

  @override
  Stream<RealtimeRawEvent> get serverEvents => _serverEvents.stream;

  @override
  Stream<RealtimeConnectionState> get connectionStateStream =>
      _connection.stream;

  @override
  RealtimeConnectionState get connectionState => _state;

  @override
  void subscribe(String event) => subscribed.add(event);

  @override
  void unsubscribe(String event) => unsubscribed.add(event);

  /// Push a named server event to listeners.
  void emit(String name, [Map<String, dynamic> data = const {}]) {
    _serverEvents.add(RealtimeRawEvent(name, data));
  }

  /// Change the connection state and notify listeners.
  void setConnection(RealtimeConnectionState state) {
    _state = state;
    _connection.add(state);
  }

  Future<void> dispose() async {
    await _serverEvents.close();
    await _connection.close();
  }
}

/// Lets pending microtasks/stream events run.
Future<void> flushStreams([int times = 4]) async {
  for (var i = 0; i < times; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
