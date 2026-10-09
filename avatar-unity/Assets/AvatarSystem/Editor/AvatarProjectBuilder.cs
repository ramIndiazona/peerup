using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEditor.Events;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Events;
using UnityEngine.SceneManagement;
using UnityEngine.UI;
using AvatarUnity.Animation;
using AvatarUnity.Audio;
using AvatarUnity.Behaviour;
using AvatarUnity.Bridge;
using AvatarUnity.Config;
using AvatarUnity.Core;
using AvatarUnity.DebugTools;
using AvatarUnity.Diagnostics;
using AvatarUnity.Face;
using AvatarUnity.LipSync;

namespace AvatarUnity.EditorTools
{
    /// <summary>
    /// One-click project setup for the avatar system.
    ///
    /// Menu flow (run in order, or simply run "Avatar/Setup/Complete Setup"):
    ///   1. Create Configuration Assets   -> ScriptableObject configs with sensible defaults
    ///   2. Build Avatar Prefab            -> Assets/AvatarSystem/Prefabs/AIAvatarRoot.prefab
    ///   3. Build AITutor Scene            -> Assets/Scenes/AITutorScene.unity (prefab instance)
    ///   4. Add Debug Panel to Active Scene-> uGUI Canvas dev panel (optional)
    ///   5. Add Scene to Build Settings    -> registers AITutorScene
    ///
    /// "Validate Setup" prints a report of every required reference.
    /// </summary>
    public static class AvatarProjectBuilder
    {
        public const string ScenePath = "Assets/Scenes/AITutorScene.unity";
        public const string PrefabPath = "Assets/AvatarSystem/Prefabs/AIAvatarRoot.prefab";
        public const string ConfigDir = "Assets/AvatarSystem/ScriptableObjects";
        public const string ConfigPath = ConfigDir + "/AvatarConfig.asset";
        public const string FaceConfigPath = ConfigDir + "/AvatarFaceConfig.asset";
        public const string VisemeConfigPath = ConfigDir + "/VisemeMappingConfig.asset";

        // ------------------------------------------------------------------
        // Menu items
        // ------------------------------------------------------------------

        [MenuItem("Avatar/Setup/Complete Setup (Configurations + Prefab + Scene)")]
        public static void CompleteSetup()
        {
            CreateConfigurations();
            BuildPrefab();
            BuildScene();
            AddSceneToBuildSettings();
            // Selection.activeScene = SceneManager.GetActiveScene();
            Debug.Log("[Avatar] Complete setup finished. Open Assets/Scenes/AITutorScene.unity and press Play.");
        }

        [MenuItem("Avatar/Setup/1. Create Configuration Assets")]
        public static void CreateConfigurations()
        {
            EnsureFolder(ConfigDir);

            AvatarConfig config = LoadOrCreate<AvatarConfig>(ConfigPath, "AvatarConfig");
            AvatarFaceConfig face = LoadOrCreate<AvatarFaceConfig>(FaceConfigPath, "AvatarFaceConfig");
            VisemeMappingConfig visemes = LoadOrCreate<VisemeMappingConfig>(VisemeConfigPath, "VisemeMappingConfig");

            if (config.FaceConfig == null)
            {
                AssignRef(config, "faceConfig", face);
            }
            if (config.VisemeConfig == null)
            {
                AssignRef(config, "visemeConfig", visemes);
            }

            if (face.ChannelMappings.Count == 0)
            {
                PopulateFaceDefaults(face);
            }
            if (face.EmotionMappings.Count == 0)
            {
                PopulateEmotionDefaults(face);
            }
            if (visemes.Visemes.Count == 0)
            {
                PopulateVisemeDefaults(visemes);
            }

            EditorUtility.SetDirty(config);
            EditorUtility.SetDirty(face);
            EditorUtility.SetDirty(visemes);
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();

            Debug.Log($"[Avatar] Configuration assets ready:\n  {ConfigPath}\n  {FaceConfigPath}\n  {VisemeConfigPath}");
        }

        [MenuItem("Avatar/Setup/2. Build Avatar Prefab")]
        public static void BuildPrefab()
        {
            CreateConfigurations();
            EnsureFolder("Assets/AvatarSystem/Prefabs");

            AvatarConfig config = AssetDatabase.LoadAssetAtPath<AvatarConfig>(ConfigPath);
            AvatarFaceConfig face = AssetDatabase.LoadAssetAtPath<AvatarFaceConfig>(FaceConfigPath);
            VisemeMappingConfig visemes = AssetDatabase.LoadAssetAtPath<VisemeMappingConfig>(VisemeConfigPath);
            Material placeholderMat = LoadOrCreatePlaceholderMaterial();

            GameObject root = BuildAvatarRoot("AIAvatarRoot", config, face, visemes, placeholderMat);

            PrefabUtility.SaveAsPrefabAsset(root, PrefabPath);
            Object.DestroyImmediate(root);

            Debug.Log($"[Avatar] Prefab created: {PrefabPath}");
        }

