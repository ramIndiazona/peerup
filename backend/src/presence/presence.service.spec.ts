import { ConfigService } from "@nestjs/config";
import { PrismaService } from "../prisma/prisma.service";
import { RedisService } from "../redis/redis.service";
import { RealtimeEventsService } from "../realtime/realtime-events.service";
import { PresenceService, PresenceStatus } from "./presence.service";

const makeRedis = (overrides: Record<string, unknown> = {}) => ({
  getJson: jest.fn().mockResolvedValue(null),
  setJson: jest.fn().mockResolvedValue(true),
  get: jest.fn().mockResolvedValue(null),
  set: jest.fn().mockResolvedValue("OK"),
  sadd: jest.fn().mockResolvedValue(1),
  srem: jest.fn().mockResolvedValue(1),
  incr: jest.fn().mockResolvedValue(1),
  decr: jest.fn().mockResolvedValue(0),
  del: jest.fn().mockResolvedValue(1),
  smembers: jest.fn().mockResolvedValue([]),
  scard: jest.fn().mockResolvedValue(0),
  ...overrides,
});

const makeEvents = () => ({
  broadcastLiveUsers: jest.fn().mockResolvedValue(undefined),
});

const makePrisma = (users: unknown[] = []) => ({
  user: { findMany: jest.fn().mockResolvedValue(users) },
});

const livePresence = (userId: string): Record<string, unknown> => ({
  userId,
  status: PresenceStatus.AVAILABLE,
  socketId: `socket-${userId}`,
  lastHeartbeat: Date.now(),
  availableSince: Date.now(),
  currentCallId: null,
  lastActiveAt: Date.now(),
});

const baseProfile = (name: string) => ({
  name,
  avatar: null,
  englishLevel: "B1",
  nativeLanguage: "English",
  learningLanguage: "Spanish",
  userInterests: [{ interest: { name: "movies" } }],
});

const redis = makeRedis();
const events = makeEvents();
const prisma = makePrisma([
  { id: "ram", profile: baseProfile("Ram") },
  { id: "varun", profile: baseProfile("Varun") },
  { id: "suraj", profile: baseProfile("Suraj") },
]);

const service = new PresenceService(
  redis as unknown as RedisService,
  { get: () => 45 } as unknown as ConfigService,
  events as unknown as RealtimeEventsService,
  prisma as unknown as PrismaService,
);

// broadcastLiveUsers() is fire-and-forget (void) in upsert/setOffline, so flush
// the microtask queue before asserting on those calls.
const flush = () => new Promise<void>((resolve) => setImmediate(resolve));

describe("PresenceService broadcast", () => {
  beforeEach(() => {
    redis.smembers.mockReset();
    redis.set.mockClear();
    redis.getJson.mockReset().mockResolvedValue(null);
    events.broadcastLiveUsers.mockClear();
  });

  it("broadcasts a sanitized LIVE_USERS payload for 3 live users (count=3)", async () => {
    redis.smembers.mockResolvedValue(["ram", "varun", "suraj"]);
    redis.getJson.mockImplementation((key: string) =>
      Promise.resolve(livePresence(key.split(":").pop() as string)),
    );

    await service.broadcastLiveUsers();

    expect(events.broadcastLiveUsers).toHaveBeenCalledTimes(1);
    const [count, users] = events.broadcastLiveUsers.mock.calls[0] as [
      number,
      Record<string, unknown>[],
    ];
    expect(count).toBe(3);
    expect(users).toHaveLength(3);
    for (const u of users) {
      expect(u).toMatchObject({ name: expect.any(String) });
      expect(u).not.toHaveProperty("password");
      expect(u).not.toHaveProperty("email");
      expect(u).not.toHaveProperty("passwordHash");
      expect(u).toHaveProperty("englishLevel", "B1");
      expect(u).toHaveProperty("interests", ["movies"]);
    }
    // The cached count is reconciled to the payload length.
    expect(redis.set).toHaveBeenCalledWith("live:count", "3");
  });

  it("broadcasts count=0 when nobody is live", async () => {
    redis.smembers.mockResolvedValue([]);

    await service.broadcastLiveUsers();

    expect(events.broadcastLiveUsers).toHaveBeenLastCalledWith(0, []);
  });

  it("drops users without a live presence record and reconciles count", async () => {
    // 'ghost' is in the Redis set but its presence key already expired.
    redis.smembers.mockResolvedValue(["ram", "ghost"]);
    redis.getJson.mockImplementation((key: string) =>
      Promise.resolve(key.endsWith(":ghost") ? null : livePresence("ram")),
    );

    await service.broadcastLiveUsers();

    const [count, users] = events.broadcastLiveUsers.mock.calls.at(-1) as [
      number,
      Record<string, unknown>[],
    ];
    expect(count).toBe(1);
    expect(users.map((u) => u.id)).toEqual(["ram"]);
  });
});

describe("PresenceService membership lifecycle", () => {
  beforeEach(() => {
    redis.getJson.mockReset().mockResolvedValue(null);
    events.broadcastLiveUsers.mockClear();
    redis.decr.mockClear();
  });

  it("becoming AVAILABLE adds to the live set, increments count, broadcasts", async () => {
    await service.availability("ram", true, "socket-1");
    await flush();

    expect(redis.sadd).toHaveBeenCalledWith("live:users", "ram");
    expect(redis.incr).toHaveBeenCalledWith("live:count");
    expect(events.broadcastLiveUsers).toHaveBeenCalledTimes(1);
  });

  it("moving SEARCHING -> MATCHED removes from the live set and broadcasts", async () => {
    redis.getJson.mockResolvedValue({
      userId: "ram",
      status: PresenceStatus.SEARCHING,
      socketId: "socket-1",
    });

    await service.upsert("ram", { status: PresenceStatus.MATCHED });
    await flush();

    expect(redis.srem).toHaveBeenCalledWith("live:users", "ram");
    expect(redis.decr).toHaveBeenCalledWith("live:count");
    expect(events.broadcastLiveUsers).toHaveBeenCalledTimes(1);
  });

  it("setOffline always SREMs (ghost-safe) and only DECRs when a member was removed", async () => {
    // Ghost: presence expired, but stale membership in the live set.
    redis.srem.mockResolvedValue(1);

    await service.setOffline("varun");
    await flush();

    expect(redis.srem).toHaveBeenCalledWith("live:users", "varun");
    expect(redis.decr).toHaveBeenCalledWith("live:count");
    expect(events.broadcastLiveUsers).toHaveBeenCalledTimes(1);

    // No membership at all: nothing decremented, nothing broadcast.
    redis.srem.mockResolvedValue(0);
    redis.decr.mockClear();
    events.broadcastLiveUsers.mockClear();

    await service.setOffline("suraj");
    await flush();

    expect(redis.decr).not.toHaveBeenCalled();
    expect(events.broadcastLiveUsers).not.toHaveBeenCalled();
  });
});
