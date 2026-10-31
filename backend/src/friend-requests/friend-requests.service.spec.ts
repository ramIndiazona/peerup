import {
  CallReaction,
  FriendRequestStatus,
  NotificationType,
} from '@prisma/client';
import { FriendRequestsService } from './friend-requests.service';

type StoredFriendRequest = {
  id: string;
  senderId: string;
  receiverId: string;
  status: FriendRequestStatus;
  createdAt: Date;
  updatedAt: Date;
};

type StoredNotification = {
  id: string;
  userId: string;
  type: NotificationType;
  title: string;
  body: string;
  data: Record<string, any> | null;
  readAt: Date | null;
  createdAt: Date;
};

function matches(row: any, where: any): boolean {
  if (!where) return true;

  for (const [key, value] of Object.entries(where)) {
    if (key === 'OR') {
      if (!Array.isArray(value) || !value.some((item) => matches(row, item))) {
        return false;
      }
      continue;
    }

    if (key === 'data') {
      const filter = value as { path?: string[]; equals?: unknown };
      const path = filter.path ?? [];
      let current: any = row.data;
      for (const part of path) current = current?.[part];
      if (filter.equals !== undefined && current !== filter.equals) {
        return false;
      }
      continue;
    }

    if (
      key === 'id' &&
      value &&
      typeof value === 'object' &&
      !Array.isArray(value)
    ) {
      if ('not' in value && row.id === (value as any).not) return false;
      if ('in' in value && !(value as any).in.includes(row.id)) return false;
      continue;
    }

    if (row[key] !== value) return false;
  }

  return true;
}

class FakePrisma {
  private sequence = 0;
  private transactionTail: Promise<void> = Promise.resolve();

  users = new Set<string>();
  profiles = new Map<string, { name: string; avatar?: string | null }>();
  blocks: { id: string; blockerId: string; blockedId: string }[] = [];
  friendRequests: StoredFriendRequest[] = [];
  notifications: StoredNotification[] = [];
  calls: { id: string; userAId: string; userBId: string; createdAt: Date }[] =
    [];
  feedbacks: any[] = [];

  $executeRaw = jest.fn(async () => 1);

  constructor() {
    for (const id of ['a', 'b', 'c']) {
      this.users.add(id);
      this.profiles.set(id, { name: id.toUpperCase() });
    }
  }

  private nextId(prefix: string): string {
    this.sequence += 1;
    return `${prefix}-${this.sequence}`;
  }

  private userView(id: string) {
    return { id, profile: this.profiles.get(id) ?? null };
  }

  private friendRequestView(row: StoredFriendRequest, include: any) {
    const out: any = { ...row };
    if (include?.sender) out.sender = this.userView(row.senderId);
    if (include?.receiver) out.receiver = this.userView(row.receiverId);
    return out;
  }

  user = {
    findUnique: jest.fn(async ({ where }: any) => {
      if (!this.users.has(where.id)) return null;
      return this.userView(where.id);
    }),
  };

  block = {
    findFirst: jest.fn(async ({ where }: any) => {
      return this.blocks.find((block) => matches(block, where)) ?? null;
    }),
  };

  callSession = {
    findFirst: jest.fn(async ({ where, orderBy }: any) => {
      const rows = this.calls
        .filter((call) => matches(call, where))
        .sort((a, b) =>
          orderBy?.createdAt === 'desc'
            ? b.createdAt.getTime() - a.createdAt.getTime()
            : a.createdAt.getTime() - b.createdAt.getTime(),
        );
      return rows[0] ?? null;
    }),
  };