        [MenuItem("Avatar/Setup/3. Build AITutor Scene")]
        public static void BuildScene()
        {
            CreateConfigurations();
            if (!System.IO.File.Exists(PrefabPath))
            {
                BuildPrefab();
            }

            AvatarConfig config = AssetDatabase.LoadAssetAtPath<AvatarConfig>(ConfigPath);
            AvatarFaceConfig face = AssetDatabase.LoadAssetAtPath<AvatarFaceConfig>(FaceConfigPath);
            VisemeMappingConfig visemes = AssetDatabase.LoadAssetAtPath<VisemeMappingConfig>(VisemeConfigPath);

            Scene scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            scene.name = "AITutorScene";

            // Systems
            GameObject systems = new GameObject("Systems");
            GameObject bootstrapGo = new GameObject("AvatarBootstrap");
            bootstrapGo.transform.SetParent(systems.transform);
            AvatarBootstrap bootstrap = bootstrapGo.AddComponent<AvatarBootstrap>();

            // Environment
            GameObject environment = new GameObject("Environment");

            GameObject cameraGo = new GameObject("Main Camera");
            Camera cam = cameraGo.AddComponent<Camera>();
            cameraGo.tag = "MainCamera";
            cameraGo.AddComponent<AudioListener>();
            cam.clearFlags = CameraClearFlags.SolidColor;
            cam.backgroundColor = new Color(0.075f, 0.09f, 0.12f, 1f);
            cam.fieldOfView = 55f;
            cameraGo.transform.position = new Vector3(0f, 1.5f, -2.6f);
            cameraGo.transform.LookAt(new Vector3(0f, 1.55f, 0f));
            cameraGo.transform.SetParent(environment.transform);

            GameObject lightGo = new GameObject("Directional Light");
            Light light = lightGo.AddComponent<Light>();
            light.type = LightType.Directional;
            light.intensity = 1.1f;
            light.color = new Color(1f, 0.95f, 0.9f);
            lightGo.transform.rotation = Quaternion.Euler(48f, -28f, 0f);
            lightGo.transform.SetParent(environment.transform);

            GameObject background = new GameObject("Background");
            background.transform.SetParent(environment.transform);

            // Avatar prefab instance
            Object prefab = AssetDatabase.LoadAssetAtPath<GameObject>(PrefabPath);
            GameObject avatarInstance = (GameObject)PrefabUtility.InstantiatePrefab(prefab);
            avatarInstance.name = "AIAvatarRoot";
            avatarInstance.transform.position = Vector3.zero;

            // Wire bootstrap references
            AvatarController controller = avatarInstance.GetComponent<AvatarController>();
            AssignRef(bootstrap, "avatarConfig", config);
            AssignRef(bootstrap, "faceConfig", face);
            AssignRef(bootstrap, "visemeConfig", visemes);
            AssignRef(bootstrap, "avatarController", controller);

            EditorSceneManager.MarkSceneDirty(scene);
            EditorSceneManager.SaveScene(scene, ScenePath);

            Debug.Log($"[Avatar] Scene created: {ScenePath}");
        }

        [MenuItem("Avatar/Setup/4. Add Debug Panel to Active Scene")]
        public static void AddDebugPanelToActiveScene()
        {
            if (SceneManager.GetActiveScene().IsValid() == false)
            {
                Debug.LogError("[Avatar] Open a scene first.");
                return;
            }

            AvatarController controller = Object.FindFirstObjectByType<AvatarController>();

            GameObject canvasGo = CreateDebugCanvas(controller);
            canvasGo.name = "DebugCanvas";

            if (controller != null)
            {
                AssignRef(canvasGo.GetComponentInChildren<AvatarDebugPanelController>(), "controller", controller);
            }

            EditorSceneManager.MarkSceneDirty(SceneManager.GetActiveScene());
            Debug.Log("[Avatar] Debug panel added (disable the DebugCanvas GameObject for production).");
        }

        [MenuItem("Avatar/Setup/5. Add Scene to Build Settings")]
        public static void AddSceneToBuildSettings()
        {
            if (!System.IO.File.Exists(ScenePath))
            {
                Debug.LogError($"[Avatar] Scene not found: {ScenePath}");
                return;
            }

            EditorBuildSettingsScene[] scenes = EditorBuildSettings.scenes;
            var list = new List<EditorBuildSettingsScene>(scenes);
            bool exists = false;
            for (int i = 0; i < list.Count; i++)
            {
                if (list[i].path == ScenePath)
                {
                    exists = true;
                    list[i].enabled = true;
                    break;
                }
            }
            if (!exists)
            {
                list.Add(new EditorBuildSettingsScene(ScenePath, true));
            }
            EditorBuildSettings.scenes = list.ToArray();
            Debug.Log("[Avatar] AITutorScene registered in Build Settings.");
        }

