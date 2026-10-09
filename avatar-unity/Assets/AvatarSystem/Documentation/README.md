# Avatar System — Unity side (AITutor chat avatar)

Production-grade Unity foundation for a realtime 3D AI talking avatar that will be
embedded as a Unity Library inside the Flutter `peerup` app.

Everything lives under `Assets/AvatarSystem/` and is namespaced `AvatarUnity.*`.
It is **framework-agnostic** on the AI side: the Unity project never talks to your
LLM/TTS/stt providers. A thin **Flutter ↔ Unity JSON bridge** carries the data.

---

## Requirements

- **Unity 6000.0.84f1 LTS** (`ProjectSettings/ProjectVersion.txt`) — built-in Render
  Pipeline (no URP/HDRP dependency).
- No third-party C# packages. Only `com.unity.test-framework`, `com.unity.ugui`
  and the base modules from `Packages/manifest.json`.
- Unity 2022.2+ API (`Object.FindFirstObjectByType`) — satisfied by Unity 6.

## Typical avatar rig requirements

See [`AVATAR_MODEL_REQUIREMENTS.md`](AVATAR_MODEL_REQUIREMENTS.md). At a minimum the
final production model must expose **skinned meshes that match the renderer keys** and
**blend shapes that match the channel mappings** configured in
`AvatarFaceConfig` (defaults assumed: renderer key `FaceMesh`, standard ARKit-style
blend shape names such as `jawOpen`, `mouthSmileLeft`, `eyeBlinkLeft`, …).

## Quick start (in the Editor)

1. Open `avatar-unity` in Unity **6000.0.84f1**.
2. Run `Avatar ▸ Setup ▸ Complete Setup (Configurations + Prefab + Scene)`.
   This creates:
   - `Assets/AvatarSystem/ScriptableObjects/*.asset` (configs with sensible defaults)
   - `Assets/AvatarSystem/Prefabs/AIAvatarRoot.prefab` (full component stack +
     placeholder capsule model)
   - `Assets/Scenes/AITutorScene.unity` (camera + light + a pre-instanced prefab)
   - the scene registered in Build Settings.
3. **Replace the placeholder model** with the production avatar:
   drag it onto `AIAvatarRoot ▸ AvatarModel` (or re-target the Hierarchy) and
   re-point: `AvatarController.animator` → the avatar's `Animator`,
   `AvatarAnimatorController` is wired at runtime in `AvatarBootstrap`.
4. Press **Play**. You should see:
   - `[Avatar] Bootstrap` log lines (idle state, audio ready, etc.),
   - the implicit camera feed, blinking, subtle idle drift,
   - debug hotkeys (see below).

Individual menu items exist for each step (`Avatar ▸ Setup ▸ 1..5`) and
`Avatar ▸ Setup ▸ Validate Setup` prints a reference report.

### Optional debug panel

`Avatar ▸ Setup ▸ 4. Add Debug Panel to Active Scene` creates an in-scene uGUI panel
with buttons for state, emotion, gestures, test tone and a synthetic viseme run.
Disable/delete the `DebugCanvas` GameObject for production.

### Debug hotkeys (Editor / dev builds)

With the legacy input manager active (`ENABLE_LEGACY_INPUT_MANAGER`):

| Key | Action                     | Key | Action                 |
|-----|----------------------------|-----|------------------------|
| 1   | Idle                       | 6   | Happy emotion          |
| 2   | Listening                  | 7   | Encouraging emotion    |
| 3   | Thinking                   | 8   | Thinking emotion       |
| 4   | Speaking                   | B   | Force blink            |
| 5   | Interrupt (barge-in)        | M   | Test tone (audio mouth)|
| N   | Nod gesture                | V   | Test synthetic visemes |
| C   | Celebrate gesture          |     |                        |

## Architecture

```
Assets/AvatarSystem/
├── Scripts/                    (runtime assembly  AvatarUnity.asmdef)
│   ├── Core/                   AvatarState, AvatarStateController, AvatarStateRules,
│   │                           AvatarController, AvatarBootstrap,
│   │                           UnityMainThreadDispatcher, AvatarQualityLevel,
│   │                           AvatarPerformanceController
│   ├── Animation/              AvatarAnimatorController, AvatarGesture, GestureController
│   ├── Face/                   FaceChannel, AvatarEmotion, FacialExpressionController,
│   │                           EmotionController, BlinkController, EyeLookController,
│   │                           IdleBehaviourController
│   ├── LipSync/                VisemeTypes, VisemeScheduler, LipSyncController,
│   │                           AudioDrivenLipSync
│   ├── Audio/                  AvatarAudioPlayer, PcmDecoder
│   ├── Bridge/                 BridgeMessages, BridgeMessageParser, FlutterUnityBridge,
│   │                           IExternalMessageBridge
│   ├── Config/                 AvatarConfig, AvatarFaceConfig, VisemeMappingConfig
│   ├── Diagnostics/            AvatarLogLevel, AvatarLogger, AvatarDiagnostics
│   ├── Behaviour/              AvatarAppLifecycleController
│   └── Utilities/              AvatarDebugCommands, AvatarDebugHotkeys,
│                               AvatarDebugPanelController
├── Editor/                     (editor assembly   AvatarUnity.Editor.asmdef)
│   └── AvatarProjectBuilder.cs one-click setup + setup validation
├── Tests/EditMode/             (test assembly    AvatarUnity.Tests.EditMode.asmdef)
│   ├── AvatarStateRulesTests.cs
│   ├── BridgeMessageParserTests.cs
│   └── VisemeSchedulerTests.cs (+ PcmDecoderTests)
└── Documentation/              this file + protocol + model requirements
```

