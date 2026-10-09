using System;
using UnityEngine;
using AvatarUnity.Animation;
using AvatarUnity.Audio;
using AvatarUnity.Bridge;
using AvatarUnity.Config;
using AvatarUnity.Diagnostics;
using AvatarUnity.Face;
using AvatarUnity.LipSync;

namespace AvatarUnity.Core
{
    /// <summary>
    /// Main avatar orchestrator. Owns references to every subsystem and wires
    /// them together. Subsystems are initialized in a deterministic order from
    /// <see cref="Initialize(AvatarConfig)"/>. Detailed animation, face, audio
    /// and gesture logic intentionally lives in the subsystems, not here.
    /// </summary>
    [DisallowMultipleComponent]
    public sealed class AvatarController : MonoBehaviour
    {
        public event Action<AvatarState, AvatarState> StateChanged;
        public event Action InitializationCompleted;

        // ---- Subsystem references (all optional, resolved on the same root if null) ----

        [Header("Core")]
        [SerializeField] private AvatarStateController stateController;
        [SerializeField] private Animator animator;

        [Header("Animation")]
        [SerializeField] private AvatarAnimatorController animatorController;
        [SerializeField] private GestureController gestureController;

        [Header("Face")]
        [SerializeField] private FacialExpressionController facialController;
        [SerializeField] private EmotionController emotionController;
        [SerializeField] private BlinkController blinkController;
        [SerializeField] private EyeLookController eyeLookController;
        [SerializeField] private IdleBehaviourController idleBehaviourController;

        [Header("Audio / LipSync")]
        [SerializeField] private AvatarAudioPlayer audioPlayer;
        [SerializeField] private LipSyncController lipSyncController;
        [SerializeField] private AudioDrivenLipSync audioDrivenLipSync;

        [Header("Diagnostics / Performance")]
        [SerializeField] private AvatarDiagnostics diagnostics;
        [SerializeField] private AvatarPerformanceController performanceController;

        [Header("Bridge")]
        [SerializeField] private FlutterUnityBridge bridge;

        [Header("Configuration")]
        [SerializeField] private AvatarConfig avatarConfig;

        private bool _initialized;
        private bool _isInitializing;

        /// <summary>The avatar state controller (single source of truth for state).</summary>
        public AvatarStateController State => stateController;

        /// <summary>The assigned configuration (used by debug tools).</summary>
        public AvatarConfig Config => avatarConfig;

        /// <summary>Current behaviour state.</summary>
        public AvatarState CurrentState => stateController != null ? stateController.CurrentState : AvatarState.Initializing;

        /// <summary>The streaming audio player.</summary>
        public AvatarAudioPlayer AudioPlayer => audioPlayer;

        /// <summary>The lip-sync controller.</summary>
        public LipSyncController LipSync => lipSyncController;

        /// <summary>The audio-driven fallback lip-sync.</summary>
        public AudioDrivenLipSync AudioDrivenLipSync => audioDrivenLipSync;

        /// <summary>The facial expression controller.</summary>
        public FacialExpressionController FacialController => facialController;

        /// <summary>The emotion controller.</summary>
        public EmotionController Emotions => emotionController;

        /// <summary>The gesture controller.</summary>
        public GestureController Gestures => gestureController;

        /// <summary>The diagnostics tracker.</summary>
        public AvatarDiagnostics Diagnostics => diagnostics;

        /// <summary>The Flutter bridge (may be null until wired).</summary>
        public FlutterUnityBridge Bridge => bridge;

        /// <summary>Applies a quality profile at runtime (from bridge / debug UI).</summary>
        public AvatarQualityLevel PerformanceProfile
        {
            get => performanceController != null ? performanceController.ActiveProfile : AvatarQualityLevel.Medium;
            set
            {
                if (performanceController != null)
                {
                    performanceController.ApplyProfile(value);
                }
            }
        }

        /// <summary>True once the full subsystem graph has been initialized.</summary>
        public bool IsInitialized => _initialized;

        private void Awake()
        {
            if (stateController == null)
            {
                stateController = GetComponent<AvatarStateController>();
            }
        }

        /// <summary>
        /// Internal bootstrap entry: wires the bridge, then initializes everything.
        /// </summary>
        public void InitializeInternal(AvatarConfig config, FlutterUnityBridge externalBridge)
        {
            if (externalBridge != null)
            {
                bridge = externalBridge;
            }
            Initialize(config);
        }

