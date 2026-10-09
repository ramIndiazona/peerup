using System;
using UnityEngine;
using AvatarUnity.Core;
using AvatarUnity.Diagnostics;
using AvatarUnity.Face;
using AvatarUnity.LipSync;

// ReSharper disable FieldCanBeMadeReadOnly.Local

namespace AvatarUnity.Config
{
    /// <summary>
    /// Master tuneable configuration for the avatar. This ScriptableObject keeps the
    /// majority of numeric / behavioural values out of code. Missing values at runtime
    /// degrade to sensible built-in defaults in the consuming subsystems.
    /// </summary>
    [CreateAssetMenu(fileName = "AvatarConfig", menuName = "Avatar System/Avatar Config")]
    public sealed class AvatarConfig : ScriptableObject
    {
        [Header("Identity")]
        [SerializeField] private string displayName = "AI Tutor Avatar";

        [Header("Target Frame Rate (per quality profile)")]
        [SerializeField] private int fpsLow = 30;
        [SerializeField] private int fpsMedium = 60;
        [SerializeField] private int fpsHigh = 60;
        [SerializeField] private AvatarQualityLevel qualityLevel = AvatarQualityLevel.Medium;

        [Header("Head / Look Behaviour")]
        [SerializeField] private float maxYaw = 25f;
        [SerializeField] private float maxPitch = 18f;
        [SerializeField] private float headWeight = 0.6f;
        [SerializeField] private float eyeWeight = 0.9f;
        [SerializeField] private float lookSmoothSpeed = 6f;
        [SerializeField] private float lookTargetDistance = 1.8f;
        [SerializeField] private float microLookDeviation = 0.12f;
        [SerializeField, Range(0f, 0.6f)] private float noiseAmplitude = 0.1f;

        [Header("Blink Settings")]
        [SerializeField] private float blinkMinInterval = 1.6f;
        [SerializeField] private float blinkMaxInterval = 6.0f;
        [SerializeField, Range(0.01f, 0.5f)] private float blinkCloseDuration = 0.10f;
        [SerializeField, Range(0.01f, 0.5f)] private float blinkHoldDuration = 0.06f;
        [SerializeField, Range(0.01f, 0.5f)] private float blinkOpenDuration = 0.14f;

        [Header("Idle / Breathing")]
        [SerializeField] private bool idleBreathingEnabled = true;
        [SerializeField, Range(0f, 1f)] private float breathingAmplitude = 0.18f;
        [SerializeField, Range(0.1f, 1f)] private float breathingFrequency = 0.55f;
        [SerializeField, Range(0f, 1f)] private float breathingCyclePhase = 0f;
        [SerializeField] private bool idleMicroMotionEnabled = true;
        [SerializeField, Range(0f, 1f)] private float microMotionAmplitude = 0.12f;
        [SerializeField] private bool useIdleAnimations = true;
        [SerializeField] private float idleMotionSpeakingScale = 0.3f;

        [Header("Audio Streaming")]
        [SerializeField] private int audioSampleRate = 24000;
        [SerializeField] private int audioChannels = 1;
        [SerializeField] private float audioBufferThresholdSeconds = 0.12f;
        [SerializeField] private int audioRingBufferSeconds = 4;
        [SerializeField] private float audioUnderrunToleranceSeconds = 0.5f;

        [Header("Lip Sync")]
        [SerializeField] private float visemeLookaheadMs = 40f;
        [SerializeField] private float lipSmoothTime = 0.045f;
        [SerializeField] private float mouthResetDuration = 0.12f;
        [SerializeField] private float audioDrivenSensitivity = 1.0f;
        [SerializeField, Range(0f, 1f)] private float audioDrivenNoiseGate = 0.015f;
        [SerializeField, Range(0.001f, 0.2f)] private float audioDrivenAttack = 0.015f;
        [SerializeField, Range(0.001f, 0.2f)] private float audioDrivenRelease = 0.08f;

