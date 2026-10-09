using UnityEngine;
using AvatarUnity.Audio;
using AvatarUnity.Config;
using AvatarUnity.Diagnostics;
using AvatarUnity.Face;

namespace AvatarUnity.LipSync
{
    /// <summary>
    /// Fallback mouth animation derived from realtime audio amplitude when no
    /// explicit visemes are available. Smooth eye-safe envelope with attack/release,
    /// a configurable noise gate and sensitivity. It yields to the explicit viseme
    /// pipeline whenever <see cref="LipSyncController.ActiveNow"/> is true.
    /// </summary>
    [DisallowMultipleComponent]
    public sealed class AudioDrivenLipSync : MonoBehaviour
    {
        private FacialExpressionController _facialController;
        private AvatarAudioPlayer _audioPlayer;
        private LipSyncController _lipSyncController;
        private AvatarConfig _config;

        private float _sensitivity = 1f;
        private float _noiseGate = 0.015f;
        private float _attack = 0.015f;
        private float _release = 0.08f;

        private float _envelope;
        private float _smoothedJaw;
        private bool _initialized;

        public void Initialize(FacialExpressionController facialController, AvatarAudioPlayer audioPlayer,
            LipSyncController lipSyncController, AvatarConfig config)
        {
            _facialController = facialController;
            _audioPlayer = audioPlayer;
            _lipSyncController = lipSyncController;
            _config = config;

            if (config != null)
            {
                _sensitivity = Mathf.Max(0.1f, config.AudioDrivenSensitivity);
                _noiseGate = Mathf.Clamp01(config.AudioDrivenNoiseGate);
                _attack = Mathf.Clamp(config.AudioDrivenAttack, 0.001f, 0.3f);
                _release = Mathf.Clamp(config.AudioDrivenRelease, 0.005f, 0.5f);
            }

            _initialized = true;
            AvatarLogger.LogInfo("AudioDrivenLipSync initialized (fallback lip-sync).");
        }

        /// <summary>Resets the envelope quickly (used on interruption).</summary>
        public void Reset()
        {
            _envelope = 0f;
            _smoothedJaw = 0f;
        }

        private void Update()
        {
            if (!_initialized)
            {
                return;
            }

            // Explicit visemes win over amplitude-driven mouth.
            if (_lipSyncController != null && _lipSyncController.ActiveNow)
            {
                _facialController?.ResetSpeech();
                return;
            }

            float amplitude = _audioPlayer != null ? _audioPlayer.CurrentAmplitude : 0f;

            // Noise gate.
            if (amplitude < _noiseGate)
            {
                amplitude = 0f;
            }

            // Attack / release envelope (audiophile smoothing, no jitter).
            float coefficient = amplitude >= _envelope ? _attack : _release;
            _envelope += (amplitude - _envelope) * (1f - Mathf.Exp(-Time.deltaTime / Mathf.Max(0.001f, coefficient)));

            // Map envelope (0..1) to jaw-open amount with sensitivity + soft threshold.
            float jaw = Mathf.Clamp01(_envelope * _sensitivity);
            jaw = jaw * jaw * (3f - 2f * jaw); // smoothstep for a natural open curve

            _smoothedJaw = Mathf.Lerp(_smoothedJaw, jaw, 1f - Mathf.Exp(-Time.deltaTime * 40f));
            float finalJaw = _smoothedJaw;

            if (_facialController != null)
            {
                _facialController.SetSpeechValue(FaceChannel.JawOpen, finalJaw);
                _facialController.SetSpeechValue(FaceChannel.MouthClose, Mathf.Clamp01(1f - finalJaw) * 0.35f);
                // Mouth funnel approximates vowel-rounding from energy.
                _facialController.SetSpeechValue(FaceChannel.MouthFunnel, finalJaw * 0.25f);
            }
        }
    }
}