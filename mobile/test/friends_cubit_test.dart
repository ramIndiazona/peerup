import 'package:flutter_test/flutter_test.dart';
import 'package:peerup/core/network/api_exception.dart';
import 'package:peerup/core/realtime/realtime_connection_state.dart';
import 'package:peerup/features/friends/bloc/friends_cubit.dart';
import 'package:peerup/features/friends/friends_repository.dart';

import 'support/fakes.dart';

Map<String, dynamic> _friend(
  String id, {
  String name = 'Alex',
  bool online = true,
}) => {'id': id, 'name': name, 'avatar': 'avatar_01', 'online': online};

void main() {
  late StubApiClient api;
  late FriendsCubit cubit;
  late FakeRealtimeBus bus;

  FriendsCubit build() => FriendsCubit(
    repo: FriendsRepository(api),
    socket: bus,
    currentUserId: () => 'me',
  );

  setUp(() {
    api = StubApiClient();
    bus = FakeRealtimeBus();
    cubit = build();
  });

  tearDown(() async {
    await cubit.close();
    await bus.dispose();
  });

  test('loads accepted friends', () async {
    api.onGet =
        (path, query) async => {
          'items': [_friend('u1'), _friend('u2', online: false)],
          'total': 2,
        };

    await cubit.load();

    expect(cubit.state.isLoaded, isTrue);
    expect(cubit.state.value, hasLength(2));
    expect(cubit.state.value!.first.id, 'u1');
    expect(api.calls.single.path, 'friend-requests/friends');
  });

  test('deduplicates friends returned more than once', () async {
    api.onGet =
        (path, query) async => {
          'items': [_friend('u1'), _friend('u1'), _friend('u2')],
          'total': 3,
        };

    await cubit.load();

    expect(cubit.state.value, hasLength(2));
    expect(cubit.state.value!.map((f) => f.id).toSet(), {'u1', 'u2'});
  });

  test('empty friends list loads as an empty collection', () async {
    api.onGet = (path, query) async => {'items': [], 'total': 0};

    await cubit.load();

    expect(cubit.state.isLoaded, isTrue);
    expect(cubit.state.value, isEmpty);
  });

  test('surfaces API errors', () async {
    api.onGet = (path, query) async {
      throw const ApiException('HTTP_500', 'boom', statusCode: 500);
    };

    await cubit.load();

    expect(cubit.state.hasError, isTrue);
  });

  test('parses the nested friends envelope used by friend-requests', () async {
    api.onGet =
        (path, query) async => {
          'items': [
            {
              'id': 'fr1',
              'sender': {
                'id': 'me',
                'profile': {'name': 'Me', 'avatar': null},
              },
              'receiver': {
                'id': 'peer',
                'profile': {'name': 'Peer', 'avatar': 'avatar_02'},
              },
            },
          ],
          'total': 1,
        };

    await cubit.load();

    final friend = cubit.state.value!.single;
    expect(friend.id, 'peer');
    expect(friend.name, 'Peer');
    expect(friend.avatar, 'avatar_02');
  });

  test('a FRIENDSHIP_CREATED event triggers a refresh', () async {
    api.onGet =
        (path, query) async => {
          'items': [_friend('u1')],
          'total': 1,
        };
    await cubit.load();
    expect(api.countOf('GET'), 1);

    expect(bus.subscribed, contains('FRIENDSHIP_CREATED'));
    bus.emit('FRIENDSHIP_CREATED', {'friendId': 'u2'});
    await flushStreams();

    expect(api.countOf('GET'), 2);
  });

  test('reconnect reloads the friends list', () async {
    api.onGet = (path, query) async => {'items': [], 'total': 0};
    await cubit.load();
    expect(api.countOf('GET'), 1);

    bus.setConnection(RealtimeConnectionState.connected);
    await flushStreams();

    expect(api.countOf('GET'), 2);
  });
}