  friendRequest = {
    findFirst: jest.fn(async ({ where }: any) => {
      return this.friendRequests.find((request) => matches(request, where)) ?? null;
    }),

    findUnique: jest.fn(async ({ where, include }: any) => {
      const row =
        this.friendRequests.find((request) => request.id === where.id) ?? null;
      return row ? this.friendRequestView(row, include) : null;
    }),

    findMany: jest.fn(async ({ where, include, orderBy }: any) => {
      let rows = this.friendRequests.filter((request) => matches(request, where));
      if (orderBy?.updatedAt === 'desc') {
        rows = [...rows].sort(
          (a, b) => b.updatedAt.getTime() - a.updatedAt.getTime(),
        );
      }
      if (orderBy?.createdAt === 'desc') {
        rows = [...rows].sort(
          (a, b) => b.createdAt.getTime() - a.createdAt.getTime(),
        );
      }
      return rows.map((row) => this.friendRequestView(row, include));
    }),

    create: jest.fn(async ({ data }: any) => {
      const now = new Date();
      const row: StoredFriendRequest = {
        id: this.nextId('fr'),
        senderId: data.senderId,
        receiverId: data.receiverId,
        status: data.status ?? FriendRequestStatus.PENDING,
        createdAt: now,
        updatedAt: now,
      };
      this.friendRequests.push(row);
      return { ...row };
    }),

    update: jest.fn(async ({ where, data }: any) => {
      const row = this.friendRequests.find((request) => request.id === where.id);
      if (!row) throw new Error('Friend request not found');
      Object.assign(row, data, { updatedAt: new Date() });
      return { ...row };
    }),

    updateMany: jest.fn(async ({ where, data }: any) => {
      let count = 0;
      for (const row of this.friendRequests) {
        if (!matches(row, where)) continue;
        Object.assign(row, data, { updatedAt: new Date() });
        count += 1;
      }
      return { count };
    }),
  };

  notification = {
    create: jest.fn(async ({ data }: any) => {
      const row: StoredNotification = {
        id: this.nextId('n'),
        userId: data.userId,
        type: data.type,
        title: data.title,
        body: data.body,
        data: data.data ?? null,
        readAt: null,
        createdAt: new Date(),
      };
      this.notifications.push(row);
      return { ...row };
    }),

    updateMany: jest.fn(async ({ where, data }: any) => {
      let count = 0;
      for (const row of this.notifications) {
        if (!matches(row, where)) continue;
        if (data.data !== undefined) row.data = data.data;
        if (data.readAt !== undefined) row.readAt = data.readAt;
        count += 1;
      }
      return { count };
    }),
  };

  callFeedback = {
    upsert: jest.fn(async ({ where, update, create }: any) => {
      const existing = this.feedbacks.find(
        (feedback) => feedback.dedupeKey === where.dedupeKey,
      );
      if (existing) {
        Object.assign(existing, update, { updatedAt: new Date() });
        return { ...existing };
      }
      const row = {
        id: this.nextId('fb'),
        createdAt: new Date(),
        updatedAt: new Date(),
        ...create,
      };
      this.feedbacks.push(row);
      return { ...row };
    }),
  };

  async $transaction<T>(fn: (tx: FakePrisma) => Promise<T>): Promise<T> {
    // The real implementation uses a PostgreSQL advisory lock per pair.
    // A global queue gives the same serialization guarantee in tests.
    let release!: () => void;
    const previous = this.transactionTail;
    this.transactionTail = new Promise<void>((resolve) => {
      release = resolve;
    });

    await previous;
    try {
      return await fn(this);
    } finally {
      release();
    }
  }
}