        /// <summary>
        /// Initializes the full subsystem graph in dependency order.
        /// Call once from <see cref="AvatarBootstrap"/> after configuration is assigned.
        /// </summary>
        public void Initialize(AvatarConfig config)
        {
            if (_initialized)
            {
                return;
            }
            if (_isInitializing)
            {
                return;
            }
            _isInitializing = true;

            avatarConfig = config ?? avatarConfig;

            ResolveReferences();

            if (stateController == null)
            {
                ReportError(new AvatarError(AvatarErrorCode.MissingAnimator, "AvatarStateController is required on the avatar root.", CurrentPlaybackTime()));
            }

            // Order matters: lower-level systems before higher-level ones.
            if (stateController != null)
            {
                stateController.StateChanged += OnStateChanged;
                stateController.Begin(AvatarState.Initializing);
            }

            if (performanceController != null && avatarConfig != null)
            {
                performanceController.Initialize(avatarConfig);
            }

            if (animatorController != null)
            {
                animatorController.Initialize(animator);
            }

            if (facialController != null && avatarConfig != null)
            {
                facialController.Initialize(avatarConfig.FaceConfig, avatarConfig);
            }

            if (emotionController != null)
            {
                emotionController.Initialize(facialController, avatarConfig);
            }

            if (blinkController != null)
            {
                blinkController.Initialize(facialController, avatarConfig);
            }

            if (eyeLookController != null)
            {
                eyeLookController.Initialize(animator, avatarConfig);
            }

            if (idleBehaviourController != null)
            {
                idleBehaviourController.Initialize(animator, avatarConfig);
            }

            if (audioPlayer != null)
            {
                audioPlayer.Initialize(avatarConfig);
                WireAudioEvents();
            }

            if (lipSyncController != null)
            {
                lipSyncController.Initialize(facialController, audioPlayer, avatarConfig);
            }

            if (audioDrivenLipSync != null)
            {
                audioDrivenLipSync.Initialize(facialController, audioPlayer, lipSyncController, avatarConfig);
            }

            if (gestureController != null)
            {
                gestureController.Initialize(animatorController, avatarConfig);
            }

            if (diagnostics != null)
            {
                diagnostics.Initialize(this);
            }

            _initialized = true;
            _isInitializing = false;

            AvatarLogger.LogInfo("AvatarController initialized.");
            InitializationCompleted?.Invoke();

            // Safe start: leave initializing, enter idle.
            stateController?.Begin(AvatarState.Idle);
        }

        /// <summary>
        /// Resolves any unassigned subsystem references by searching this
        /// GameObject (and its children via GetComponentInChildren for optional parts).
        /// </summary>
        private void ResolveReferences()
        {
            if (stateController == null) stateController = GetComponent<AvatarStateController>();
            if (animator == null)
            {
                animator = GetComponent<Animator>();
                if (animator == null)
                {
                    animator = GetComponentInChildren<Animator>(true);
                }
                if (animator != null)
                {
                    AvatarLogger.LogInfo($"AvatarController resolved Animator '{animator.name}' on GameObject '{animator.gameObject.name}'.");
                }
                else
                {
                    AvatarLogger.LogWarning(
                        "No Animator resolved on the avatar root or its children. " +
                        "State animation is disabled (safe placeholder mode). " +
                        "Assign the 'party-f-0001' Animator to AvatarController.animator in the Inspector, " +
                        "or make sure its Animator Controller exposes the Int parameter 'AvatarState'.");
                }
            }
            if (animatorController == null) animatorController = GetComponent<AvatarAnimatorController>();
            if (gestureController == null) gestureController = GetComponent<GestureController>();
            if (facialController == null) facialController = GetComponent<FacialExpressionController>();
            if (emotionController == null) emotionController = GetComponent<EmotionController>();
            if (blinkController == null) blinkController = GetComponent<BlinkController>();
            if (eyeLookController == null) eyeLookController = GetComponent<EyeLookController>();
            if (idleBehaviourController == null) idleBehaviourController = GetComponent<IdleBehaviourController>();
            if (audioPlayer == null) audioPlayer = GetComponent<AvatarAudioPlayer>();
            if (lipSyncController == null) lipSyncController = GetComponent<LipSyncController>();
            if (audioDrivenLipSync == null) audioDrivenLipSync = GetComponent<AudioDrivenLipSync>();
            if (diagnostics == null) diagnostics = GetComponent<AvatarDiagnostics>();
            if (performanceController == null) performanceController = GetComponent<AvatarPerformanceController>();
            if (bridge == null) bridge = GetComponent<FlutterUnityBridge>();
        }