        [MenuItem("Avatar/Setup/Validate Setup")]
        public static void ValidateSetup()
        {
            Debug.Log("[Avatar] ==== Setup validation ====");

            bool configs = File.Exists(ConfigPath) && File.Exists(FaceConfigPath) && File.Exists(VisemeConfigPath);
            bool prefab = File.Exists(PrefabPath);
            bool sceneFile = File.Exists(ScenePath);

            Debug.Log($"Configurations created: {configs}");
            Debug.Log($"Prefab created:            {prefab}");
            Debug.Log($"AITutorScene created:      {sceneFile}");

            var scenes = EditorBuildSettings.scenes;
            Debug.Log($"Scene in Build Settings:  {System.Array.Exists(scenes, s => s.path == ScenePath)}");

            if (configs)
            {
                AvatarConfig c = AssetDatabase.LoadAssetAtPath<AvatarConfig>(ConfigPath);
                Debug.Log($"AvatarConfig.FaceConfig assigned:   {c != null && c.FaceConfig != null}");
                Debug.Log($"AvatarConfig.VisemeConfig assigned: {c != null && c.VisemeConfig != null}");
                Debug.Log($"Graceful placeholders only: a model/animation clips were NOT invented. Assign a real rig + blendshapes. See AVATAR_MODEL_REQUIREMENTS.md");
            }

            Debug.Log("[Avatar] ==== Validation complete ====");
        }

        // ------------------------------------------------------------------
        // Root construction
        // ------------------------------------------------------------------

        private static GameObject BuildAvatarRoot(string name, AvatarConfig config, AvatarFaceConfig face,
            VisemeMappingConfig visemes, Material placeholderMat)
        {
            GameObject root = new GameObject(name);

            // Core
            root.AddComponent<AvatarController>();
            root.AddComponent<AvatarStateController>();
            root.AddComponent<AvatarPerformanceController>();

            // Animation
            root.AddComponent<AvatarAnimatorController>();
            root.AddComponent<GestureController>();

            // Face
            FacialExpressionController faceCtrl = root.AddComponent<FacialExpressionController>();
            root.AddComponent<EmotionController>();
            root.AddComponent<BlinkController>();
            root.AddComponent<EyeLookController>();
            IdleBehaviourController idle = root.AddComponent<IdleBehaviourController>();

            // Audio + lip sync
            root.AddComponent<AudioSource>();
            root.AddComponent<AvatarAudioPlayer>();
            root.AddComponent<LipSyncController>();
            root.AddComponent<AudioDrivenLipSync>();

            // Bridge / diagnostics / lifecycle / debug
            root.AddComponent<FlutterUnityBridge>();
            root.AddComponent<AvatarDiagnostics>();
            root.AddComponent<AvatarAppLifecycleController>();
            root.AddComponent<AvatarDebugHotkeys>();

            // Config wiring
            AvatarController controller = root.GetComponent<AvatarController>();
            AssignRef(controller, "avatarConfig", config);

            // Placeholder children
            GameObject avatarModel = new GameObject("AvatarModel");
            avatarModel.transform.SetParent(root.transform);
            BuildPlaceholderModel(avatarModel, placeholderMat);

            GameObject lookTarget = new GameObject("LookTarget");
            lookTarget.transform.SetParent(root.transform);
            lookTarget.transform.position = new Vector3(0f, 1.6f, 2.5f);

            EyeLookController look = root.GetComponent<EyeLookController>();
            AssignRef(look, "lookTarget", lookTarget.transform);
            AssignRef(idle, "idleMotionRoot", avatarModel.transform);

            return root;
        }

        private static void BuildPlaceholderModel(GameObject parent, Material mat)
        {
            GameObject body = GameObject.CreatePrimitive(PrimitiveType.Capsule);
            body.name = "Body (PLACEHOLDER - replace with production model)";
            body.transform.SetParent(parent.transform);
            body.transform.localPosition = new Vector3(0f, 0.95f, 0f);
            body.transform.localScale = new Vector3(0.55f, 1.0f, 0.38f);
            SetRendererMaterial(body, mat);

            GameObject head = GameObject.CreatePrimitive(PrimitiveType.Sphere);
            head.name = "Head (PLACEHOLDER - replace with production model)";
            head.transform.SetParent(parent.transform);
            head.transform.localPosition = new Vector3(0f, 1.85f, 0f);
            head.transform.localScale = Vector3.one * 0.42f;
            SetRendererMaterial(head, mat);

            GameObject leftEye = GameObject.CreatePrimitive(PrimitiveType.Sphere);
            leftEye.name = "EyeL (placeholder)";
            leftEye.transform.SetParent(head.transform);
            leftEye.transform.localPosition = new Vector3(-0.12f, 0.02f, 0.34f);
            leftEye.transform.localScale = Vector3.one * 0.09f;
            SetRendererMaterial(leftEye, mat);

            GameObject rightEye = GameObject.CreatePrimitive(PrimitiveType.Sphere);
            rightEye.name = "EyeR (placeholder)";
            rightEye.transform.SetParent(head.transform);
            rightEye.transform.localPosition = new Vector3(0.12f, 0.02f, 0.34f);
            rightEye.transform.localScale = Vector3.one * 0.09f;
            SetRendererMaterial(rightEye, mat);
        }