        [Header("Gestures")]
        [SerializeField] private float gestureCooldownSeconds = 1.0f;
        [SerializeField] private int gestureMaxRepeat = 3;
        [SerializeField] private bool blockGesturesWhileSpeaking = false;

        [Header("Behaviour")]
        [SerializeField] private bool pauseOnBackground = true;
        [SerializeField] private bool logToScreen = false;
        [SerializeField] private bool enableDebugControls = false;
        [SerializeField] private AvatarLogLevel logLevel = AvatarLogLevel.Info;

        [Header("Sub-Configuration (auto wired)")]
        [SerializeField] private AvatarFaceConfig faceConfig;
        [SerializeField] private VisemeMappingConfig visemeConfig;

        public string DisplayName => displayName;
        public int FpsLow => fpsLow;
        public int FpsMedium => fpsMedium;
        public int FpsHigh => fpsHigh;
        public AvatarQualityLevel QualityLevel => qualityLevel;

        public float MaxYaw => maxYaw;
        public float MaxPitch => maxPitch;
        public float HeadWeight => headWeight;
        public float EyeWeight => eyeWeight;
        public float LookSmoothSpeed => lookSmoothSpeed;
        public float LookTargetDistance => lookTargetDistance;
        public float MicroLookDeviation => microLookDeviation;
        public float NoiseAmplitude => noiseAmplitude;

        public float BlinkMinInterval => blinkMinInterval;
        public float BlinkMaxInterval => blinkMaxInterval;
        public float BlinkCloseDuration => blinkCloseDuration;
        public float BlinkHoldDuration => blinkHoldDuration;
        public float BlinkOpenDuration => blinkOpenDuration;

        public bool IdleBreathingEnabled => idleBreathingEnabled;
        public float BreathingAmplitude => breathingAmplitude;
        public float BreathingFrequency => breathingFrequency;
        public float BreathingCyclePhase => breathingCyclePhase;
        public bool IdleMicroMotionEnabled => idleMicroMotionEnabled;
        public float MicroMotionAmplitude => microMotionAmplitude;
        public bool UseIdleAnimations => useIdleAnimations;
        public float IdleMotionSpeakingScale => idleMotionSpeakingScale;

        public int AudioSampleRate => audioSampleRate;
        public int AudioChannels => audioChannels;
        public float AudioBufferThresholdSeconds => audioBufferThresholdSeconds;
        public int AudioRingBufferSeconds => audioRingBufferSeconds;
        public float AudioUnderrunToleranceSeconds => audioUnderrunToleranceSeconds;

        public float VisemeLookaheadMs => visemeLookaheadMs;
        public float LipSmoothTime => lipSmoothTime;
        public float MouthResetDuration => mouthResetDuration;
        public float AudioDrivenSensitivity => audioDrivenSensitivity;
        public float AudioDrivenNoiseGate => audioDrivenNoiseGate;
        public float AudioDrivenAttack => audioDrivenAttack;
        public float AudioDrivenRelease => audioDrivenRelease;

        public float GestureCooldownSeconds => gestureCooldownSeconds;
        public int GestureMaxRepeat => gestureMaxRepeat;
        public bool BlockGesturesWhileSpeaking => blockGesturesWhileSpeaking;

        public bool PauseOnBackground => pauseOnBackground;
        public bool LogToScreen => logToScreen;
        public bool EnableDebugControls => enableDebugControls;
        public AvatarLogLevel LogLevel => logLevel;

        public AvatarFaceConfig FaceConfig => faceConfig;
        public VisemeMappingConfig VisemeConfig => visemeConfig;

        /// <summary>Assigns the face configuration (used by the bootstrap fallback path).</summary>
        public void AssignFaceConfig(AvatarFaceConfig cfg)
        {
            faceConfig = cfg;
        }

        /// <summary>Assigns the viseme configuration (used by the bootstrap fallback path).</summary>
        public void AssignVisemeConfig(VisemeMappingConfig cfg)
        {
            visemeConfig = cfg;
        }
    }
}