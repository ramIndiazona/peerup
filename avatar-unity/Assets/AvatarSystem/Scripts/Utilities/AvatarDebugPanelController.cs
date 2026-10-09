using UnityEngine;
using UnityEngine.UI;
using AvatarUnity.Core;
using AvatarUnity.Diagnostics;

namespace AvatarUnity.DebugTools
{
    /// <summary>
    /// Drives the optional debug panel (created in the Editor by
    /// "Avatar/Setup/Add Debug Panel to Active Scene"). It is a development aid and
    /// never a production dependency. Fully inactive when the host GameObject is
    /// disabled (the panel is disabled for production builds).
    /// </summary>
    [DisallowMultipleComponent]
    public sealed class AvatarDebugPanelController : MonoBehaviour
    {
        [SerializeField] private AvatarController controller;

        [SerializeField] private Text fpsText;
        [SerializeField] private Text stateText;
        [SerializeField] private Text emotionText;
        [SerializeField] private Text playbackText;
        [SerializeField] private Text visemeText;

        private AvatarDebugCommands _commands;
        private float _refreshTimer;
        private bool _usable;

        public void Initialize(AvatarController avatarController)
        {
            controller = avatarController;
            _commands = new AvatarDebugCommands(controller);
            _usable = controller != null;
        }

        private void Update()
        {
            if (!_usable)
            {
                return;
            }
            _refreshTimer -= Time.unscaledDeltaTime;
            if (_refreshTimer > 0f)
            {
                return;
            }
            _refreshTimer = 0.25f;
            Refresh();
        }

        private void Refresh()
        {
            if (controller == null || controller.Diagnostics == null)
            {
                return;
            }

            AvatarController c = controller;
            double playback = c.AudioPlayer != null ? c.AudioPlayer.PlaybackTimeSeconds : 0d;
            int queued = c.LipSync != null ? c.LipSync.QueuedCount : 0;
            float buffered = c.AudioPlayer != null ? c.AudioPlayer.BufferedDurationSeconds : 0f;

            if (fpsText != null) fpsText.text = "FPS: " + controller.Diagnostics.GetSnapshot().fps.ToString("F0");
            if (stateText != null) stateText.text = "State: " + c.CurrentState;
            if (emotionText != null) emotionText.text = "Emotion: " + (c.Emotions != null ? c.Emotions.CurrentEmotion.ToString() : "-");
            if (playbackText != null) playbackText.text = "Playback: " + playback.ToString("F2") + "s  Buffered: " + buffered.ToString("F2") + "s";
            if (visemeText != null) visemeText.text = "Visemes queued: " + queued;
        }

        // ---- Buttons ----

        public void OnIdle() => _commands?.SetIdle();
        public void OnListening() => _commands?.SetListening();
        public void OnThinking() => _commands?.SetThinking();
        public void OnSpeaking() => _commands?.SetSpeaking();
        public void OnInterrupt() => _commands?.Interrupt();
        public void OnHappy() => _commands?.SetHappy();
        public void OnEncouraging() => _commands?.SetEncouraging();
        public void OnThinkingEmotion() => _commands?.SetThinkingEmotion();
        public void OnNeutral() => _commands?.SetNeutral();
        public void OnNod() => _commands?.Nod();
        public void OnExplain() => _commands?.Explain();
        public void OnCelebrate() => _commands?.Celebrate();
        public void OnBlink() => _commands?.TriggerBlink();
        public void OnTestTone() => _commands?.PlayTestTone();
        public void OnTestVisemes() => _commands?.PlayTestVisemes();
    }
}