import { CallsService } from './calls.service';
import { CallStatus } from '@prisma/client';
import { PresenceStatus } from '../presence/presence.service';

describe('established call recovery', () => {
  let service: CallsService;
  let db: any;
  let records: Map<string, any>;
  let people: Map<string, any>;
  let events: any;
  let prisma: any;
  let redis: any;
  let locks: Set<string>;
  beforeEach(async () => {
    jest.useFakeTimers();
    records = new Map();
    people = new Map(['a', 'b'].map((id) => [id, { currentCallId: 'call', socketId: `socket-${id}`, status: PresenceStatus.IN_CALL }]));
    db = { id: 'call', userAId: 'a', userBId: 'b', status: CallStatus.CONNECTED, connectedAt: new Date(Date.now() - 60000) };
    prisma = { callSession: {
      findFirst: jest.fn(async () => ({ ...db })),
      findUnique: jest.fn(async () => ({ ...db })),
      updateMany: jest.fn(async ({ where, data }) => {
        if (where.status?.notIn.includes(db.status)) return { count: 0 };
        Object.assign(db, data);
        return { count: 1 };
      }),
    } };
    locks = new Set<string>();
    redis = {
      setJson: jest.fn(async (key, value) => { records.set(key, value); }),
      getJson: jest.fn(async (key) => records.get(key) ?? null),
      get: jest.fn(async (key) => records.has(key) ? JSON.stringify(records.get(key)) : null),
      del: jest.fn(async (key) => records.delete(key)),
      acquireLock: jest.fn(async (key) => {
        if (locks.has(key)) return null;
        locks.add(key);
        return async () => { locks.delete(key); };
      }),
    };
    const presence = {
      get: jest.fn(async (id) => people.get(id)),
      upsert: jest.fn(async (id, patch) => Object.assign(people.get(id), patch)),
      getLiveCount: jest.fn(async () => 0),
    };
    events = { sendToUser: jest.fn(async () => {}), isConnected: jest.fn(() => false), broadcastLiveCount: jest.fn() };
    service = new CallsService(prisma, redis, presence as any, events, { get: (_key: string, fallback: any) => fallback } as any);
    await service.registerCall('call', ['a', 'b'], CallStatus.CONNECTED);
  });
  afterEach(() => { service.onModuleDestroy(); jest.clearAllTimers(); jest.useRealTimers(); });
  const endedEvents = (events: any) => events.sendToUser.mock.calls.filter((args: any[]) => args[1] === 'CALL_ENDED');

  it('retains busy presence and resumes the same call before the deadline', async () => {
    const connectedAt = db.connectedAt;
    await service.handleDisconnect('a', 'socket-a');
    await jest.advanceTimersByTimeAsync(5000);
    expect(db.status).toBe(CallStatus.CONNECTED);
    expect(people.get('a').status).toBe(PresenceStatus.IN_CALL);
    await service.handleReconnect('a');
    await jest.advanceTimersByTimeAsync(20000);
    expect(endedEvents(events)).toHaveLength(0);
    expect(db.connectedAt).toBe(connectedAt);
    expect(records.has('call:reconnecting:call:a')).toBe(false);
  });

  it('ends exactly once after 15 seconds, then runs existing presence cleanup', async () => {
    await service.handleDisconnect('a');
    await jest.advanceTimersByTimeAsync(14999);
    expect(endedEvents(events)).toHaveLength(0);
    await jest.advanceTimersByTimeAsync(1);
    expect(db.status).toBe(CallStatus.ENDED);
    expect(endedEvents(events)).toHaveLength(2); // once per participant
    await service.handleReconnect('a');
    await service.failCall('call', 'PEER_DISCONNECTED', 'late failure');
    await jest.advanceTimersByTimeAsync(3000);
    expect(endedEvents(events)).toHaveLength(2);
    expect(people.get('a').currentCallId).toBeNull();
  });

  it('duplicate disconnects never extend grace or duplicate notifications', async () => {
    await service.handleDisconnect('a');
    await jest.advanceTimersByTimeAsync(5000);
    await service.handleDisconnect('a');
    expect(events.sendToUser.mock.calls.filter((args: any[]) => args[1] === 'CALL_RECONNECTING')).toHaveLength(2);
    await jest.advanceTimersByTimeAsync(10000);
    expect(db.status).toBe(CallStatus.ENDED);
  });

  it('manual hangup wins immediately and clears both participants timers', async () => {
    await service.handleDisconnect('a');
    await service.handleDisconnect('b');
    await service.endCall('call', 'b');
    expect(db.status).toBe(CallStatus.ENDED);
    await jest.advanceTimersByTimeAsync(20000);
    expect(endedEvents(events)).toHaveLength(2);
    expect([...records.keys()].filter((key) => key.startsWith('call:reconnecting:'))).toHaveLength(0);
  });

  it('a queued timeout cannot end a call after reconnect won', async () => {
    await service.handleDisconnect('a');
    const { deadline } = records.get('call:reconnecting:call:a');
    await service.handleReconnect('a');
    await (service as any).expireRecovery('call', 'a', 'call:reconnecting:call:a', deadline);
    expect(db.status).toBe(CallStatus.CONNECTED);
  });

  it('reconnect at the expired deadline cannot resurrect the call', async () => {
    await service.handleDisconnect('a');
    jest.setSystemTime(Date.now() + 15000);
    await service.handleReconnect('a');
    await service.confirmConnected('call');
    expect(db.status).toBe(CallStatus.ENDED);
    expect(endedEvents(events)).toHaveLength(2);
  });

  it('retries the grace period when the call lock is busy instead of leaking the call', async () => {
    await service.handleDisconnect('a');
    // Another instance holds the call lock (for example a crashed worker).
    locks.add('call:call');
    await jest.advanceTimersByTimeAsync(15000);
    expect(db.status).toBe(CallStatus.CONNECTED);
    locks.delete('call:call');
    await jest.advanceTimersByTimeAsync(10000);
    expect(db.status).toBe(CallStatus.ENDED);
    expect(endedEvents(events)).toHaveLength(2);
  });

  it('ICE restart offers preserve CONNECTED and original connectedAt', async () => {
    const connectedAt = db.connectedAt;
    await service.relaySignaling('call', 'a', 'CALL_OFFER', { iceRestart: true });
    await service.confirmConnected('call');
    expect(db.status).toBe(CallStatus.CONNECTED);
    expect(records.get('call:call').status).toBe(CallStatus.CONNECTED);
    expect(db.connectedAt).toBe(connectedAt);
  });

  it('ignores an old socket disconnect after a replacement binds', async () => {
    people.get('a').socketId = 'replacement';
    await service.handleDisconnect('a', 'socket-a');
    expect(records.has('call:reconnecting:call:a')).toBe(false);
    expect(endedEvents(events)).toHaveLength(0);
  });

  it('preserves immediate disconnect cleanup before the call is established', async () => {
    db.status = CallStatus.SIGNALING;
    await service.registerCall('call', ['a', 'b'], CallStatus.SIGNALING);
    await service.handleDisconnect('a');
    expect(db.status).toBe(CallStatus.ENDED);
    expect(endedEvents(events)).toHaveLength(2);
  });
});