        private void WireAudioEvents()
        {
            audioPlayer.OnPlaybackStarted += () => bridge?.SendAudioStarted();
            audioPlayer.OnPlaybackCompleted += () =>
            {
                bridge?.SendAudioFinished();
                bridge?.SendSpeechFinished();
            };
            audioPlayer.OnPlaybackStopped += () => bridge?.SendAudioFinished();
            audioPlayer.OnBufferUnderrun += () => bridge?.SendBufferUnderrun();
        }

        /// <summary>Wires the diagnostics tracker (used by bootstrap when it lives off-root).</summary>
        public void SetDiagnostics(AvatarDiagnostics tracker)
        {
            diagnostics = tracker;
        }

        // ------------------------------------------------------------------
        // State driven public API
        // ------------------------------------------------------------------

        public void StartListening()
        {
            if (!EnsureInitialized()) return;
            stateController?.TrySetState(AvatarState.Listening);
        }

        public void StartThinking()
        {
            if (!EnsureInitialized()) return;
            stateController?.TrySetState(AvatarState.Thinking);
        }

        public void StartSpeaking()
        {
            if (!EnsureInitialized()) return;
            stateController?.TrySetState(AvatarState.Speaking);
        }

        public void StopSpeaking()
        {
            if (!EnsureInitialized()) return;
            audioPlayer?.Clear();
            lipSyncController?.StopLipSync();
            facialController?.ResetSpeech();
            stateController?.TrySetState(AvatarState.Idle);
        }

        /// <summary>
        /// Full barge-in sequence. Immediately flushes audio, clears future visemes,
        /// neutralizes the mouth, stops the active gesture and reports the event.
        /// </summary>
        public void InterruptSpeech()
        {
            if (!EnsureInitialized()) return;

            var previous = CurrentState;

            audioPlayer?.Interrupt();
            lipSyncController?.Interrupt();
            audioDrivenLipSync?.Reset();
            facialController?.ResetSpeech();
            gestureController?.StopActiveGesture();

            stateController?.TrySetState(AvatarState.Interrupted);

            if (previous == AvatarState.Speaking || previous == AvatarState.Thinking || previous == AvatarState.Listening)
            {
                stateController?.TrySetState(AvatarState.Listening);
            }
            else
            {
                stateController?.TrySetState(AvatarState.Idle);
            }

            diagnostics?.RecordInterruption();
        }

        public void ReturnToIdle()
        {
            if (!EnsureInitialized()) return;
            audioPlayer?.Clear();
            lipSyncController?.StopLipSync();
            facialController?.ResetSpeech();
            stateController?.TrySetState(AvatarState.Idle);
        }

        public void SetEmotion(AvatarEmotion emotion, float intensity = 1f, float transitionDuration = 0.4f)
        {
            if (!EnsureInitialized()) return;
            emotionController?.SetEmotion(emotion, intensity, transitionDuration);
        }

        public bool PlayGesture(AvatarGesture gesture)
        {
            if (!EnsureInitialized()) return false;
            return gestureController != null && gestureController.PlayGesture(gesture);
        }

        // ------------------------------------------------------------------
        // Internal wiring
        // ------------------------------------------------------------------

        private void OnStateChanged(AvatarState previous, AvatarState next)
        {
            animatorController?.OnStateChanged(next);
            gestureController?.OnStateChanged(next);
            idleBehaviourController?.ApplyState(next);

            StateChanged?.Invoke(previous, next);

            if (next == AvatarState.Speaking)
            {
                blinkController?.NoteActive();
            }

            bridge?.SendStateChanged(next);
            if (diagnostics != null)
            {
                diagnostics.OnAvatarStateChanged(previous, next);
            }
        }

        private bool EnsureInitialized()
        {
            if (!_initialized)
            {
                AvatarLogger.LogWarning("AvatarController not initialized; command ignored.");
                return false;
            }
            return true;
        }

        private void ReportError(AvatarError error)
        {
            AvatarLogger.LogError(error.Message);
            if (diagnostics != null)
            {
                diagnostics.RecordError(error);
            }
            bridge?.SendAvatarError(error);
        }

        private double CurrentPlaybackTime()
        {
            return audioPlayer != null ? audioPlayer.PlaybackTimeSeconds : 0d;
        }

        private void OnDestroy()
        {
            if (stateController != null)
            {
                stateController.StateChanged -= OnStateChanged;
            }
            if (audioPlayer != null)
            {
                audioPlayer.OnPlaybackStarted -= () => bridge?.SendAudioStarted();
            }
        }
    }
}