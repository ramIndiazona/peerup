using System;
using System.Collections.Generic;
using UnityEngine;
using AvatarUnity.Audio;
using AvatarUnity.Config;
using AvatarUnity.Diagnostics;
using AvatarUnity.Face;

namespace AvatarUnity.LipSync
{
    /// <summary>
    /// Explicit viseme lip-sync. Visemes are queued with timestamps and played back
    /// against the <see cref="AvatarAudioPlayer.PlaybackTimeSeconds"/> master clock so
    /// the mouth never drifts from the actual emitted audio.
    ///
    /// Priority across the system:
    ///   1. Explicit visemes (this controller) when present.
    ///   2. Audio-driven fallback (AudioDrivenLipSync) when no visemes exist.
    ///   3. Neutral mouth otherwise.
    /// </summary>
    [DisallowMultipleComponent]
    public sealed class LipSyncController : MonoBehaviour
    {
        private struct ChannelTarget
        {
            public FaceChannel Channel;
            public float Weight;
        }

        private FacialExpressionController _facialController;
        private AvatarAudioPlayer _audioPlayer;
        private AvatarConfig _config;
        private VisemeMappingConfig _visemeConfig;

        private VisemeScheduler _scheduler;
        private readonly Dictionary<int, List<ChannelTarget>> _mappedCache = new Dictionary<int, List<ChannelTarget>>();
        private readonly Dictionary<FaceChannel, float> _frameTargets = new Dictionary<FaceChannel, float>();

        private bool _active;
        private bool _lastFrameHadViseme;
        private double _lookaheadMs = 40d;
        private double _expireWindowMs = 400d;

        /// <summary>Number of visemes still waiting to be played.</summary>
        public int QueuedCount => _scheduler != null ? _scheduler.Count : 0;

        /// <summary>True while explicit viseme lip-sync is enabled.</summary>
        public bool IsLipSyncing => _active;

        /// <summary>
        /// True when explicit visemes are actively driving the mouth right now
        /// (used by AudioDrivenLipSync to stay out of the way).
        /// </summary>
        public bool ActiveNow
        {
            get
            {
                if (!_active || _scheduler == null)
                {
                    return false;
                }
                double nowMs = NowMilliseconds();
                return _scheduler.HasActiveWithin(nowMs, _lookaheadMs);
            }
        }

        public void Initialize(FacialExpressionController facialController, AvatarAudioPlayer audioPlayer, AvatarConfig config)
        {
            _facialController = facialController;
            _audioPlayer = audioPlayer;
            _config = config;
            _visemeConfig = config != null ? config.VisemeConfig : null;

            if (config != null)
            {
                _lookaheadMs = Math.Max(0d, config.VisemeLookaheadMs);
                _expireWindowMs = _lookaheadMs + 400d;
            }

            _scheduler = new VisemeScheduler(_expireWindowMs, 400d);
            AvatarLogger.LogInfo("LipSyncController initialized.");
        }

        /// <summary>Queues a single viseme event.</summary>
        public void QueueViseme(VisemeEvent viseme)
        {
            if (viseme == null)
            {
                ReportInvalidViseme("QueueViseme called with null VisemeEvent.");
                return;
            }
            if (_scheduler == null)
            {
                return;
            }
            _scheduler.Queue(viseme);
            if (viseme.weight <= 0.001f)
            {
                AvatarLogger.LogVerbose("Viseme queued with zero weight (ok).");
            }
        }

        /// <summary>Queues a batch of viseme events.</summary>
        public void QueueVisemes(IEnumerable<VisemeEvent> visemes)
        {
            if (visemes == null)
            {
                ReportInvalidViseme("QueueVisemes called with null collection.");
                return;
            }
            if (_scheduler == null)
            {
                return;
            }
            _scheduler.QueueRange(visemes);
        }

        /// <summary>Removes all pending visemes.</summary>
        public void Clear()
        {
            _scheduler?.Clear();
        }

        /// <summary>Starts explicit viseme playback.</summary>
        public void StartLipSync()
        {
            _active = true;
            AvatarLogger.LogVerbose("LipSync started.");
        }