describe('FriendRequestsService', () => {
  let prisma: FakePrisma;
  let events: { sendToUser: jest.Mock };
  let presence: { isOnline: jest.Mock };
  let service: FriendRequestsService;

  
beforeEach(() => {
  prisma = new FakePrisma();

  events = {
    sendToUser: jest.fn(async () => true),
  };

  presence = {
    isOnline: jest.fn(async () => false),
  };

  service = new FriendRequestsService(
    prisma as any,
    events as any,
    presence as any,
  );
});


  const feedback = (overrides: Record<string, unknown> = {}) => ({
    receiverId: 'b',
    reaction: null,
    feedback: [],
    addToFriends: false,
    connectAgain: false,
    ...overrides,
  });

  const eventNames = () =>
    events.sendToUser.mock.calls.map((call: any[]) => call[1]);

  it('stores feedback with no reaction and no friend request', async () => {
    const result = await service.submitCallFeedback('a', feedback() as any);

    expect(result.status).toBe('FEEDBACK_SUBMITTED');
    expect(prisma.feedbacks).toHaveLength(1);
    expect(prisma.feedbacks[0].reaction).toBeNull();
    expect(prisma.friendRequests).toHaveLength(0);
    expect(events.sendToUser).not.toHaveBeenCalled();
  });

  it('stores a LIKE reaction and feedback labels', async () => {
    await service.submitCallFeedback(
      'a',
      feedback({
        reaction: 'like',
        feedback: ['Friendly', 'Good English'],
      }) as any,
    );

    expect(prisma.feedbacks[0].reaction).toBe(CallReaction.LIKE);
    expect(prisma.feedbacks[0].feedback).toEqual(['Friendly', 'Good English']);
  });

  it('creates a pending friend request when addToFriends is true', async () => {
    const result = await service.submitCallFeedback(
      'a',
      feedback({ addToFriends: true }) as any,
    );

    expect(result.status).toBe('PENDING');
    expect(prisma.feedbacks).toHaveLength(1);
    expect(prisma.friendRequests).toHaveLength(1);
    expect(prisma.friendRequests[0].status).toBe(FriendRequestStatus.PENDING);

    const notification = prisma.notifications[0];
    expect(notification.userId).toBe('b');
    expect(notification.data?.kind).toBe('FRIEND_REQUEST');
    expect(notification.data?.requestId).toBe(prisma.friendRequests[0].id);
    expect(eventNames()).toEqual([
      'NOTIFICATION_CREATED',
      'FRIEND_REQUEST_RECEIVED',
    ]);
  });

  it('keeps a one-sided request pending and notifies only the receiver', async () => {
    const result = await service.sendRequest('a', 'b');

    expect(result.status).toBe('PENDING');
    expect(prisma.friendRequests).toHaveLength(1);
    expect(prisma.friendRequests[0].status).toBe(FriendRequestStatus.PENDING);
    expect(prisma.notifications).toHaveLength(1);
    expect(prisma.notifications[0].userId).toBe('b');
  });

  it('auto-accepts a reverse pending request on a mutual request', async () => {
    await service.sendRequest('a', 'b');
    const originalRequestId = prisma.friendRequests[0].id;

    const result = await service.sendRequest('b', 'a');

    expect(result.status).toBe('FRIENDS');
    expect(prisma.friendRequests).toHaveLength(1);
    expect(prisma.friendRequests[0].id).toBe(originalRequestId);
    expect(prisma.friendRequests[0].status).toBe(
      FriendRequestStatus.ACCEPTED,
    );

    const resolved = prisma.notifications.find(
      (notification) => notification.data?.requestId === originalRequestId,
    );
    expect(resolved?.data?.kind).toBe('FRIEND_REQUEST_ACCEPTED');
  });

  it('lists both users as friends after a mutual request', async () => {
    await service.sendRequest('a', 'b');
    await service.sendRequest('b', 'a');

    const friendsOfA = await service.listFriends('a');
    const friendsOfB = await service.listFriends('b');

    expect(friendsOfA).toHaveLength(1);
    expect(friendsOfA[0]).toMatchObject({
      userId: 'b',
      name: 'B',
      avatar: null,
    });
    expect(friendsOfB).toHaveLength(1);
    expect(friendsOfB[0]).toMatchObject({
      userId: 'a',
      name: 'A',
      avatar: null,
    });
  });

  it('does not create another friendship for already-friends users', async () => {
    await service.sendRequest('a', 'b');
    await service.sendRequest('b', 'a');
    const notificationsBefore = prisma.notifications.length;

    const result = await service.sendRequest('a', 'b');

    expect(result.status).toBe('FRIENDS');
    expect(prisma.friendRequests).toHaveLength(1);
    expect(prisma.friendRequests[0].status).toBe(
      FriendRequestStatus.ACCEPTED,
    );
    expect(prisma.notifications).toHaveLength(notificationsBefore);
  });

  it('does not duplicate a pending request or notification on retry', async () => {
    await service.sendRequest('a', 'b');
    events.sendToUser.mockClear();

    const result = await service.sendRequest('a', 'b');

    expect(result.status).toBe('PENDING');
    expect(prisma.friendRequests).toHaveLength(1);
    expect(prisma.notifications).toHaveLength(1);
    expect(events.sendToUser).not.toHaveBeenCalled();
  });

  it('rejects friend requests between blocked users', async () => {
    prisma.blocks.push({
      id: 'block-1',
      blockerId: 'b',
      blockedId: 'a',
    });

    await expect(service.sendRequest('a', 'b')).rejects.toThrow(
      'Friend requests are unavailable between these users.',
    );
    expect(prisma.friendRequests).toHaveLength(0);
  });

  it('rejects feedback and requests for an unknown receiver', async () => {
    await expect(
      service.submitCallFeedback('a', feedback({ receiverId: 'missing' }) as any),
    ).rejects.toThrow('User not found.');
    await expect(service.sendRequest('a', 'missing')).rejects.toThrow(
      'User not found.',
    );
  });

  it('allows the receiver to accept a one-sided pending request', async () => {
    await service.sendRequest('a', 'b');
    const requestId = prisma.friendRequests[0].id;

    const result = await service.acceptRequest('b', requestId);

    expect(result.status).toBe('FRIENDS');
    expect(prisma.friendRequests[0].status).toBe(
      FriendRequestStatus.ACCEPTED,
    );
    expect((await service.listFriends('a')).map((friend) => friend.userId)).toEqual([
      'b',
    ]);
    expect((await service.listFriends('b')).map((friend) => friend.userId)).toEqual([
      'a',
    ]);
    expect(eventNames()).toContain('FRIEND_REQUEST_ACCEPTED');
    expect(eventNames()).toContain('FRIENDSHIP_CREATED');
  });

  it('never lists declined or cancelled requests as friends', async () => {
    await service.sendRequest('a', 'b');
    const declinedId = prisma.friendRequests[0].id;
    await service.declineRequest('b', declinedId);

    expect(await service.listFriends('a')).toEqual([]);
    expect(await service.listFriends('b')).toEqual([]);
    expect(await service.receivedRequests('b')).toEqual([]);

    await service.sendRequest('a', 'b');
    const cancelledId = prisma.friendRequests[1].id;
    await service.cancelRequest('a', cancelledId);

    expect(await service.listFriends('a')).toEqual([]);
    expect(await service.listFriends('b')).toEqual([]);
    expect(await service.sentRequests('a')).toEqual([]);
  });

  it('generates notifications only for appropriate state transitions', async () => {
    await service.sendRequest('a', 'b');
    const afterFirstRequest = prisma.notifications.length;
    expect(afterFirstRequest).toBe(1);

    await service.sendRequest('a', 'b');
    expect(prisma.notifications).toHaveLength(afterFirstRequest);

    await service.sendRequest('b', 'a');
    expect(prisma.notifications).toHaveLength(afterFirstRequest + 2);

    const kinds = prisma.notifications.map((notification) => notification.data?.kind);
    expect(kinds).toContain('FRIEND_REQUEST_ACCEPTED');
    expect(kinds.filter((kind) => kind === 'FRIENDSHIP_CREATED')).toHaveLength(2);
  });

  it('serializes concurrent mutual requests into one accepted friendship', async () => {
    const results = await Promise.all([
      service.sendRequest('a', 'b'),
      service.sendRequest('b', 'a'),
    ]);

    expect(results.map((result) => result.status).sort()).toEqual([
      'FRIENDS',
      'PENDING',
    ]);
    expect(prisma.friendRequests).toHaveLength(1);
    expect(prisma.friendRequests[0].status).toBe(
      FriendRequestStatus.ACCEPTED,
    );
    expect(await service.listFriends('a')).toHaveLength(1);
    expect(await service.listFriends('b')).toHaveLength(1);
  });

  it('keeps existing received/sent/accept/decline/cancel APIs compatible', async () => {
    const sent = await service.sendRequest('a', 'b');
    expect(sent.request).toMatchObject({
      senderId: 'a',
      receiverId: 'b',
      status: FriendRequestStatus.PENDING,
    });

    const received = await service.receivedRequests('b');
    expect(received).toHaveLength(1);
    expect(received[0].id).toBe(sent.request.id);

    const outgoing = await service.sentRequests('a');
    expect(outgoing).toHaveLength(1);
    expect(outgoing[0].id).toBe(sent.request.id);

    const accepted = await service.acceptRequest('b', sent.request.id);
    expect(accepted.status).toBe('FRIENDS');
    expect(accepted.request.status).toBe(FriendRequestStatus.ACCEPTED);
  });
});
