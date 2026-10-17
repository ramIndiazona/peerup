import 'package:flutter_test/flutter_test.dart';
import 'package:peerup/core/network/api_exception.dart';
import 'package:peerup/features/chat/bloc/chat_cubit.dart';
import 'package:peerup/features/chat/chat_repository.dart';

import 'support/fakes.dart';

Map<String, dynamic> _message(
  String id, {
  required String senderId,
  required String content,
  String conversationId = 'c1',
  DateTime? at,
}) => {
  'id': id,
  'conversationId': conversationId,
  'senderId': senderId,
  'content': content,
  'messageType': 'TEXT',
  'createdAt': (at ?? DateTime.now()).toIso8601String(),
};

/// Raw Prisma conversation row as returned by `POST /conversations`.
Map<String, dynamic> _conversation(String peerId, {String me = 'me'}) => {
  'id': 'c1',
  'userAId': me,
  'userBId': peerId,
  'userA': {
    'id': me,
    'profile': {'name': 'Me', 'avatar': null},
  },
  'userB': {
    'id': peerId,
    'profile': {'name': 'Peer', 'avatar': 'avatar_02'},
  },
};

void main() {
  late StubApiClient api;
  late ChatCubit cubit;

  ChatCubit build() => ChatCubit(
    repo: ChatRepository(api),
    friendId: 'peer',
    socket: null,
    currentUserId: 'me',
  );

  setUp(() {
    api = StubApiClient();
    api.onPost = (path, data) async {
      if (path == 'conversations') {
        return _conversation(data['friendId'] ?? 'peer');
      }
      // send message
      return _message('s-$data', senderId: 'me', content: data['content']);
    };
    api.onGet =
        (path, query) async => [
          _message('h1', senderId: 'peer', content: 'hello'),
        ];
    cubit = build();
  });

  tearDown(() async {
    await cubit.close();
  });

  test('open resolves the conversation and loads history', () async {
    await cubit.open();

    expect(cubit.state.isLoaded, isTrue);
    expect(cubit.state.conversationId, 'c1');
    expect(cubit.state.messages, hasLength(1));
    expect(cubit.state.messages.single.content, 'hello');

    // Contract: POST /conversations must send `friendId`, not `peerId`.
    final create = api.calls.firstWhere(
      (c) => c.method == 'POST' && c.path == 'conversations',
    );
    expect((create.data as Map).containsKey('friendId'), isTrue);
    expect((create.data as Map).containsKey('peerId'), isFalse);

    // Contract: history uses the `limit` cursor, not `page`.
    final history = api.calls.firstWhere((c) => c.method == 'GET');
    expect(history.query!.containsKey('limit'), isTrue);
    expect(history.query!.containsKey('page'), isFalse);
  });

  test('open surfaces errors', () async {
    api.onPost = (path, data) async {
      throw const ApiException('HTTP_500', 'boom', statusCode: 500);
    };

    await cubit.open();

    expect(cubit.state.hasError, isTrue);
  });

  test(
    'send adds an optimistic message then reconciles with the server id',
    () async {
      await cubit.open();

      final future = cubit.send('hi there');
      // Optimistic echo is visible immediately.
      expect(cubit.state.messages.last.pending, isTrue);
      expect(cubit.state.sending, isTrue);

      await future;

      final mine = cubit.state.messages.where((m) => m.content == 'hi there');
      expect(mine, hasLength(1));
      expect(mine.single.pending, isFalse);
      expect(mine.single.id, isNot(startsWith('local-')));
      expect(cubit.state.sending, isFalse);
    },
  );

  test(
    'a send failure marks the message failed without auto-retrying',
    () async {
      await cubit.open();
      api.onPost = (path, data) async {
        throw const ApiException('NETWORK_ERROR', 'offline');
      };

      await cubit.send('nope');

      final failed = cubit.state.messages.where((m) => m.content == 'nope');
      expect(failed, hasLength(1));
      expect(failed.single.failed, isTrue);
      expect(failed.single.pending, isFalse);
    },
  );

  test('empty / whitespace-only sends are ignored', () async {
    await cubit.open();
    api.onPost = (path, data) async => fail('should not send');

    await cubit.send('   ');

    expect(cubit.state.messages, hasLength(1));
  });

  test(
    'a duplicate socket event (same id) does not create a duplicate',
    () async {
      final bus = FakeRealtimeBus();
      final socketCubit = ChatCubit(
        repo: ChatRepository(api),
        friendId: 'peer',
        socket: bus,
        currentUserId: 'me',
      );
      await socketCubit.open();

      bus.emit('CHAT_MESSAGE', _message('m9', senderId: 'peer', content: 'ping'));
      await flushStreams();
      expect(
        socketCubit.state.messages.where((m) => m.id == 'm9'),
        hasLength(1),
      );

      bus.emit('CHAT_MESSAGE', _message('m9', senderId: 'peer', content: 'ping'));
      await flushStreams();
      expect(
        socketCubit.state.messages.where((m) => m.id == 'm9'),
        hasLength(1),
      );

      await socketCubit.close();
      await bus.dispose();
    },
  );

  test('subscribes to CHAT_MESSAGE on the shared socket', () async {
    final bus = FakeRealtimeBus();
    final socketCubit = ChatCubit(
      repo: ChatRepository(api),
      friendId: 'peer',
      socket: bus,
      currentUserId: 'me',
    );
    await socketCubit.open();

    expect(bus.subscribed, contains('CHAT_MESSAGE'));

    await socketCubit.close();
    expect(bus.unsubscribed, contains('CHAT_MESSAGE'));
    await bus.dispose();
  });

  test('socket messages for other conversations are ignored', () async {
    final bus = FakeRealtimeBus();
    final socketCubit = ChatCubit(
      repo: ChatRepository(api),
      friendId: 'peer',
      socket: bus,
      currentUserId: 'me',
    );
    await socketCubit.open();

    bus.emit(
      'CHAT_MESSAGE',
      _message(
        'other',
        senderId: 'peer',
        content: 'elsewhere',
        conversationId: 'c-other',
      ),
    );
    await flushStreams();

    expect(socketCubit.state.messages.any((m) => m.id == 'other'), isFalse);

    await socketCubit.close();
    await bus.dispose();
  });

  test('reloadHistory merges missed messages after reconnect', () async {
    await cubit.open();

    api.onGet =
        (path, query) async => [
          _message('h1', senderId: 'peer', content: 'hello'),
          _message('h2', senderId: 'peer', content: 'missed you'),
        ];

    await cubit.reloadHistory();

    expect(cubit.state.messages.map((m) => m.id), containsAll(['h1', 'h2']));
    expect(cubit.state.messages, hasLength(2));
  });

  test('loadOlder prepends older messages and uses the before cursor', () async {
    // A full first page means there may be older messages.
    final page = List.generate(
      ChatCubit.pageSize,
      (i) => _message(
        'p$i',
        senderId: 'peer',
        content: 'm$i',
        at: DateTime.now().add(Duration(seconds: i)),
      ),
    );
    api.onGet = (path, query) async => page;

    await cubit.open();
    expect(cubit.state.hasMore, isTrue);

    api.onGet = (path, query) async => [
      _message(
        'old1',
        senderId: 'peer',
        content: 'older',
        at: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];

    await cubit.loadOlder();

    expect(cubit.state.messages.first.id, 'old1');
    expect(cubit.state.hasMore, isFalse);

    final older = api.calls.last;
    expect(older.query!.containsKey('before'), isTrue);
  });
}
