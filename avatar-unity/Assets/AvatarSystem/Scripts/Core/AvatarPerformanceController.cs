using UnityEngine;
using AvatarUnity.Config;
using AvatarUnity.Diagnostics;

namespace AvatarUnity.Core
{
    /// <summary>
    /// Applies mobile-friendly quality profiles to the Unity engine.
    /// This module will be embedded in a Flutter app, so we keep GPU cost low
    /// and the frame rate stable. It never enables heavy effects or ray tracing.
    /// </summary>
    [DisallowMultipleComponent]
    public sealed class AvatarPerformanceController : MonoBehaviour
    {
        [SerializeField] private AvatarQualityLevel startProfile = AvatarQualityLevel.Medium;

        private AvatarConfig _config;
        private AvatarQualityLevel _active;

        /// <summary>The currently active quality profile.</summary>
        public AvatarQualityLevel ActiveProfile => _active;

        public void Initialize(AvatarConfig config)
        {
            _config = config;
            AvatarQualityLevel profile = startProfile;
            if (_config != null)
            {
                profile = _config.QualityLevel;
            }
            ApplyProfile(profile);
        }

        /// <summary>Applies a quality profile at runtime (also callable from the bridge).</summary>
        public void ApplyProfile(AvatarQualityLevel profile)
        {
            _active = profile;

            switch (profile)
            {
                case AvatarQualityLevel.Low:
                    Application.targetFrameRate = _config != null && _config.FpsLow > 0 ? _config.FpsLow : 30;
                    QualitySettings.shadowDistance = 0f;
                    QualitySettings.shadowCascades = 0;
                    QualitySettings.shadowProjection = ShadowProjection.CloseFit;
                    QualitySettings.pixelLightCount = 0;
                    QualitySettings.antiAliasing = 0;
                    QualitySettings.vSyncCount = 0;
                    QualitySettings.maximumLODLevel = 2;
                    break;

                case AvatarQualityLevel.Medium:
                    Application.targetFrameRate = _config != null && _config.FpsMedium > 0 ? _config.FpsMedium : 60;
                    QualitySettings.shadowDistance = 15f;
                    QualitySettings.shadowCascades = 1;
                    QualitySettings.shadowProjection = ShadowProjection.CloseFit;
                    QualitySettings.pixelLightCount = 1;
                    QualitySettings.antiAliasing = 2;
                    QualitySettings.vSyncCount = 0;
                    QualitySettings.maximumLODLevel = 1;
                    break;

                case AvatarQualityLevel.High:
                    Application.targetFrameRate = _config != null && _config.FpsHigh > 0 ? _config.FpsHigh : 60;
                    QualitySettings.shadowDistance = 30f;
                    QualitySettings.shadowCascades = 2;
                    QualitySettings.shadowProjection = ShadowProjection.StableFit;
                    QualitySettings.pixelLightCount = 2;
                    QualitySettings.antiAliasing = 4;
                    QualitySettings.vSyncCount = 0;
                    QualitySettings.maximumLODLevel = 0;
                    break;
            }

            // Mobile: do not turn the screen off during tutoring sessions.
            Screen.sleepTimeout = SleepTimeout.NeverSleep;

            AvatarLogger.LogInfo($"Avatar performance profile applied: {profile}, targetFPS={Application.targetFrameRate}.");
        }
    }
}