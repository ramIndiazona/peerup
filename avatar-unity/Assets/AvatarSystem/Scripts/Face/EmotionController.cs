using System.Collections.Generic;
using UnityEngine;
using AvatarUnity.Config;
using AvatarUnity.Diagnostics;

namespace AvatarUnity.Face
{
    /// <summary>
    /// Drives facial emotion channels on top of the neutral base face.
    ///
    /// Emotion weights are written into the <see cref="FacialExpressionController"/>
    /// "emotion" layer which cannot touch speech-owned channels, so emotions never
    /// fight lip-sync over the mouth.
    /// </summary>
    [DisallowMultipleComponent]
    public sealed class EmotionController : MonoBehaviour
    {
        private FacialExpressionController _facialController;
        private AvatarConfig _config;

        private AvatarEmotion _currentEmotion = AvatarEmotion.Neutral;
        private AvatarEmotion _targetEmotion = AvatarEmotion.Neutral;
        private float _currentIntensity = 1f;
        private float _targetIntensity = 1f;
        private float _transitionDuration = 0.4f;

        private readonly Dictionary<FaceChannel, float> _currentWeights = new Dictionary<FaceChannel, float>();
        private readonly Dictionary<FaceChannel, float> _targetWeights = new Dictionary<FaceChannel, float>();

        public AvatarEmotion CurrentEmotion => _currentEmotion;
        public AvatarEmotion TargetEmotion => _targetEmotion;
        public float CurrentIntensity => _currentIntensity;
        public float TargetIntensity => _targetIntensity;

        /// <summary>Initialized by the AvatarController during bootstrap.</summary>
        public void Initialize(FacialExpressionController facialController, AvatarConfig config)
        {
            _facialController = facialController;
            _config = config;
        }

        /// <summary>
        /// Sets the desired emotion, intensity (0..1) and transition duration in seconds.
        /// The change is interpolated smoothly over <paramref name="transitionDuration"/>.
        /// </summary>
        public void SetEmotion(AvatarEmotion emotion, float intensity = 1f, float transitionDuration = 0.4f)
        {
            _targetEmotion = emotion;
            _targetIntensity = Mathf.Clamp01(intensity);
            _transitionDuration = Mathf.Max(0.01f, transitionDuration);
            AvatarLogger.LogVerbose($"Emotion target: {emotion} intensity={_targetIntensity:F2}");
        }

        /// <summary>Immediately resets emotion to neutral.</summary>
        public void Reset()
        {
            SetEmotion(AvatarEmotion.Neutral, 0f, 0.3f);
        }

        private void Update()
        {
            if (_facialController == null)
            {
                return;
            }

            RebuildTargets();

            float speed = 1f - Mathf.Exp(-Time.deltaTime / _transitionDuration);

            _currentIntensity = Mathf.Lerp(_currentIntensity, _targetIntensity, speed);
            _currentEmotion = _targetEmotion;

            foreach (KeyValuePair<FaceChannel, float> kv in _targetWeights)
            {
                float previous = _currentWeights.TryGetValue(kv.Key, out float existing) ? existing : 0f;
                float value = Mathf.Lerp(previous, kv.Value * _currentIntensity, speed);
                _currentWeights[kv.Key] = value;
                _facialController.SetEmotionValue(kv.Key, value);
            }
        }

        private void RebuildTargets()
        {
            // Union of previous + new channels: channels leaving the emotion must
            // target zero so they fade out instead of sticking forever.
            _targetWeights.Clear();
            foreach (KeyValuePair<FaceChannel, float> kv in _currentWeights)
            {
                _targetWeights[kv.Key] = 0f;
            }

            if (_targetEmotion == AvatarEmotion.Neutral)
            {
                return;
            }

            AvatarFaceConfig faceConfig = _config != null ? _config.FaceConfig : null;
            if (faceConfig == null)
            {
                return;
            }

            EmotionChannelMapping emotion = faceConfig.FindEmotion(_targetEmotion);
            if (emotion == null || emotion.Channels == null)
            {
                return;
            }

            for (int i = 0; i < emotion.Channels.Count; i++)
            {
                EmotionChannelWeight w = emotion.Channels[i];
                if (w != null && w.Channel != FaceChannel.None)
                {
                    _targetWeights[w.Channel] = Mathf.Clamp01(w.Weight);
                }
            }
        }
    }
}