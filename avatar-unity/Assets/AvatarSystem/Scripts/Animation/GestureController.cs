using System;
using UnityEngine;
using AvatarUnity.Config;
using AvatarUnity.Core;
using AvatarUnity.Diagnostics;

namespace AvatarUnity.Animation
{
    /// <summary>
    /// Triggers body gestures on the avatar. Enforces a per-gesture cooldown and
    /// limits how many times the same gesture can repeat in a row, so the avatar
    /// does not look mechanical. Gesture playback never stops speech unless the
    /// production workspace chooses to interrupt on gesture (not the default).
    /// </summary>
    [DisallowMultipleComponent]
    public sealed class GestureController : MonoBehaviour
    {
        public event Action<AvatarGesture> GestureStarted;
        public event Action<AvatarGesture> GestureEnded;

        private AvatarAnimatorController _animatorController;
        private AvatarConfig _config;

        private float _cooldown = 1f;
        private int _maxRepeat = 3;
        private bool _blockWhileSpeaking;

        private AvatarGesture _activeGesture = AvatarGesture.None;
        private float _activeSince;
        private int _lastSubsequent;
        private int _lastRepeatCount;
        private readonly float[] _nextAllowedAt = new float[16];

        private AvatarState _state = AvatarState.Idle;

        /// <summary>Gesture currently playing (or None).</summary>
        public AvatarGesture ActiveGesture => _activeGesture;

        public void Initialize(AvatarAnimatorController animatorController, AvatarConfig config)
        {
            _animatorController = animatorController;
            _config = config;

            if (config != null)
            {
                _cooldown = Mathf.Max(0f, config.GestureCooldownSeconds);
                _maxRepeat = Mathf.Max(1, config.GestureMaxRepeat);
                _blockWhileSpeaking = config.BlockGesturesWhileSpeaking;
            }
        }

        internal void OnStateChanged(AvatarState state)
        {
            _state = state;
            if (state == AvatarState.Idle)
            {
                ClearActiveGesture();
            }
        }

        /// <summary>
        /// Attempts to play a gesture. Returns false if the gesture is cooling down,
        /// repeating too often, blocked during speaking, or cannot reach an Animator.
        /// </summary>
        public bool PlayGesture(AvatarGesture gesture)
        {
            if (gesture == AvatarGesture.None || _animatorController == null)
            {
                return false;
            }

            if (_blockWhileSpeaking && _state == AvatarState.Speaking)
            {
                AvatarLogger.LogVerbose($"Gesture '{gesture}' blocked while speaking.");
                return false;
            }

            int id = (int)gesture;
            if (_activeGesture != AvatarGesture.None && id == (int)_activeGesture)
            {
                return false;
            }

            if (!IsAllowed(id))
            {
                AvatarLogger.LogVerbose($"Gesture '{gesture}' is cooling down.");
                return false;
            }

            int variant = 0;
            if (_lastSubsequent == id)
            {
                _lastRepeatCount++;
                variant = _lastRepeatCount % 2;
            }
            else
            {
                _lastRepeatCount = 0;
                _lastSubsequent = id;
            }

            bool applied = _animatorController.ApplyGesture(gesture, variant);
            if (!applied)
            {
                return false;
            }

            _nextAllowedAt[id] = Time.time + _cooldown;
            _activeGesture = gesture;
            _activeSince = Time.time;

            GestureStarted?.Invoke(gesture);
            AvatarLogger.LogInfo($"Gesture started: {gesture} (variant {variant})");
            return true;
        }

        /// <summary>Stops the current gesture (used on speech interruption).</summary>
        public void StopActiveGesture()
        {
            if (_activeGesture == AvatarGesture.None)
            {
                return;
            }
            AvatarGesture ended = _activeGesture;
            _activeGesture = AvatarGesture.None;
            _animatorController?.ResetGestureTrigger();
            GestureEnded?.Invoke(ended);
        }

        private void ClearActiveGesture()
        {
            if (_activeGesture == AvatarGesture.None)
            {
                return;
            }
            AvatarGesture ended = _activeGesture;
            _activeGesture = AvatarGesture.None;
            _animatorController?.ResetGestureTrigger();
            GestureEnded?.Invoke(ended);
        }

        private bool IsAllowed(int id)
        {
            if (id < 0 || id >= _nextAllowedAt.Length)
            {
                return false;
            }
            if (Time.time < _nextAllowedAt[id])
            {
                return false;
            }
            if (_lastSubsequent == id && _lastRepeatCount >= _maxRepeat)
            {
                return false;
            }
            return true;
        }
    }
}