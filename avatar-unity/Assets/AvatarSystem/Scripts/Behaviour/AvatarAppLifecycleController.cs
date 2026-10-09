using UnityEngine;
using AvatarUnity.Audio;
using AvatarUnity.Config;
using AvatarUnity.Core;
using AvatarUnity.Diagnostics;

namespace AvatarUnity.Behaviour
{
    /// <summary>
    /// Handles mobile app lifecycle events (pause / focus / quit).
    ///
    /// When the app backgrounds we pause audio and optionally lower frame cost.
    /// Flutter owns the overall app lifecycle; this only keeps the Unity runtime
    /// safe while it is backgrounded and never terminates it.
    /// </summary>
    [DisallowMultipleComponent]
    public sealed class AvatarAppLifecycleController : MonoBehaviour
    {
        [SerializeField] private AvatarController controller;
        [SerializeField] private AvatarConfig config;

        private bool _wasPlayingAudio;
        private bool _initialized;

        public void Initialize(AvatarController avatarController, AvatarConfig avatarConfig)
        {
            controller = avatarController;
            config = avatarConfig;
            _initialized = true;
        }

        private void OnApplicationPause(bool paused)
        {
            if (!_initialized)
            {
                return;
            }
            if (paused)
            {
                OnBackgrounded();
            }
            else
            {
                OnForegrounded();
            }
        }

        private void OnApplicationFocus(bool hasFocus)
        {
            if (!_initialized)
            {
                return;
            }
            if (!hasFocus)
            {
                OnBackgrounded();
            }
            else
            {
                OnForegrounded();
            }
        }

        private void OnApplicationQuit()
        {
            AvatarAudioPlayer player = controller != null ? controller.AudioPlayer : null;
            if (player != null)
            {
                player.Stop();
            }
            AvatarLogger.LogInfo("Avatar lifecycle: application quitting, audio stopped.");
        }

        private void OnBackgrounded()
        {
            bool pauseAudio = config == null || config.PauseOnBackground;
            if (pauseAudio && controller != null && controller.AudioPlayer != null)
            {
                _wasPlayingAudio = controller.AudioPlayer.IsPlaying;
                if (_wasPlayingAudio)
                {
                    controller.AudioPlayer.Pause();
                }
            }

            controller?.Bridge?.SendWarning("app.paused", "Unity application backgrounded.");
            AvatarLogger.LogInfo("Avatar lifecycle: app backgrounded.");
        }

        private void OnForegrounded()
        {
            if (controller != null && controller.AudioPlayer != null && _wasPlayingAudio)
            {
                controller.AudioPlayer.Resume();
            }
            _wasPlayingAudio = false;

            controller?.Bridge?.SendWarning("app.resumed", "Unity application foregrounded.");
            AvatarLogger.LogInfo("Avatar lifecycle: app foregrounded.");
        }
    }
}