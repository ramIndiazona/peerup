# Flutter ⇄ Unity Bridge Protocol

The Unity avatar does not know about Flutter or your AI providers. It speaks one
**JSON message protocol** over a transport that Flutter owns. On the Unity side the
transport is an `IExternalMessageBridge`:

```csharp
public interface IExternalMessageBridge {
    void SendMessage(string json);          // Unity -> Flutter
}
```

`FlutterUnityBridge` also dynamically listens for Unity-`SendMessage`
(`"AvatarBridge", "OnFlutterMessageFromHostApp"`) and provides
`FlutterUnityBridge.SendOutbound(..)` for pushing messages *from* Unity.

The default implementation bridges via Unity's `UnitySendMessage`, which is how
`SendMessage("AvatarBridge", ..)` reaches the host GameObject. In a Unity-Library
embedding, the Flutter side implements the counterpart: it both **receives** the
outbound JSON (Unity→Flutter) and **injects** inbound JSON into
`FlutterUnityBridge.HandleIncoming(json)` (Flutter→Unity).

---

## Envelope (all messages)

```json
{
  "type": "<message-type>",
  "requestId": "<optional correlation id, echoed in replies>",
  "payload": { }
}
```

- `requestId` is echoed in outbound replies (e.g. `diagnostics.metrics`).
- Parsing is strict & resilient: malformed JSON or missing `type` is rejected,
  logged, counted in diagnostics, and answered with `avatar.warning`.
- Unknown-but-valid `type` values are ignored with a warning (forward-compatible).
- All inbound handling runs on the Unity main thread (queued automatically by
  `UnityMainThreadDispatcher`).

---

## Inbound messages (Flutter → Unity)

### `avatar.state`
Drive the behavioural state machine (`AvatarStateController`).
```json
{ "type": "avatar.state", "payload": { "state": "listening" } }
```
`state` values: `idle`, `listening`, `thinking`, `speaking`, `interrupted`.
Invalid states are ignored (logged).

### `avatar.emotion`
Apply an emotion blend (blends in/out smoothly).
```json
{ "type": "avatar.emotion", "payload": { "emotion": "happy", "intensity": 0.8, "transitionMs": 300 } }
```
- `emotion`: `neutral`, `happy`, `encouraging`, `curious`, `thinking`, `excited`,
  `concerned`, `surprised` (case-insensitive).
- `intensity` (0..1, default 1) and either `transitionMs` (int) or
  `transitionSeconds` (float, wins if > 0). Default transition 0.4 s.

### `avatar.gesture`
Fire a gesture through the Animator (`GestureTrigger` parameter).
```json
{ "type": "avatar.gesture", "payload": { "gesture": "nod" } }
```
`gesture`: `nod`, `welcome`, `explain`, `point`, `agree`, `think`, `celebrate`,
`question`, `encourage` (case-insensitive; `none` is ignored).

### `audio.configure`
Configure the streaming PCM player **before** the first chunk.
```json
{ "type": "audio.configure", "payload": { "sampleRate": 16000, "channels": 1 } }
```
Rejected (→ `avatar.error` `InvalidAudioConfiguration`) if invalid.

### `audio.chunk`
Append a chunk of audio. Drained audio begins playing automatically once enough
buffer exists (`AvatarAudioPlayer.bufferThresholdSeconds`).
```json
{ "type": "audio.chunk", "payload": { "encoding": "pcm16-base64", "data": "<base64>", "sampleRate": 16000, "channels": 1 } }
```
- `encoding`: `pcm16-base64` or `pcm16` (both require base64 payload currently).
- 16-bit little-endian **mono** PCM, one `float` per sample.
- Decoding errors are logged + ignored — the player never crashes.

### `audio.stop`
Stop playback immediately and flush the decoded buffer.
```json
{ "type": "audio.stop" }
```

### `speech.interrupt`
Barge-in: interrupts streamed speech + explicit visemes, emits `speech.interrupted`.
```json
{ "type": "speech.interrupt" }
```