        private static void SetRendererMaterial(GameObject go, Material mat)
        {
            Renderer r = go.GetComponent<Renderer>();
            if (r != null && mat != null)
            {
                r.sharedMaterial = mat;
            }
        }

        // ------------------------------------------------------------------
        // Configuration default data
        //
        // All of the nested classes (FaceShapeMapping etc.) have private serialized
        // fields, so defaults are written through the owning ScriptableObject's
        // SerializedObject. This keeps the in-memory object and the asset in sync.
        // ------------------------------------------------------------------

        private static void PopulateFaceDefaults(AvatarFaceConfig face)
        {
            SerializedObject so = SoFor(face);

            SerializedProperty keys = so.FindProperty("rendererKeys");
            if (keys == null) { LogMissing(face, "rendererKeys"); return; }
            string[] defaultKeys = { "FaceMesh", "BodyMesh" };
            keys.ClearArray();
            for (int i = 0; i < defaultKeys.Length; i++)
            {
                keys.InsertArrayElementAtIndex(keys.arraySize);
                keys.GetArrayElementAtIndex(keys.arraySize - 1).stringValue = defaultKeys[i];
            }

            SerializedProperty channels = so.FindProperty("channelMappings");
            if (channels == null) { LogMissing(face, "channelMappings"); return; }
            channels.ClearArray();

            void Add(FaceChannel channel, string rendererKey, string shape, float defaultW, float maxW, bool smooth)
            {
                channels.InsertArrayElementAtIndex(channels.arraySize);
                SerializedProperty elem = channels.GetArrayElementAtIndex(channels.arraySize - 1);
                elem.FindPropertyRelative("channel").enumValueIndex = (int)channel;
                elem.FindPropertyRelative("rendererKey").stringValue = rendererKey;
                elem.FindPropertyRelative("blendShapeName").stringValue = shape;
                elem.FindPropertyRelative("defaultWeight").floatValue = defaultW;
                elem.FindPropertyRelative("maxWeight").floatValue = maxW;
                elem.FindPropertyRelative("applySmoothing").boolValue = smooth;
            }

            Add(FaceChannel.JawOpen, "FaceMesh", "jawOpen", 0f, 1f, true);
            Add(FaceChannel.MouthClose, "FaceMesh", "mouthClose", 0f, 1f, true);
            Add(FaceChannel.MouthPucker, "FaceMesh", "mouthPucker", 0f, 1f, true);
            Add(FaceChannel.MouthFunnel, "FaceMesh", "mouthFunnel", 0f, 1f, true);
            Add(FaceChannel.MouthSmile, "FaceMesh", "mouthSmileLeft", 0f, 1f, true);
            Add(FaceChannel.MouthSmileLeft, "FaceMesh", "mouthSmileLeft", 0f, 1f, true);
            Add(FaceChannel.MouthSmileRight, "FaceMesh", "mouthSmileRight", 0f, 1f, true);
            Add(FaceChannel.MouthFrownLeft, "FaceMesh", "mouthFrownLeft", 0f, 1f, true);
            Add(FaceChannel.MouthFrownRight, "FaceMesh", "mouthFrownRight", 0f, 1f, true);
            Add(FaceChannel.EyeBlinkLeft, "FaceMesh", "eyeBlinkLeft", 0f, 1f, true);
            Add(FaceChannel.EyeBlinkRight, "FaceMesh", "eyeBlinkRight", 0f, 1f, true);
            Add(FaceChannel.EyeSquintLeft, "FaceMesh", "eyeSquintLeft", 0f, 1f, true);
            Add(FaceChannel.EyeSquintRight, "FaceMesh", "eyeSquintRight", 0f, 1f, true);
            Add(FaceChannel.BrowUpLeft, "FaceMesh", "browUpLeft", 0f, 1f, true);
            Add(FaceChannel.BrowUpRight, "FaceMesh", "browUpRight", 0f, 1f, true);
            Add(FaceChannel.BrowDownLeft, "FaceMesh", "browDownLeft", 0f, 1f, true);
            Add(FaceChannel.BrowDownRight, "FaceMesh", "browDownRight", 0f, 1f, true);
            Add(FaceChannel.CheekRaiseLeft, "FaceMesh", "cheekRaiseLeft", 0f, 1f, true);
            Add(FaceChannel.CheekRaiseRight, "FaceMesh", "cheekRaiseRight", 0f, 1f, true);

            so.ApplyModifiedPropertiesWithoutUndo();
            EditorUtility.SetDirty(face);
        }

