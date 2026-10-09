# Avatar Model Requirements (Unity)

How to prepare, import and wire the production avatar so the Avatar System works
out of the box. The system is **name-mapped**, never fixed-index: blend shapes and
object names are resolved once at startup from config, so misnamed shapes degrade to
"no-op" instead of breaking the avatar.

---

## 1. Hierarchy (required)

A single package root that the embedded Unity scene instantiates. Any deeper layout
is fine; wiring is done by reference/name.

```
AIAvatarRoot                       (MonoBehaviour: AvatarController, Bootstrap, …)
└── AvatarModel                    (root of the rig; assigned to AvatarController.animator)
    ├── Armature/
    │   ├── Hips, Spine, …, Head
    │   └── Head/Mouth, Head/EyeLeft, Head/EyeRight   (look-at targets, optional)
    └── FaceMesh (SkinnedMeshRenderer)                (renderer key "FaceMesh", optional)
```

- `AvatarModel` should contain the rig's **Animator** (required for Animator-based
  gestures, IK and breathing controls).
- The head, eye bones and a pelvis ("hips-like") node are used by `IdleBehaviour`/
  `BoneLook`-style fallbacks when IK is unavailable.

## 2. Skinned mesh renderers (required for facial animation)

The **face renderer** (blend shapes + skinning of the head) must be discoverable.
`AvatarFaceConfig.rendererKeys` lists logical keys (default `["FaceMesh"]`). At
startup `FacialExpressionController` binds its assigned renderers to a key by
**GameObject name** thanks to a best-effort binding step, so:

- name your face skinned mesh **`FaceMesh`** (simplest), or
- bind the renderers **manually** on the `FacialExpressionController`/`AvatarController`
  renderer slots, in the same order as `rendererKeys`.

A body renderer is optional (skin the whole body against a single mesh for
performance). Keep **one** SkinnedMeshRenderer per logical body region; the mixer
drives blend shapes per renderer.

## 3. Blend shapes (mandatory set)

The avatar's face mesh should provide these **exact blend-shape names** (ARKit
convention, as created by most character generators and used by the default config):

| Channel (logical)          | Default blend shape name |
|----------------------------|--------------------------|
| JawOpen                    | `jawOpen`                |
| MouthClose                 | `mouthClose`             |
| MouthPucker                | `mouthPucker`            |
| MouthFunnel                | `mouthFunnel`            |
| MouthSmile (L↔R auto)      | `mouthSmileLeft` / `mouthSmileRight` |
| MouthFrownLeft             | `mouthFrownLeft`         |
| MouthFrownRight            | `mouthFrownRight`        |
| EyeBlinkLeft               | `eyeBlinkLeft`           |
| EyeBlinkRight              | `eyeBlinkRight`          |
| EyeSquintLeft / Right      | `eyeSquintLeft` / `eyeSquintRight` |
| BrowUpLeft / Right         | `browUpLeft` / `browUpRight` |
| BrowDownLeft / Right       | `browDownLeft` / `browDownRight` |
| CheekRaiseLeft / Right     | `cheekRaiseLeft` / `cheekRaiseRight` |

Required for **speech**: `jawOpen` (+ ideally `mouthClosed, mouthPucker, mouthFunnel,
mouthSmileLeft/Right`) — visemes will still drive partial reconstructions without
`mouthClose`, so make sure at least `jawOpen` exists.

### If your provider uses different names
Do **not** rename assets — remap in the Inspector on the `AvatarFaceConfig` asset:
each `FaceShapeMapping` overrides `BlendShapeName`/`rendererKey`/`MaxWeight` etc.
Same works for `EmotionMappings` (emotion ⇒ per-channel weights).

## 4. Rig & Animator

- **Humanoid Avatar** is strongly recommended: enables `EyeLookController` head/bone
  IK and most animation retargeting. Generated avatars (MetaHuman, Ready Player Me,
  etc.) should be configured Humanoid in the FBX import.
- The Animator should expose **Float** parameter `AvatarState` and optional
  **Bool** `IsListening`, `IsThinking`, `IsSpeaking` and **Trigger**+
  **Int** `GestureTrigger`/`GestureVariant`. All are optional — the controllers
  detect presence and skip gracefully.
- Animator controller: any content at first; the system drives it and provides a
  default controller (`Avatar/Setup`). For full expressions you supply:
  - an **Idle** animation (breathing, drift),
  - **Getting ready/Thinking/Listening** animations,
  - per-gesture animations triggered by `GestureTrigger`.

## 5. Timeline / visemes

When your TTS/AI provider returns visemes (Azure Speech, ElevenLabs, etc.),
`avatar-unity` maps them to mouth blend shapes through `VisemeMappingConfig`
(22 entries id 0..21). The defaults assume provider IDs in **Azure-viseme order**
(0=silence, 1=`ae/ax/ah`, 2=`aa`, …, 21=`p/b/m`). Remap in the `AvatarVisemeMapping`
asset Inspector to match your provider. If you only have phonemes, map phonemes to
these IDs client-side before sending `viseme.batch`.

## 6. Textures / materials / performance

- Use **Original material** directly on the mesh, no copies per instance.
- Atlas anything skinnable; prefer a single 1024/2048 texture for face+body.
- No realtime lights beyond a shadow-casting key light; the system caps shadow
  quality + FPS per profile (`avatar.quality` / `AvatarConfig.QualityLevel`).
- Vertex limit: aim ≤ 60k vertices total on entry-level Android; enable
  **Optimize Game Objects** and GPU skinning where supported.

## 7. Import checklist

| Check | Value |
|-------|-------|
| model scale | 1 unit = 1 metre; model ~1.6–1.8 m tall |
| rig | Humanoid (or Generic + look bones) |
| animation type | Humanoid (for retargeting gestures) |
| blend shapes | enabled on the FBX (BlendShapesNormals) |
| mesh compression | on, with 30–60 Hz skinning |
| tangents/Lightmap UVs | off for runtime avatar |
| fbx normals | imported, not recomputed |

## 8. Wiring in the scene

After adding the production model, in the Inspector of `AIAvatarRoot`:

1. `AvatarController.animator` → `AvatarModel`'s `Animator`.
2. `AvatarController.avatarModelRoot`/`.faceRoot` → `AvatarModel` / face bone root.
3. `FacialExpressionController.renderers` → `[FaceMesh]` (bind by name automatically
   otherwise).
4. `AvatarController.bootstrap` assigns the config assets (`AvatarConfig`,
   `AvatarFaceConfig`, `AvatarVisemeMapping`) if not already set.
5. Run `Avatar ▸ Setup ▸ Validate Setup` — it reports which renderers/blend shapes/
   animator parameters were found and which are missing.

## 9. Placeholder → production swap

The default `Complete Setup` builds the scene with a **placeholder capsule** so you
can press Play immediately. To swap: delete/disable the placeholder skinned mesh,
drop the new model under `AIAvatarRoot`, re-point `animator` + renderer slots, and
re-run **Validate Setup**. Nothing in the runtime scripts needs editing.