### `viseme.batch`
Explicit viseme stream, timestamped against **Unity's playback clock**
(`AvatarAudioPlayer.PlaybackTimeSeconds`, i.e. `AudioSettings.dspTime`,
in seconds ⇒ multiply your provider timestamps by 1000 for `timestampMs`).
```json
{
  "type": "viseme.batch",
  "payload": { "items": [ { "id": 4, "timestampMs": 80, "weight": 1.0 } ] }
}
```
- `id` is the **provider viseme ID**, mapped to mouth channels through
  `VisemeMappingConfig` (22 defaults provided, Azure-viseme-compatible ordering).
- Items are sorted + blended automatically (`VisemeScheduler`); anything pruned by
  expiry is dropped silently.

### `avatar.logLevel`
Adjust logger verbosity at runtime.
```json
{ "type": "avatar.logLevel", "payload": { "level": "verbose" } }
```
`level`: `off`, `error`, `warning`, `info`, `verbose`, `debug`.

### `avatar.quality`
Switch mobile quality profile live.
```json
{ "type": "avatar.quality", "payload": { "qualityLevel": 1 } }
```
`qualityLevel`: `0` Low, `1` Medium, `2` High. Applies FPS cap + shadow/pixel-light
tuning (`AvatarPerformanceController.ApplyProfile`).

### `diagnostics.get`
Request a metrics snapshot; replied with `diagnostics.metrics` (echoes `requestId`).
```json
{ "type": "diagnostics.get" }
```

---

## Outbound messages (Unity → Flutter)

| type | purpose | payload |
|------|---------|---------|
| `unity.ready` | bridge component Start | — |
| `avatar.ready` | bootstrap completed; args `{ "displayName": "..." }` | — |
| `avatar.stateChanged` | state machine transition | `{ "from":"...", "state":"..." }` |
| `audio.started` | streamed playback began | `{ "playbackTime": <dsp seconds> }` |
| `audio.finished` | playback completed / drained | — |
| `audio.bufferUnderrun` | audio-thread underrun | `{ "count":<n>, "playbackTime":<s> }` |
| `speech.started` | speaking session began | — |
| `speech.finished` | speaking session ended | — |
| `speech.interrupted` | barge-in happened | — |
| `avatar.error` | recoverable error | `{ "code":"..", "message":".." }` |
| `avatar.warning` | malformed/ignored input | `{ "code":"..", "message":".." }` |
| `diagnostics.metrics` | reply to `diagnostics.get` | see below |

`diagnostics.metrics` payload fields:

```json
{
  "state": "speaking",
  "fps": 59.8,
  "audioPlaybackTime": 12.25,
  "audioBufferSeconds": 0.42,
  "audioUnderruns": 0,
  "queuedVisemes": 3,
  "bridgeMessagesReceived": 240,
  "malformedMessages": 0,
  "interruptions": 1,
  "errors": 0,
  "lastErrorCode": null,
  "emotion": "happy",
  "gesture": "none"
}
```

Error codes available on `AvatarErrorCode`: `Unknown`, `MissingAnimator`,
`MissingFaceRenderer`, `InvalidAudioConfiguration`, `InvalidBridgeMessage`,
`InvalidViseme`, `AudioBufferFailure`, `InitializationFailure`.

---

## Suggested Flutter flow

1. Unity scene starts → sends `unity.ready`, then `avatar.ready`.
2. Flutter sends `audio.configure` the day you know the TTS format
   (16 kHz mono PCM16 recommended).
3. Per user turn:
   - `avatar.state` `listening` → user speaks → `thinking` → `speaking`
   - TTS arrives: `viseme.batch` (if your TTS exposes visemes) +
     repeated `audio.chunk` until end.
   - On done: `audio.stop` (or just let it drain → `audio.finished`), then
     `avatar.emotion`/`avatar.gesture` as you like.
4. Barge-in: send `speech.interrupt`, expect `speech.interrupted`.
5. Monitor health with `diagnostics.get` every few seconds.

## Concurrency & threading

- Inbound JSON may arrive from any thread: the bridge marshals to the main thread.
- The audio ring buffer is written on the main thread and read on the audio thread;
  synchronization is a lock + atomic-ish drains inside `AvatarAudioPlayer`.
- Viseme timestamps always use `AvatarAudioPlayer.PlaybackTimeSeconds`
  (paused-time-aware), never `Time.time`.