        private static void PopulateEmotionDefaults(AvatarFaceConfig face)
        {
            SerializedObject so = SoFor(face);
            SerializedProperty emotions = so.FindProperty("emotionMappings");
            if (emotions == null) { LogMissing(face, "emotionMappings"); return; }
            emotions.ClearArray();

            void AddEmotion(AvatarEmotion emotion, params (FaceChannel c, float w)[] channels)
            {
                emotions.InsertArrayElementAtIndex(emotions.arraySize);
                SerializedProperty elem = emotions.GetArrayElementAtIndex(emotions.arraySize - 1);
                elem.FindPropertyRelative("emotion").enumValueIndex = (int)emotion;
                SerializedProperty sub = elem.FindPropertyRelative("channels");
                if (sub == null) { return; }
                sub.ClearArray();
                for (int i = 0; i < channels.Length; i++)
                {
                    sub.InsertArrayElementAtIndex(sub.arraySize);
                    SerializedProperty e = sub.GetArrayElementAtIndex(sub.arraySize - 1);
                    e.FindPropertyRelative("channel").enumValueIndex = (int)channels[i].c;
                    e.FindPropertyRelative("weight").floatValue = channels[i].w;
                }
            }

            AddEmotion(AvatarEmotion.Happy,
                (FaceChannel.MouthSmileLeft, 0.85f), (FaceChannel.MouthSmileRight, 0.85f),
                (FaceChannel.CheekRaiseLeft, 0.5f), (FaceChannel.CheekRaiseRight, 0.5f),
                (FaceChannel.EyeSquintLeft, 0.25f), (FaceChannel.EyeSquintRight, 0.25f));

            AddEmotion(AvatarEmotion.Encouraging,
                (FaceChannel.MouthSmileLeft, 0.55f), (FaceChannel.MouthSmileRight, 0.55f),
                (FaceChannel.BrowUpLeft, 0.5f), (FaceChannel.BrowUpRight, 0.5f));

            AddEmotion(AvatarEmotion.Curious,
                (FaceChannel.BrowUpLeft, 0.6f), (FaceChannel.BrowUpRight, 0.6f),
                (FaceChannel.MouthSmileLeft, 0.2f), (FaceChannel.MouthSmileRight, 0.2f));

            AddEmotion(AvatarEmotion.Thinking,
                (FaceChannel.BrowDownLeft, 0.4f), (FaceChannel.BrowDownRight, 0.4f),
                (FaceChannel.EyeSquintLeft, 0.3f), (FaceChannel.EyeSquintRight, 0.3f),
                (FaceChannel.MouthFrownLeft, 0.15f), (FaceChannel.MouthFrownRight, 0.15f));

            AddEmotion(AvatarEmotion.Excited,
                (FaceChannel.MouthSmileLeft, 0.95f), (FaceChannel.MouthSmileRight, 0.95f),
                (FaceChannel.BrowUpLeft, 0.7f), (FaceChannel.BrowUpRight, 0.7f),
                (FaceChannel.CheekRaiseLeft, 0.6f), (FaceChannel.CheekRaiseRight, 0.6f));

            AddEmotion(AvatarEmotion.Concerned,
                (FaceChannel.BrowUpLeft, 0.6f), (FaceChannel.BrowDownRight, 0.5f),
                (FaceChannel.MouthFrownLeft, 0.4f), (FaceChannel.MouthFrownRight, 0.4f));

            AddEmotion(AvatarEmotion.Surprised,
                (FaceChannel.BrowUpLeft, 0.85f), (FaceChannel.BrowUpRight, 0.85f),
                (FaceChannel.MouthSmileLeft, 0.15f), (FaceChannel.MouthSmileRight, 0.15f));

            so.ApplyModifiedPropertiesWithoutUndo();
            EditorUtility.SetDirty(face);
        }

