using System;
using System.Collections.Generic;
using UnityEngine;
using AvatarUnity.Config;
using AvatarUnity.Diagnostics;

namespace AvatarUnity.Face
{
    /// <summary>
    /// Central facial blend-shape mixer.
    ///
    /// The final weight of each <see cref="FaceChannel"/> is a combination of four
    /// independent layers that are combined (clamped) rather than overwritten:
    ///
    ///   Base (neutral defaults)
    ///   + Emotion
    ///   + Blink
    ///   + Speech (lip-sync)
    ///
    /// Blend-shape indexes are resolved by NAME at initialization from
    /// <see cref="AvatarFaceConfig"/>. No fixed numeric blend-shape indexes are used.
    ///
    /// Speech-owned channels (JawOpen, MouthClose, MouthPucker, MouthFunnel) may not
    /// be driven by emotions or blinks, so emotion and lip-sync never fight over the
    /// mouth.
    /// </summary>
    [DisallowMultipleComponent]
    public sealed class FacialExpressionController : MonoBehaviour
    {
        private struct ResolvedChannel
        {
            public FaceChannel Channel;
            public int RendererIndex;
            public int BlendShapeIndex;
            public float DefaultWeight;
            public float MaxWeight;
            public bool ApplySmoothing;
        }

        private static readonly FaceChannel[] SpeechOwnedChannels =
        {
            FaceChannel.JawOpen,
            FaceChannel.MouthClose,
            FaceChannel.MouthPucker,
            FaceChannel.MouthFunnel
        };

        [SerializeField]
        private List<SkinnedMeshRenderer> facialRenderers = new List<SkinnedMeshRenderer>();

        [Tooltip("Optional parallel keys for facialRenderers. Empty = GameObject names are used.")]
        [SerializeField]
        private List<string> rendererKeys = new List<string>();

        [SerializeField, Min(0f)] private float smoothingTime = 0.045f;

        private readonly Dictionary<FaceChannel, ResolvedChannel> _resolved =
            new Dictionary<FaceChannel, ResolvedChannel>();

        private readonly Dictionary<FaceChannel, int> _channelIndex =
            new Dictionary<FaceChannel, int>();

        private readonly List<FaceChannel> _channels = new List<FaceChannel>();

        private float[] _baseValues;
        private float[] _emotionValues;
        private float[] _speechValues;
        private float[] _blinkValues;
        private float[] _currentValues;
        private float[] _smoothVelocities;
        private float[] _maxWeights;

        private AvatarFaceConfig _faceConfig;
        private AvatarConfig _config;
        private bool _initialized;

        /// <summary>True if the controller resolved at least one usable face renderer.</summary>
        public bool HasFaceRenderer => _resolved.Count > 0;

        public IReadOnlyList<SkinnedMeshRenderer> FacialRenderers => facialRenderers;

        /// <summary>
        /// Initializes the controller by resolving the renderers and blend shapes from
        /// <see cref="AvatarFaceConfig"/>. Called by AvatarController during bootstrap.
        /// </summary>
        public void Initialize(AvatarFaceConfig faceConfig, AvatarConfig config)
        {
            _faceConfig = faceConfig;
            _config = config;

            if (_faceConfig == null)
            {
                AvatarLogger.LogWarning("AvatarFaceConfig missing; facial controller uses empty mappings (safe).");
            }

            BuildRendererKeys();

            if (facialRenderers == null || facialRenderers.Count == 0)
            {
                ResolveRenderersFromChildren();
            }

            ResetChannelState();

            if (_faceConfig != null)
            {
                int mappingCount = _faceConfig.ChannelMappings.Count;
                for (int i = 0; i < mappingCount; i++)
                {
                    FaceShapeMapping mapping = _faceConfig.ChannelMappings[i];
                    AddMapping(mapping);
                }
            }

            _initialized = true;

            int applied = _channels.Count;
            AvatarLogger.LogInfo(
                $"FacialExpressionController initialized: renderers={facialRenderers.Count}, channels={applied}.");
        }

        private void ResolveRenderersFromChildren()
        {
            SkinnedMeshRenderer[] childRenderers = GetComponentsInChildren<SkinnedMeshRenderer>(true);
            for (int i = 0; i < childRenderers.Length; i++)
            {
                facialRenderers.Add(childRenderers[i]);
            }
        }