        /// <summary>Stops explicit viseme playback and neutralizes the mouth.</summary>
        public void StopLipSync()
        {
            _active = false;
            if (_facialController != null)
            {
                _facialController.ResetSpeech();
            }
            _lastFrameHadViseme = false;
            AvatarLogger.LogVerbose("LipSync stopped, mouth neutralized.");
        }

        /// <summary>Barge-in: clears pending visemes and neutralizes the mouth immediately.</summary>
        public void Interrupt()
        {
            Clear();
            StopLipSync();
        }

        private void Update()
        {
            if (_scheduler == null || _facialController == null)
            {
                return;
            }

            if (!_active)
            {
                if (_lastFrameHadViseme)
                {
                    _facialController.ResetSpeech();
                    _lastFrameHadViseme = false;
                }
                return;
            }

            double nowMs = NowMilliseconds();

            if (_audioPlayer != null)
            {
                bool audioActive = _audioPlayer.IsPlaying || _audioPlayer.BufferedDurationSeconds > 0.05f;
                if (!audioActive && !_scheduler.HasActiveWithin(nowMs, _lookaheadMs))
                {
                    // Speech is over; reset to neutral mouth.
                    StopLipSync();
                    return;
                }
            }

            VisemeEvent active;
            VisemeEvent next;
            float blend;
            if (!_scheduler.TrySample(nowMs, out active, out next, out blend))
            {
                _facialController.ResetSpeech();
                _lastFrameHadViseme = false;
                return;
            }

            _frameTargets.Clear();
            BlendIntoFrame(active, 1f - blend);
            BlendIntoFrame(next, blend);

            foreach (KeyValuePair<FaceChannel, float> kv in _frameTargets)
            {
                _facialController.SetSpeechValue(kv.Key, kv.Value);
            }

            _lastFrameHadViseme = true;
        }

        private void BlendIntoFrame(VisemeEvent viseme, float weight)
        {
            if (viseme == null || weight <= 0.0001f)
            {
                return;
            }

            List<ChannelTarget> targets = ResolveMapping(viseme.visemeId);
            if (targets == null || targets.Count == 0)
            {
                return;
            }

            for (int i = 0; i < targets.Count; i++)
            {
                ChannelTarget t = targets[i];
                if (t.Channel == FaceChannel.None)
                {
                    continue;
                }
                float contribution = t.Weight * viseme.weight * weight;
                float existing;
                if (_frameTargets.TryGetValue(t.Channel, out existing))
                {
                    _frameTargets[t.Channel] = Mathf.Clamp01(existing + contribution);
                }
                else
                {
                    _frameTargets[t.Channel] = Mathf.Clamp01(contribution);
                }
            }
        }

        private List<ChannelTarget> ResolveMapping(int providerVisemeId)
        {
            List<ChannelTarget> cached;
            if (_mappedCache.TryGetValue(providerVisemeId, out cached))
            {
                return cached;
            }

            cached = new List<ChannelTarget>();

            if (_visemeConfig != null)
            {
                VisemeMapping mapping = _visemeConfig.FindByProviderId(providerVisemeId);
                if (mapping != null && mapping.Channels != null)
                {
                    for (int i = 0; i < mapping.Channels.Count; i++)
                    {
                        VisemeChannelValue v = mapping.Channels[i];
                        if (v != null && v.Channel != FaceChannel.None)
                        {
                            ChannelTarget t;
                            t.Channel = v.Channel;
                            t.Weight = v.Weight;
                            cached.Add(t);
                        }
                    }
                }
                else
                {
                    AvatarLogger.LogVerbose($"Viseme provider ID {providerVisemeId} not mapped; treated as neutral.");
                }
            }

            _mappedCache[providerVisemeId] = cached;
            return cached;
        }

        private double NowMilliseconds()
        {
            if (_audioPlayer != null)
            {
                return _audioPlayer.PlaybackTimeSeconds * 1000d;
            }
            return Time.time * 1000d;
        }

        private void ReportInvalidViseme(string reason)
        {
            AvatarLogger.LogWarning(reason);
        }
    }
}