### State machine (single source of truth)

`AvatarStateController` (reads `AvatarStateRules`) owns the state graph:

```
Initializing → Idle → Listening → Thinking → Speaking → Idle
                    ↘             ↘              ↘
                     Error ←---------------------- 
```
Any state → `Error`; `Error` → `Idle` recover; `Speaking`/`Listening` → `Interrupted`
on barge-in; `Interrupted` → `Listening`/`Idle`. `AvatarController` exposes
`StartListening()`, `StartThinking()`, `StartSpeaking()`, `StopSpeaking()`,
`InterruptSpeech()`, `ReturnToIdle()`, `SetEmotion(...)`, `PlayGesture(...)`,
`State`, `CurrentState`, `Diagnostics`, `AudioPlayer`, `LipSync` for integration.

### Face/lips/emotion/look/blink/idle

- `FacialExpressionController` binds renderers to config `rendererKeys`, resolves
  blend-shape **indexes by name** once, and mixes four ordered layers:
  base → emotion → blink → speech. Speech owns `JawOpen/MouthClose/MouthPucker/
  MouthFunnel` channels (blocked from emotion + blink layers) so emotions never
  fight the mouth.
- `EmotionController` → EmotionChannelMapping (defined in `AvatarFaceConfig`).
- `BlinkController` random asymmetric blinks (also spoken-word blinks via
  `TriggerBlink`).
- `EyeLookController`: Animator IK when the rig is humanoid, else bone/head fallback;
  occluded by `Physics.Raycast` when a mask is supplied.
- `IdleBehaviourController`: slow breathing lookahead drift + optional
  Animator breathing triggers.
- `GestureController` + `AvatarAnimatorController`: sets Animator parameters
  (`AvatarState`, `IsListening/Thinking/Speaking`, `GestureTrigger/Id/Variant`) —
  all optional, degrades to no-op if parameters are missing.

### Lip sync + audio

- `AvatarAudioPlayer` (master clock): streamed PCM16 mono into a ring buffer; real
  playback position comes from `AudioSettings.dspTime` (`PlaybackTimeSeconds`),
  gapless, underrun-tolerant, responsive to `Pause/Resume`.
- `LipSyncController` is the canonical explicit-viseme path: `viseme.batch` items
  are queued with timestamps on the master clock and blended (`VisemeScheduler`),
  words/mouth state and barge-in cleared via `Interrupt()`.
- `AudioDrivenLipSync`: RMS-envelope fallback that is automatically suppressed
  while explicit visemes are driving the mouth.

### Bridge

`FlutterUnityBridge` (see [protocol](FLUTTER_BRIDGE_PROTOCOL.md)):
- parses inbound JSON via `BridgeMessageParser` (the **only** JSON parser),
- never throws — malformed/unknown messages are logged, counted and answered with
  `avatar.warning`,
- marshals everything onto the main thread via `UnityMainThreadDispatcher`,
- all outbound events are routed through `IExternalMessageBridge`
  (a `SendMessage`-based default; the Flutter side replaces it with its Unity
  Library message channel).

### Diagnostics & lifecycle

- `AvatarLogger` singleton writes `[Avatar]`-prefixed logs with levels.
- `AvatarDiagnostics` records fps, audio position/buffer, underruns, malformed
  messages, interruptions, errors; `diagnostics.get` returns `diagnostics.metrics`.
- `AvatarAppLifecycleController`: pauses audio / resumes on mobile background-focus,
  singleton-safe (bootstrap disables duplicates).

## Testing

Unity **EditMode** tests cover the pure logic (no scene needed): state transition
validity, JSON parsing (well-formed + malformed), viseme scheduler ordering/blending/
pruning, PCM base64 decode. Run via **Window ▸ General ▸ Test Runner ▸ EditMode**.
`AvatarProjectBuilder` and scene/prefab wiring are exercised manually in the Editor
(menu items above).

> The repo was developed standalone (no Unity install here): all runtime/editor/test
> assemblies compile clean under the dotnet compile-check harness and the EditMode
> suite passes 34/34 there.

## Mobile (Flutter embedding) notes

- Built for low-end devices: adjustable quality profiles (`avatar.quality`,
  `AvatarConfig.QualityLevel`, FPS limits), shadow/pixel-light caps, no heavy
  post-processing, screen never sleeps during a session.
- Audio is 16-bit PCM16 mono; `audio.configure` sets `sampleRate`/`channels`;
  keep chunks ≤ ~100 ms for low latency.
- The Unity project adds **no** backend/AI code and stores **no** secrets.
- When exporting as a Unity Library, disable the `DebugCanvas` and remove any
  Com./internal packages; see the Flutter integration doc for the message channel.

## Troubleshooting

- **"Animator (placeholder mode)"** → the rig has no Animator yet. Assign one.
- **Mouth does not move with speech** → blend shape names don't match the rig;
  check `AvatarFaceConfig.ChannelMappings` and remap shape names in the Inspector.
- **Renderers not found** → the model's skinned meshes must match `rendererKeys`
  (default `FaceMesh`), or bind them manually on `AvatarController`/FacialExpression
  renderers.
- **No audio** → confirm `audio.configure` before `audio.chunk`; sampleRate 8000+
  and mono. `audio.chunk` never throws — it counts and reports underruns.