        private static void PopulateVisemeDefaults(VisemeMappingConfig visemes)
        {
            SerializedObject so = SoFor(visemes);
            SerializedProperty neutral = so.FindProperty("neutralProviderId");
            if (neutral != null)
            {
                neutral.intValue = 0;
            }

            SerializedProperty list = so.FindProperty("visemes");
            if (list == null) { LogMissing(visemes, "visemes"); return; }
            list.ClearArray();

            void Add(int id, string name, params (FaceChannel c, float w)[] channels)
            {
                list.InsertArrayElementAtIndex(list.arraySize);
                SerializedProperty elem = list.GetArrayElementAtIndex(list.arraySize - 1);
                elem.FindPropertyRelative("providerVisemeId").intValue = id;
                elem.FindPropertyRelative("name").stringValue = name;
                elem.FindPropertyRelative("enabled").boolValue = true;
                SerializedProperty sub = elem.FindPropertyRelative("channels");
                if (sub == null) { return; }
                sub.ClearArray();
                for (int i = 0; i < channels.Length; i++)
                {
                    sub.InsertArrayElementAtIndex(sub.arraySize);
                    SerializedProperty e = sub.GetArrayElementAtIndex(sub.arraySize - 1);
                    e.FindPropertyRelative("channel").enumValueIndex = (int)channels[i].c;
                    e.FindPropertyRelative("weight").floatValue = channels[i].w;
                }
            }

            Add(0, "silence");
            Add(1, "ae/ax/ah", (FaceChannel.JawOpen, 0.55f));
            Add(2, "aa", (FaceChannel.JawOpen, 0.7f), (FaceChannel.MouthPucker, 0.2f));
            Add(3, "ao", (FaceChannel.JawOpen, 0.5f), (FaceChannel.MouthFunnel, 0.5f));
            Add(4, "ey/eh/uh", (FaceChannel.JawOpen, 0.35f), (FaceChannel.MouthSmileLeft, 0.2f), (FaceChannel.MouthSmileRight, 0.2f));
            Add(5, "er", (FaceChannel.MouthPucker, 0.35f), (FaceChannel.JawOpen, 0.2f));
            Add(6, "y/iy/ih", (FaceChannel.MouthSmileLeft, 0.6f), (FaceChannel.MouthSmileRight, 0.6f), (FaceChannel.JawOpen, 0.18f));
            Add(7, "w/uw", (FaceChannel.MouthPucker, 0.5f), (FaceChannel.MouthFunnel, 0.3f));
            Add(8, "ow", (FaceChannel.MouthFunnel, 0.4f), (FaceChannel.JawOpen, 0.3f));
            Add(9, "aw", (FaceChannel.JawOpen, 0.6f), (FaceChannel.MouthFunnel, 0.3f));
            Add(10, "oy", (FaceChannel.MouthPucker, 0.4f), (FaceChannel.MouthFunnel, 0.2f));
            Add(11, "ay", (FaceChannel.JawOpen, 0.5f), (FaceChannel.MouthSmileLeft, 0.3f), (FaceChannel.MouthSmileRight, 0.3f));
            Add(12, "h", (FaceChannel.JawOpen, 0.35f));
            Add(13, "r", (FaceChannel.MouthPucker, 0.3f));
            Add(14, "l", (FaceChannel.MouthSmileLeft, 0.25f), (FaceChannel.MouthSmileRight, 0.25f), (FaceChannel.JawOpen, 0.2f));
            Add(15, "s/z", (FaceChannel.MouthSmileLeft, 0.45f), (FaceChannel.MouthSmileRight, 0.45f), (FaceChannel.JawOpen, 0.1f));
            Add(16, "sh/ch/jh", (FaceChannel.MouthPucker, 0.3f), (FaceChannel.MouthSmileLeft, 0.3f), (FaceChannel.MouthSmileRight, 0.3f));
            Add(17, "th/dh", (FaceChannel.JawOpen, 0.2f), (FaceChannel.MouthSmileLeft, 0.15f), (FaceChannel.MouthSmileRight, 0.15f));
            Add(18, "f/v", (FaceChannel.MouthClose, 0.35f), (FaceChannel.JawOpen, 0.15f), (FaceChannel.MouthSmileLeft, 0.3f), (FaceChannel.MouthSmileRight, 0.3f));
            Add(19, "d/t/n", (FaceChannel.JawOpen, 0.3f));
            Add(20, "k/g/ng", (FaceChannel.JawOpen, 0.35f));
            Add(21, "p/b/m", (FaceChannel.MouthClose, 0.6f));

            so.ApplyModifiedPropertiesWithoutUndo();
            EditorUtility.SetDirty(visemes);
        }

        // ------------------------------------------------------------------
        // Debug canvas
        // ------------------------------------------------------------------

