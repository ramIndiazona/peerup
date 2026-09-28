/**
 * E2E smoke test: two users -> live -> matchmaking -> signaling -> call lifecycle.
 * Run with: npx ts-node test/e2e-script.ts  (backend must be running)
 */
import io from 'socket.io-client';
import type { Socket } from 'socket.io-client';
import { randomUUID } from 'crypto';

const BASE = process.env.API_BASE ?? 'http://localhost:3100';
const WS_URL = BASE.replace(/^http/, 'ws');

let passed = 0;
let failed = 0;
function check(name: string, ok: boolean, detail?: unknown): void {
  if (ok) {
    passed += 1;
    console.log(`  PASS ${name}`);
  } else {
    failed += 1;
    console.error(`  FAIL ${name}`, detail ?? '');
  }
}

async function api(path: string, body?: unknown, token?: string) {
  const res = await fetch(`${BASE}/api${path}`, {
    method: body === undefined ? 'GET' : 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  let json: any = {};
  try {
    if (res.status !== 204) json = await res.json();
  } catch { /* body not JSON */ }
  return { status: res.status, json };
}

type SocketClient = ReturnType<typeof io>;
function connect(token: string): Promise<{ sock: SocketClient; connected: Promise<any> }> {
  const sock = io(WS_URL, { path: '/realtime', auth: { token }, transports: ['websocket'] });
  return new Promise((resolve, reject) => {
    const t = setTimeout(() => reject(new Error('connect timeout')), 8000);
    sock.on('connect', () => {
      clearTimeout(t);
      const connected = once(sock, 'CONNECTED', 8000);
      resolve({ sock, connected });
    });
    sock.on('connect_error', (err: any) => {
      clearTimeout(t);
      reject(err);
    });
  });
}

function once(socket: SocketClient, event: string, timeoutMs = 10000): Promise<any> {
  return new Promise((resolve, reject) => {
    const t = setTimeout(() => reject(new Error(`timeout waiting for ${event}`)), timeoutMs);
    socket.once(event, (data: any) => {
      clearTimeout(t);
      resolve(data);
    });
  });
}

async function main(): Promise<void> {
  const suffix = randomUUID().slice(0, 8);
  const regA = await api('/auth/register', {
    email: `alice-${suffix}@test.local`, password: 'Password1a', name: 'Alice', englishLevel: 'B1',
  });
  const regB = await api('/auth/register', {
    email: `bob-${suffix}@test.local`, password: 'Password1a', name: 'Bob', englishLevel: 'B2',
  });
  check('register A', regA.status === 201, regA.json?.error);
  check('register B', regB.status === 201, regB.json?.error);
  const tokenA = regA.json.accessToken as string;
  const tokenB = regB.json.accessToken as string;

  const meA = await api('/users/me', undefined, tokenA);
  check('profile me A (has id + name)', !!meA.json?.user?.id && !!meA.json?.user?.profile?.name, meA.json?.user);

  const { sock: sockA, connected: connA } = await connect(tokenA);
  const { sock: sockB, connected: connB } = await connect(tokenB);
  const [ca, cb] = await Promise.all([connA, connB]);
  check('CONNECTED hello A', ca?.userId === meA.json.user.id, ca);
  check('CONNECTED hello B', cb?.userId !== undefined, cb);

  const liveA = await api('/live/start', {}, tokenA);
  const liveB = await api('/live/start', {}, tokenB);
  check('live start A', liveA.json?.count >= 1, liveA.json);
  check('live start B', liveB.json?.count >= 2, liveB.json);
  const count = await api('/live/count', undefined, tokenA);
  check('live/count endpoint', count.json?.count >= 2, count.json);

  // A searches. B is already AVAILABLE, so A should match B immediately.
  const foundPromiseB = once(sockB, 'MATCH_FOUND', 10000);
  const foundPromiseA = once(sockA, 'MATCH_FOUND', 10000);
  sockA.emit('START_MATCH', { filters: { level: 'B1' } });

  const [foundA, foundB] = await Promise.all([foundPromiseA, foundPromiseB]);
  check('A received MATCH_FOUND', Boolean(foundA?.callId), foundA);
  check('B received MATCH_FOUND', Boolean(foundB?.callId), foundB);
  check('same call for both', foundA?.callId === foundB?.callId, { A: foundA?.callId, B: foundB?.callId });
  const callId = foundA?.callId as string;

  // WebRTC signaling relay.
  const offerPromise = once(sockB, 'CALL_OFFER', 8000);
  sockA.emit('CALL_OFFER', { callId, data: { sdp: 'fake-offer' } });
  check('CALL_OFFER relayed to B', (await offerPromise)?.callId === callId);

  const answerPromise = once(sockA, 'CALL_ANSWER', 8000);
  sockB.emit('CALL_ANSWER', { callId, data: { sdp: 'fake-answer' } });
  check('CALL_ANSWER relayed to A', (await answerPromise)?.callId === callId);

  sockA.emit('ICE_CANDIDATE', { callId, data: { candidate: 'candidate:1' } });
  sockB.emit('ICE_CANDIDATE', { callId, data: { candidate: 'candidate:2' } });

  const connectedPromiseB = once(sockB, 'CALL_CONNECTED', 8000);
  sockA.emit('CALL_CONNECTED', { callId });
  check('CALL_CONNECTED relayed', (await connectedPromiseB)?.callId === callId);

  const call = await api(`/calls/${callId}`, undefined, tokenA);
  check('call readable by participant', call.status === 200, call.json?.error);

  const endedPromiseB = once(sockB, 'CALL_ENDED', 8000);
  sockA.emit('END_CALL', { callId });
  check('B received CALL_ENDED', (await endedPromiseB)?.callId === callId);

  const callAfter = await api(`/calls/${callId}`, undefined, tokenA);
  check('call persisted ENDED', callAfter.json?.call?.status === 'ENDED', callAfter.json);

  // Third party must NOT read the call.
  const regE = await api('/auth/register', {
    email: `eve-${suffix}@test.local`, password: 'Password1a', name: 'Eve',
  });
  const forbidden = await api(`/calls/${callId}`, undefined, regE.json.accessToken);
  check('third party cannot read call (403)', forbidden.status === 403, forbidden.json?.error);

  sockA.disconnect();
  sockB.disconnect();
  console.log(`\n${passed} passed, ${failed} failed`);
  process.exit(failed > 0 ? 1 : 0);
}

main().catch((err) => {
  console.error('E2E crashed:', err.message);
  process.exit(1);
});