        private void BuildRendererKeys()
        {
            if (rendererKeys != null && rendererKeys.Count == facialRenderers.Count)
            {
                return;
            }

            rendererKeys = new List<string>(facialRenderers.Count);
            for (int i = 0; i < facialRenderers.Count; i++)
            {
                SkinnedMeshRenderer r = facialRenderers[i];
                rendererKeys.Add(r != null ? r.gameObject.name : "Renderer_" + i);
            }
        }

        private void ResetChannelState()
        {
            _resolved.Clear();
            _channelIndex.Clear();
            _channels.Clear();

            // Pre-add every known channel with default weights so layers can safely
            // write on channels that have not been explicitly mapped.
            var known = (FaceChannel[])Enum.GetValues(typeof(FaceChannel));
            for (int i = 0; i < known.Length; i++)
            {
                FaceChannel channel = known[i];
                if (channel == FaceChannel.None)
                {
                    continue;
                }
                if (!_channelIndex.ContainsKey(channel))
                {
                    _channelIndex.Add(channel, _channels.Count);
                    _channels.Add(channel);
                }
            }

            int count = _channels.Count;
            _baseValues = new float[count];
            _emotionValues = new float[count];
            _speechValues = new float[count];
            _blinkValues = new float[count];
            _currentValues = new float[count];
            _smoothVelocities = new float[count];
            _maxWeights = new float[count];
        }

        private void AddMapping(FaceShapeMapping mapping)
        {
            if (mapping == null || mapping.Channel == FaceChannel.None)
            {
                return;
            }

            int rendererIndex = -1;
            if (!TryResolveRenderer(mapping.RendererKey, out rendererIndex))
            {
                AvatarLogger.LogVerbose(
                    $"Face channel '{mapping.Channel}' skipped: renderer key '{mapping.RendererKey}' not bound.");
                return;
            }

            SkinnedMeshRenderer renderer = facialRenderers[rendererIndex];
            if (renderer == null || renderer.sharedMesh == null)
            {
                AvatarLogger.LogVerbose($"Face channel '{mapping.Channel}' skipped: renderer has no mesh.");
                return;
            }

            int blendShapeIndex = renderer.sharedMesh.GetBlendShapeIndex(mapping.BlendShapeName);
            if (blendShapeIndex < 0)
            {
                AvatarLogger.LogVerbose(
                    $"Face channel '{mapping.Channel}' skipped: blend shape '{mapping.BlendShapeName}' not found on '{renderer.gameObject.name}'.");
                return;
            }

            ResolvedChannel resolved;
            resolved.RendererIndex = rendererIndex;
            resolved.BlendShapeIndex = blendShapeIndex;
            resolved.DefaultWeight = Mathf.Clamp01(mapping.DefaultWeight);
            resolved.MaxWeight = Mathf.Clamp01(mapping.MaxWeight);
            resolved.ApplySmoothing = mapping.ApplySmoothing;
            resolved.Channel = mapping.Channel;

            _resolved[mapping.Channel] = resolved;

            int idx = _channelIndex[mapping.Channel];
            _baseValues[idx] = resolved.DefaultWeight;
            _maxWeights[idx] = resolved.MaxWeight;
        }

        private bool TryResolveRenderer(string key, out int rendererIndex)
        {
            rendererIndex = -1;

            if (string.IsNullOrEmpty(key) && _faceConfig != null)
            {
                key = _faceConfig.RendererKeys.Count > 0 ? _faceConfig.RendererKeys[0] : string.Empty;
            }
            if (string.IsNullOrEmpty(key))
            {
                key = rendererKeys.Count > 0 ? rendererKeys[0] : string.Empty;
            }

            if (facialRenderers == null)
            {
                return false;
            }

            if (_faceConfig != null)
            {
                for (int i = 0; i < _faceConfig.RendererKeys.Count; i++)
                {
                    if (string.Equals(_faceConfig.RendererKeys[i], key, StringComparison.Ordinal))
                    {
                        // Prefer an explicit parallel key, otherwise first renderer.
                        for (int j = 0; j < facialRenderers.Count; j++)
                        {
                            if (j < rendererKeys.Count && string.Equals(rendererKeys[j], key, StringComparison.Ordinal))
                            {
                                rendererIndex = j;
                                return true;
                            }
                        }
                        rendererIndex = 0;
                        return rendererKeys.Count == 0 || rendererIndex < facialRenderers.Count;
                    }
                }
            }

            for (int j = 0; j < facialRenderers.Count; j++)
            {
                if (j < rendererKeys.Count && string.Equals(rendererKeys[j], key, StringComparison.Ordinal))
                {
                    rendererIndex = j;
                    return true;
                }
            }

            return false;
        }