        private static GameObject CreateDebugCanvas(AvatarController controller)
        {
            var canvasGo = new GameObject("DebugCanvas",
                typeof(Canvas), typeof(CanvasScaler), typeof(GraphicRaycaster));
            Canvas canvas = canvasGo.GetComponent<Canvas>();
            canvas.renderMode = RenderMode.ScreenSpaceOverlay;
            CanvasScaler scaler = canvasGo.GetComponent<CanvasScaler>();
            scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
            scaler.referenceResolution = new Vector2(1280f, 720f);

            var panel = CreatePanel(canvasGo.transform, new Vector2(260f, 560f), new Vector2(10f, -10f));
            var layout = panel.GetComponent<RectTransform>();
            layout.anchorMin = new Vector2(0f, 1f);
            layout.anchorMax = new Vector2(0f, 1f);
            layout.pivot = new Vector2(0f, 1f);
            layout.sizeDelta = new Vector2(260f, 600f);

            Font font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");

            TitleText(panel.transform, font, "AVATAR DEBUG");

            AvatarDebugPanelController panelCtl = canvasGo.AddComponent<AvatarDebugPanelController>();

            var stateText = StatusText(panel.transform, font, "State: -", new Vector2(10f, -30f));
            var emotionText = StatusText(panel.transform, font, "Emotion: -", new Vector2(10f, -54f));
            var playbackText = StatusText(panel.transform, font, "Playback: -", new Vector2(10f, -78f));
            var visemeText = StatusText(panel.transform, font, "Visemes: -", new Vector2(10f, -102f));
            var fpsText = StatusText(panel.transform, font, "FPS: -", new Vector2(10f, -126f));

            AssignRef(panelCtl, "stateText", stateText);
            AssignRef(panelCtl, "emotionText", emotionText);
            AssignRef(panelCtl, "playbackText", playbackText);
            AssignRef(panelCtl, "visemeText", visemeText);
            AssignRef(panelCtl, "fpsText", fpsText);

            CreateRow1(panel.transform, font, panelCtl);
            return canvasGo;
        }

        private static Image CreatePanel(Transform parent, Vector2 size, Vector2 pos)
        {
            var go = new GameObject("Panel", typeof(RectTransform), typeof(CanvasRenderer), typeof(Image));
            go.transform.SetParent(parent, false);
            RectTransform rt = go.GetComponent<RectTransform>();
            rt.sizeDelta = size;
            rt.localPosition = pos;
            Image image = go.GetComponent<Image>();
            image.color = new Color(0.02f, 0.02f, 0.04f, 0.82f);
            return image;
        }

        private static Text TitleText(Transform parent, Font font, string value)
        {
            Text t = StatusText(parent, font, value, new Vector2(0f, 0f));
            t.fontSize = 16;
            t.color = new Color(0.6f, 0.85f, 1f);
            t.fontStyle = FontStyle.Bold;
            return t;
        }

        private static Text StatusText(Transform parent, Font font, string value, Vector2 anchoredPosition)
        {
            var go = new GameObject("Text", typeof(RectTransform), typeof(CanvasRenderer), typeof(Text));
            go.transform.SetParent(parent, false);
            RectTransform rt = go.GetComponent<RectTransform>();
            rt.anchorMin = new Vector2(0f, 1f);
            rt.anchorMax = new Vector2(0f, 1f);
            rt.pivot = new Vector2(0f, 1f);
            rt.anchoredPosition = anchoredPosition;
            rt.sizeDelta = new Vector2(240f, 22f);
            Text text = go.GetComponent<Text>();
            text.text = value;
            text.font = font;
            text.fontSize = 14;
            text.color = Color.white;
            text.alignment = TextAnchor.UpperLeft;
            return text;
        }

        private static void CreateRow1(Transform parent, Font font, AvatarDebugPanelController panelCtl)
        {
            AddButton(parent, font, "Idle", new Vector2(10f, -160f), panelCtl.OnIdle);
            AddButton(parent, font, "Listening", new Vector2(10f, -196f), panelCtl.OnListening);
            AddButton(parent, font, "Thinking", new Vector2(10f, -232f), panelCtl.OnThinking);
            AddButton(parent, font, "Speaking", new Vector2(10f, -268f), panelCtl.OnSpeaking);
            AddButton(parent, font, "Interrupt", new Vector2(10f, -304f), panelCtl.OnInterrupt);
            AddButton(parent, font, "Happy", new Vector2(10f, -340f), panelCtl.OnHappy);
            AddButton(parent, font, "Encouraging", new Vector2(10f, -376f), panelCtl.OnEncouraging);
            AddButton(parent, font, "Think", new Vector2(10f, -412f), panelCtl.OnThinkingEmotion);
            AddButton(parent, font, "Nod", new Vector2(10f, -448f), panelCtl.OnNod);
            AddButton(parent, font, "Explain", new Vector2(140f, -448f), panelCtl.OnExplain);
            AddButton(parent, font, "Celebrate", new Vector2(10f, -484f), panelCtl.OnCelebrate);
            AddButton(parent, font, "Blink", new Vector2(10f, -520f), panelCtl.OnBlink);
            AddButton(parent, font, "Test Tone", new Vector2(10f, -556f), panelCtl.OnTestTone);
            AddButton(parent, font, "Test Visemes", new Vector2(140f, -556f), panelCtl.OnTestVisemes);
        }

