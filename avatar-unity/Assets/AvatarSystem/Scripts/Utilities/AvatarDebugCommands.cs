using UnityEngine;
using AvatarUnity.Animation;
using AvatarUnity.Audio;
using AvatarUnity.Core;
using AvatarUnity.Diagnostics;
using AvatarUnity.Face;
using AvatarUnity.LipSync;

namespace AvatarUnity.DebugTools
{
    /// <summary>
    /// Reusable debug/test commands shared by the editor hotkeys and the debug panel.
    /// These are development aids only and are never required for production builds.
    /// </summary>
    public sealed class AvatarDebugCommands
    {
        private readonly AvatarController _controller;

        public AvatarDebugCommands(AvatarController controller)
        {
            _controller = controller;
        }

        public void SetIdle() => _controller?.ReturnToIdle();
        public void SetListening() => _controller?.StartListening();
        public void SetThinking() => _controller?.StartThinking();
        public void SetSpeaking() => _controller?.StartSpeaking();
        public void Interrupt() => _controller?.InterruptSpeech();

        public void SetHappy() => _controller?.SetEmotion(AvatarEmotion.Happy, 0.8f, 0.3f);
        public void SetEncouraging() => _controller?.SetEmotion(AvatarEmotion.Encouraging, 0.7f, 0.3f);
        public void SetThinkingEmotion() => _controller?.SetEmotion(AvatarEmotion.Thinking, 0.6f, 0.3f);
        public void SetNeutral() => _controller?.SetEmotion(AvatarEmotion.Neutral, 0f, 0.4f);

        public void Nod() => _controller?.PlayGesture(AvatarGesture.Nod);
        public void Explain() => _controller?.PlayGesture(AvatarGesture.Explain);
        public void Celebrate() => _controller?.PlayGesture(AvatarGesture.Celebrate);
        public void Welcome() => _controller?.PlayGesture(AvatarGesture.Welcome);

        public void TriggerBlink()
        {
            BlinkController blink = _controller != null ? _controller.GetComponent<BlinkController>() : null;
            blink?.TriggerBlink();
        }

        /// <summary>
        /// Synthesizes a short test utterance (sine tone PCM) and feeds it through the
        /// normal audio pipeline. Drives audio-driven fallback lip-sync.
        /// </summary>
        public void PlayTestTone(float seconds = 1.2f, float frequency = 260f)
        {
            AvatarAudioPlayer player = _controller != null ? _controller.AudioPlayer : null;
            if (player == null)
            {
                AvatarLogger.LogWarning("Test tone: no AvatarAudioPlayer.");
                return;
            }

            int sampleRate = player.SampleRate;
            int count = Mathf.Max(32, Mathf.RoundToInt(sampleRate * seconds));
            var samples = new float[count];
            for (int i = 0; i < count; i++)
            {
                float t = i / (float)sampleRate;
                float envelope = Mathf.Min(1f, (i / (float)sampleRate) / 0.05f) * Mathf.Min(1f, (seconds - t) / 0.1f);
                samples[i] = Mathf.Sin(2f * Mathf.PI * frequency * t) * 0.35f * Mathf.Max(0f, envelope);
            }

            _controller.StartSpeaking();
            player.Clear();
            player.EnqueueSamples(samples);
            player.EndOfStream();
            AvatarLogger.LogInfo($"Test tone queued: {seconds:F1}s @ {frequency:F0}Hz ({sampleRate}Hz).");
        }

        /// <summary>
        /// Queues a synthetic viseme sequence that matches the test tone. Cycles through
        /// all configured viseme ids while the tone plays.
        /// </summary>
        public void PlayTestVisemes(float duration = 1.2f)
        {
            LipSyncController lips = _controller != null ? _controller.LipSync : null;
            if (lips == null)
            {
                AvatarLogger.LogWarning("Test visemes: no LipSyncController.");
                return;
            }

            int stepMs = 90;
            int visemeId = 1; // skip neutral
            var events = new System.Collections.Generic.List<VisemeEvent>();
            for (double t = 40; t < duration * 1000d - 30; t += stepMs)
            {
                events.Add(new VisemeEvent(visemeId, t, 1f));
                visemeId = (visemeId % 11) + 1;
            }

            lips.Clear();
            lips.QueueVisemes(events);
            lips.StartLipSync();
            AvatarLogger.LogInfo($"Synthetic viseme sequence queued ({events.Count} events).");
        }
    }
}