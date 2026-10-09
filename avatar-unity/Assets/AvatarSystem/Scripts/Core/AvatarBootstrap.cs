using UnityEngine;
using AvatarUnity.Behaviour;
using AvatarUnity.Bridge;
using AvatarUnity.Config;
using AvatarUnity.Diagnostics;

namespace AvatarUnity.Core
{
    /// <summary>
    /// Scene bootstrap for the avatar. Loads configuration, resolves the avatar
    /// subsystems, initializes them in dependency order, verifies references and
    /// finally announces avatar.ready on the bridge.
    ///
    /// A missing model / animator / face mesh does NOT stop bootstrap — the avatar
    /// loads into a safe placeholder state and reports warnings instead.
    /// </summary>
    [DefaultExecutionOrder(-500)]
    [DisallowMultipleComponent]
    public sealed class AvatarBootstrap : MonoBehaviour
    {
        [Tooltip("Main avatar configuration. If empty, a runtime default is created.")]
        [SerializeField] private AvatarConfig avatarConfig;

        [Tooltip("Optional face config used when AvatarConfig has none assigned.")]
        [SerializeField] private AvatarFaceConfig faceConfig;

        [Tooltip("Optional viseme config used when AvatarConfig has none assigned.")]
        [SerializeField] private VisemeMappingConfig visemeConfig;

        [Tooltip("Avatar controller to drive. Resolved on this GameObject if empty.")]
        [SerializeField] private AvatarController avatarController;

        [Tooltip("Optional lifecycle handler.")]
        [SerializeField] private AvatarAppLifecycleController lifecycleController;

        [Tooltip("Optional external bridge for Flutter. Attached automatically if missing.")]
        [SerializeField] private FlutterUnityBridge bridge;

        private bool _booted;

        private void Awake()
        {
            // Ensure a main-thread dispatcher exists before anything else can enqueue.
            _ = UnityMainThreadDispatcher.Instance;
        }

        private void Start()
        {
            Boot();
        }

        /// <summary>
        /// Runs the full bootstrap sequence. Safe to call manually (idempotent).
        /// </summary>
        public void Boot()
        {
            if (_booted)
            {
                return;
            }
            _booted = true;

            AvatarConfig config = ResolveConfig();

            AvatarLogger.Configure(config != null ? config.LogLevel : AvatarLogLevel.Warning);

            AvatarController controller = ResolveController();
            if (controller == null)
            {
                AvatarLogger.LogError("AvatarBootstrap: no AvatarController found. Avatar cannot start.");
                return;
            }

            FlutterUnityBridge resolvedBridge = ResolveBridge();
            AvatarDiagnostics diagnostics = ResolveDiagnostics(controller);

            controller.SetDiagnostics(diagnostics);
            controller.InitializeInternal(config, resolvedBridge);

            AvatarAppLifecycleController lifecycle = lifecycleController;
            if (lifecycle == null)
            {
                lifecycle = GetComponentInChildren<AvatarAppLifecycleController>();
            }
            if (lifecycle != null)
            {
                lifecycle.Initialize(controller, config);
            }

            Validate(controller, config);

            resolvedBridge?.SetTarget(controller);
            resolvedBridge?.SendAvatarReady(config != null ? config.DisplayName : string.Empty);

            AvatarLogger.LogInfo("Avatar bootstrap complete. avatar.ready sent.");
        }

        private AvatarConfig ResolveConfig()
        {
            if (avatarConfig == null)
            {
                var runtime = ScriptableObject.CreateInstance<AvatarConfig>();
                runtime.AssignFaceConfig(faceConfig);
                runtime.AssignVisemeConfig(visemeConfig);
                AvatarLogger.LogWarning("AvatarConfig not assigned; using runtime defaults.");
                return runtime;
            }

            // Allow fallback sub-configs from the inspector.
            if (avatarConfig.FaceConfig == null && faceConfig != null)
            {
                avatarConfig.AssignFaceConfig(faceConfig);
            }
            if (avatarConfig.VisemeConfig == null && visemeConfig != null)
            {
                avatarConfig.AssignVisemeConfig(visemeConfig);
            }
            return avatarConfig;
        }

        private AvatarController ResolveController()
        {
            if (avatarController == null)
            {
                avatarController = FindFirstObjectByType<AvatarController>();
            }
            return avatarController;
        }

        private FlutterUnityBridge ResolveBridge()
        {
            if (bridge == null)
            {
                bridge = FindInHierarchy<FlutterUnityBridge>();
            }
            return bridge;
        }

        private AvatarDiagnostics ResolveDiagnostics(AvatarController controller)
        {
            // Prefer the controller-facing diagnostics, then look around the scene.
            if (controller != null)
            {
                AvatarDiagnostics own = controller.GetComponentInChildren<AvatarDiagnostics>(true);
                if (own != null)
                {
                    return own;
                }
            }
            return FindInHierarchy<AvatarDiagnostics>();
        }

        private T FindInHierarchy<T>() where T : Component
        {
            T found = GetComponentInChildren<T>(true);
            if (found == null && transform.parent != null)
            {
                found = transform.parent.GetComponentInChildren<T>(true);
            }
            if (found == null)
            {
                found = FindFirstObjectByType<T>();
            }
            return found;
        }

        private static void Validate(AvatarController controller, AvatarConfig config)
        {
            if (controller == null)
            {
                return;
            }
            if (config != null && config.FaceConfig == null)
            {
                AvatarLogger.LogWarning("AvatarConfig.FaceConfig is null - facial blend-shapes will not be applied.");
            }
            if (config != null && config.VisemeConfig == null)
            {
                AvatarLogger.LogWarning("AvatarConfig.VisemeConfig is null - viseme lip-sync will not be applied.");
            }
            if (controller.FacialController != null && !controller.FacialController.HasFaceRenderer)
            {
                AvatarLogger.LogWarning(
                    "No facial SkinnedMeshRenderer resolved. Assign a face mesh to FacialExpressionController " +
                    "(or child SkinnedMeshRenderer) to enable facial animation.");
            }
            if (controller.LipSync == null)
            {
                AvatarLogger.LogWarning("LipSyncController missing - no viseme lip-sync.");
            }
            if (controller.AudioPlayer == null)
            {
                AvatarLogger.LogError("AvatarAudioPlayer missing - no streaming audio.");
            }
        }
    }
}