        private static void AddButton(Transform parent, Font font, string label, Vector2 pos, UnityAction onClick)
        {
            var go = new GameObject("Button", typeof(RectTransform), typeof(CanvasRenderer), typeof(Image));
            go.transform.SetParent(parent, false);
            RectTransform rt = go.GetComponent<RectTransform>();
            rt.anchorMin = new Vector2(0f, 1f);
            rt.anchorMax = new Vector2(0f, 1f);
            rt.pivot = new Vector2(0f, 1f);
            rt.anchoredPosition = pos;
            rt.sizeDelta = new Vector2(110f, 26f);
            Image image = go.GetComponent<Image>();
            image.color = new Color(0.16f, 0.2f, 0.28f, 1f);

            var textGo = new GameObject("Text", typeof(RectTransform), typeof(CanvasRenderer), typeof(Text));
            textGo.transform.SetParent(go.transform, false);
            Text text = textGo.GetComponent<Text>();
            text.text = label;
            text.font = font;
            text.fontSize = 12;
            text.color = Color.white;
            text.alignment = TextAnchor.MiddleCenter;
            RectTransform trt = textGo.GetComponent<RectTransform>();
            trt.anchorMin = Vector2.zero;
            trt.anchorMax = Vector2.one;
            trt.sizeDelta = Vector2.zero;

            Button button = go.AddComponent<Button>();
            button.targetGraphic = image;
            UnityEventTools.AddPersistentListener(button.onClick, onClick);
        }

        // ------------------------------------------------------------------
        // Helpers
        // ------------------------------------------------------------------

        private static T LoadOrCreate<T>(string path, string assetName) where T : ScriptableObject
        {
            T existing = AssetDatabase.LoadAssetAtPath<T>(path);
            if (existing != null)
            {
                return existing;
            }

            var created = ScriptableObject.CreateInstance<T>();
            AssetDatabase.CreateAsset(created, path);
            Debug.Log($"[Avatar] Created {assetName} at {path}");
            return created;
        }

        private static Material LoadOrCreatePlaceholderMaterial()
        {
            const string path = "Assets/AvatarSystem/Materials/Placeholder.mat";
            Material existing = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (existing != null)
            {
                return existing;
            }

            Shader shader = Shader.Find("Standard");
            if (shader == null)
            {
                return null;
            }
            var mat = new Material(shader);
            mat.color = new Color(0.72f, 0.78f, 0.85f);
            mat.SetFloat("_Metallic", 0f);
            mat.SetFloat("_Glossiness", 0.25f);
            AssetDatabase.CreateAsset(mat, path);
            return mat;
        }

        private static void EnsureFolder(string path)
        {
            string normalized = path;
            if (normalized.StartsWith("Assets/"))
            {
                normalized = normalized.Substring("Assets/".Length);
            }

            string[] parts = normalized.Split('/');
            string current = "Assets";
            foreach (string part in parts)
            {
                string candidate = current + "/" + part;
                if (!AssetDatabase.IsValidFolder(candidate))
                {
                    AssetDatabase.CreateFolder(current, part);
                }
                current = candidate;
            }
        }

        // ------------------------------------------------------------------
        // Serialized-object field helpers
        // ------------------------------------------------------------------

        private static void AssignRef(Object target, string field, Object value)
        {
            SerializedObject so = SoFor(target);
            SerializedProperty p = so.FindProperty(field);
            if (p == null) { LogMissing(target, field); return; }
            p.objectReferenceValue = value;
            so.ApplyModifiedPropertiesWithoutUndo();
        }

        private static void AssignString(Object target, string field, string value)
        {
            SerializedObject so = SoFor(target);
            SerializedProperty p = so.FindProperty(field);
            if (p == null) { LogMissing(target, field); return; }
            p.stringValue = value;
            so.ApplyModifiedPropertiesWithoutUndo();
        }

        private static void AssignInt(Object target, string field, int value)
        {
            SerializedObject so = SoFor(target);
            SerializedProperty p = so.FindProperty(field);
            if (p == null) { LogMissing(target, field); return; }
            p.intValue = value;
            so.ApplyModifiedPropertiesWithoutUndo();
        }

        private static SerializedObject SoFor(Object target)
        {
            return new SerializedObject(target);
        }

        private static void LogMissing(Object target, string field)
        {
            Debug.LogWarning($"[Avatar] Field '{field}' could not be found on {target.GetType().Name}.");
        }
    }
}