        // ------------------------------------------------------------------
        // Public layer setters
        // ------------------------------------------------------------------

        /// <summary>Sets an emotion-driven value (normalized 0..1) for a channel.</summary>
        public void SetEmotionValue(FaceChannel channel, float value)
        {
            if (!_initialized)
            {
                return;
            }
            if (IsSpeechOwned(channel) || IsBlinkOwned(channel))
            {
                return;
            }
            if (_channelIndex.TryGetValue(channel, out int idx))
            {
                _emotionValues[idx] = Mathf.Clamp01(value);
            }
        }

        /// <summary>Sets a speech / lip-sync value (normalized 0..1) for a channel.</summary>
        public void SetSpeechValue(FaceChannel channel, float value)
        {
            if (!_initialized)
            {
                return;
            }
            if (_channelIndex.TryGetValue(channel, out int idx))
            {
                _speechValues[idx] = Mathf.Clamp01(value);
            }
        }

        /// <summary>
        /// Sets the current blink amount for both eyes. Drives EyeBlink channels only.
        /// </summary>
        public void SetBlinkValues(float left, float right)
        {
            if (!_initialized)
            {
                return;
            }
            if (_channelIndex.TryGetValue(FaceChannel.EyeBlinkLeft, out int l))
            {
                _blinkValues[l] = Mathf.Clamp01(left);
            }
            if (_channelIndex.TryGetValue(FaceChannel.EyeBlinkRight, out int r))
            {
                _blinkValues[r] = Mathf.Clamp01(right);
            }
        }

        /// <summary>Resets the speech layer to zero (with smoothing).</summary>
        public void ResetSpeech()
        {
            if (!_initialized)
            {
                return;
            }
            for (int i = 0; i < _speechValues.Length; i++)
            {
                _speechValues[i] = 0f;
            }
        }

        /// <summary>Resets all layers back to the neutral base.</summary>
        public void ResetAll()
        {
            if (!_initialized)
            {
                return;
            }
            for (int i = 0; i < _emotionValues.Length; i++)
            {
                _emotionValues[i] = 0f;
                _speechValues[i] = 0f;
                _blinkValues[i] = 0f;
            }
        }

        private void Update()
        {
            if (!_initialized)
            {
                return;
            }

            float smoothTime = _config != null ? Mathf.Max(_config.LipSmoothTime, 0.02f) : Mathf.Max(smoothingTime, 0.02f);

            for (int i = 0; i < _channels.Count; i++)
            {
                FaceChannel channel = _channels[i];
                float baseValue = i < _baseValues.Length ? _baseValues[i] : 0f;
                float emotion = IsSpeechOwned(channel) || IsBlinkOwned(channel) ? 0f : _emotionValues[i];
                float blink = IsBlinkOwned(channel) ? _blinkValues[i] : 0f;
                float speech = _speechValues[i];

                float target = Mathf.Clamp01(baseValue + emotion + blink + speech);

                float current = _currentValues[i];
                float final;
                if (_resolved.TryGetValue(channel, out ResolvedChannel rc) && rc.ApplySmoothing)
                {
                    final = Mathf.SmoothDamp(current, target, ref _smoothVelocities[i], smoothTime,
                        Mathf.Infinity, Time.deltaTime);
                }
                else
                {
                    final = target;
                    _smoothVelocities[i] = 0f;
                }

                _currentValues[i] = final;

                if (_resolved.TryGetValue(channel, out ResolvedChannel applied) &&
                    applied.RendererIndex >= 0 &&
                    applied.RendererIndex < facialRenderers.Count)
                {
                    SkinnedMeshRenderer renderer = facialRenderers[applied.RendererIndex];
                    if (renderer != null)
                    {
                        renderer.SetBlendShapeWeight(applied.BlendShapeIndex, final * applied.MaxWeight * 100f);
                    }
                }
            }
        }

        private static bool IsSpeechOwned(FaceChannel channel)
        {
            for (int i = 0; i < SpeechOwnedChannels.Length; i++)
            {
                if (SpeechOwnedChannels[i] == channel)
                {
                    return true;
                }
            }
            return false;
        }

        private static bool IsBlinkOwned(FaceChannel channel)
        {
            return channel == FaceChannel.EyeBlinkLeft || channel == FaceChannel.EyeBlinkRight;
        }
    }
}