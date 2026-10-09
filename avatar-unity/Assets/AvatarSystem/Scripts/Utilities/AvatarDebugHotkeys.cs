using UnityEngine;
using AvatarUnity.Core;
using AvatarUnity.Config;
using AvatarUnity.Diagnostics;

#if ENABLE_LEGACY_INPUT_MANAGER

namespace AvatarUnity.DebugTools
{
    /// <summary>
    /// Keyboard debug shortcuts usable inside the Unity Editor (and optionally in
    /// test builds when AvatarConfig.enableDebugControls is true).
    ///
    ///   1 = Idle             6 = Happy
    ///   2 = Listening        7 = Encouraging
    ///   3 = Thinking         8 = Thinking emotion
    ///   4 = Speaking         B = Force blink
    ///   5 = Interrupt        M = Test tone + audio-driven mouth
    ///   N = Nod              V = Test synthetic viseme sequence
    ///   C = Celebrate
    /// </summary>
    [DisallowMultipleComponent]
    public sealed class AvatarDebugHotkeys : MonoBehaviour
    {
        private AvatarController _controller;
        private AvatarDebugCommands _commands;
        private AvatarConfig _config;
        private bool _usable;

        private void Start()
        {
            // Self-initializing development aid. Finds the avatar once at start.
            AvatarController controller = Object.FindFirstObjectByType<AvatarController>();
            Initialize(controller, controller != null ? controller.Config : null);
        }

        public void Initialize(AvatarController controller, AvatarConfig config)
        {
            _controller = controller;
            _config = config;
            _commands = new AvatarDebugCommands(controller);
            _usable = controller != null;
        }

        private void Update()
        {
            if (!_usable || _commands == null)
            {
                return;
            }

#if UNITY_EDITOR
            bool allowed = true;
#else
            bool allowed = _config != null && _config.EnableDebugControls;
#endif
            if (!allowed)
            {
                return;
            }

            if (Input.GetKeyDown(KeyCode.Alpha1)) _commands.SetIdle();
            else if (Input.GetKeyDown(KeyCode.Alpha2)) _commands.SetListening();
            else if (Input.GetKeyDown(KeyCode.Alpha3)) _commands.SetThinking();
            else if (Input.GetKeyDown(KeyCode.Alpha4)) _commands.SetSpeaking();
            else if (Input.GetKeyDown(KeyCode.Alpha5)) _commands.Interrupt();
            else if (Input.GetKeyDown(KeyCode.Alpha6)) _commands.SetHappy();
            else if (Input.GetKeyDown(KeyCode.Alpha7)) _commands.SetEncouraging();
            else if (Input.GetKeyDown(KeyCode.Alpha8)) _commands.SetThinkingEmotion();
            else if (Input.GetKeyDown(KeyCode.B)) _commands.TriggerBlink();
            else if (Input.GetKeyDown(KeyCode.M)) _commands.PlayTestTone();
            else if (Input.GetKeyDown(KeyCode.V)) _commands.PlayTestVisemes();
            else if (Input.GetKeyDown(KeyCode.N)) _commands.Nod();
            else if (Input.GetKeyDown(KeyCode.C)) _commands.Celebrate();
        }
    }
}

#endif