import 'package:flutter_test/flutter_test.dart';
import 'package:peerup/core/network/api_exception.dart';
import 'package:peerup/core/realtime/realtime_connection_state.dart';
import 'package:peerup/features/notifications/bloc/notifications_cubit.dart';
import 'package:peerup/features/notifications/notifications_repository.dart';

import 'support/fakes.dart';

Map<String, dynamic> _row(
  String id, {
  String type = 'SYSTEM',
  String? readAt,
}) => {
  'id': id,
  'type': type,
  'title': 'Title $id',
  'body': 'Body $id',
  'data': {'kind': 'FRIENDSHIP_CREATED'},
  'readAt': readAt,
  'createdAt': DateTime.now().toIso8601String(),
};

Map<String, dynamic> _friendRequestRow(String id, String requestId) => {
  'id': id,
  'type': 'SYSTEM',
  'title': 'Friend request',
  'body': 'Alex wants to add you as a friend.',
  'data': {
    'kind': 'FRIEND_REQUEST',
    'requestId': requestId,
    'senderId': 'u1',
  },
  'readAt': null,
  'createdAt': DateTime.now().toIso8601String(),
};

void main() {
  late StubApiClient api;
  late NotificationsCubit cubit;
  late FakeRealtimeBus bus;

  setUp(() {
    api = StubApiClient();
    bus = FakeRealtimeBus();
    cubit = NotificationsCubit(repo: NotificationsRepository(api), socket: bus);
  });

  tearDown(() async {
    await cubit.close();
    await bus.dispose();
  });

  test('loads notifications and derives the unread count', () async {
    api.onGet =
        (path, query) async => {
          'items': [
            _row('1'),
            _row('2', readAt: DateTime.now().toIso8601String()),
          ],
          'total': 2,
        };

    await cubit.load();

    expect(cubit.state.isLoaded, isTrue);
    expect(cubit.state.items, hasLength(2));
    expect(cubit.state.unreadCount, 1);
    expect(api.calls.single.path, 'notifications');
    expect(api.calls.single.query?['page'], 1);
  });

  test('emits an error state when loading fails', () async {
    api.onGet = (path, query) async {
      throw const ApiException('HTTP_500', 'boom', statusCode: 500);
    };

    await cubit.load();

    expect(cubit.state.hasError, isTrue);
    expect(cubit.state.error, isA<ApiException>());
  });

  test('a NOTIFICATION_CREATED event is added once (no duplicates)', () async {
    api.onGet = (path, query) async => {'items': [], 'total': 0};
    await cubit.load();

    expect(bus.subscribed, contains('NOTIFICATION_CREATED'));

    bus.emit('NOTIFICATION_CREATED', {'notification': _row('n1')});
    await flushStreams();
    expect(cubit.state.items, hasLength(1));
    expect(cubit.state.unreadCount, 1);

    // Same event delivered again (reconnect / duplicate fan-out).
    bus.emit('NOTIFICATION_CREATED', {'notification': _row('n1')});
    await flushStreams();
    expect(cubit.state.items, hasLength(1));
    expect(cubit.state.unreadCount, 1);
  });

  test('malformed notification payloads are ignored', () async {
    api.onGet = (path, query) async => {'items': [], 'total': 0};
    await cubit.load();

    bus.emit('NOTIFICATION_CREATED', {
      'notification': {'no': 'id'},
    });
    await flushStreams();

    expect(cubit.state.items, isEmpty);
  });

  test('markRead updates the unread badge locally', () async {
    api.onGet =
        (path, query) async => {
          'items': [_row('1'), _row('2')],
          'total': 2,
        };
    var patched = 0;
    api.onPatch = (path, data) async {
      patched++;
      return {'success': true};
    };

    await cubit.load();
    expect(cubit.state.unreadCount, 2);

    await cubit.markRead('1');

    expect(patched, 1);
    expect(cubit.state.unreadCount, 1);
    expect(cubit.state.items.firstWhere((n) => n.id == '1').isRead, isTrue);
  });

  test('markAllRead clears every unread notification', () async {
    api.onGet =
        (path, query) async => {
          'items': [_row('1'), _row('2')],
          'total': 2,
        };
    var patched = 0;
    api.onPatch = (path, data) async {
      patched++;
      return {'success': true};
    };

    await cubit.load();
    await cubit.markAllRead();

    expect(patched, 2);
    expect(cubit.state.unreadCount, 0);
  });

  test('accepts a friend request notification and resolves its action', () async {
    api.onGet =
        (path, query) async => {
          'items': [_friendRequestRow('n1', 'req-1')],
          'total': 1,
        };
    api.onPost = (path, data) async => {'status': 'FRIENDS'};

    await cubit.load();
    final notification = cubit.state.items.single;

    final ok = await cubit.acceptFriendRequest(notification);

    expect(ok, isTrue);
    expect(api.calls.last.method, 'POST');
    expect(api.calls.last.path, 'friend-requests/req-1/accept');
    expect(
      cubit.state.items.single.data?['kind'],
      'FRIEND_REQUEST_ACCEPTED',
    );
    expect(cubit.state.items.single.isRead, isTrue);
  });

  test('keeps the notification action when accepting fails', () async {
    api.onGet =
        (path, query) async => {
          'items': [_friendRequestRow('n1', 'req-1')],
          'total': 1,
        };
    api.onPost = (path, data) async {
      throw const ApiException('HTTP_500', 'boom', statusCode: 500);
    };

    await cubit.load();
    final ok = await cubit.acceptFriendRequest(cubit.state.items.single);

    expect(ok, isFalse);
    expect(cubit.state.items.single.data?['kind'], 'FRIEND_REQUEST');
    expect(cubit.state.error, isA<ApiException>());
  });

  test('reconnect reloads the list to pick up missed notifications', () async {
    api.onGet = (path, query) async => {'items': [], 'total': 0};
    await cubit.load();
    expect(api.countOf('GET'), 1);

    bus.setConnection(RealtimeConnectionState.connected);
    await flushStreams();

    expect(api.countOf('GET'), 2);
  });
}
