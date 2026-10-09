using UnityEngine;
using AvatarUnity.Config;
using AvatarUnity.Diagnostics;
using Random = UnityEngine.Random;

namespace AvatarUnity.Face
{
    /// <summary>
    /// Procedural random blinking driven purely via blend shapes — no animation
    /// clip required. Blinks are scheduled on a randomized interval and follow a
    /// natural close / hold / open curve. Blinking can be paused or forced.
    /// </summary>
    [DisallowMultipleComponent]
    public sealed class BlinkController : MonoBehaviour
    {
        private FacialExpressionController _facialController;
        private AvatarConfig _config;

        private float _minInterval = 1.6f;
        private float _maxInterval = 6f;
        private float _closeDuration = 0.10f;
        private float _holdDuration = 0.06f;
        private float _openDuration = 0.14f;

        private float _nextBlinkTime;
        private float _blinkStartTime;
        private bool _blinkActive;
        private bool _paused;

        private readonly float[] _eyeOffsets = { 0f, 0.006f };

        public bool IsBlinking => _blinkActive;
        public bool IsPaused => _paused;

        public void Initialize(FacialExpressionController facialController, AvatarConfig config)
        {
            _facialController = facialController;
            _config = config;

            if (config != null)
            {
                _minInterval = Mathf.Max(0.1f, config.BlinkMinInterval);
                _maxInterval = Mathf.Max(_minInterval, config.BlinkMaxInterval);
                _closeDuration = Mathf.Clamp(config.BlinkCloseDuration, 0.01f, 0.5f);
                _holdDuration = Mathf.Clamp(config.BlinkHoldDuration, 0f, 0.5f);
                _openDuration = Mathf.Clamp(config.BlinkOpenDuration, 0.01f, 0.5f);
            }

            ScheduleNext(_minInterval, _maxInterval);
            AvatarLogger.LogVerbose("BlinkController initialized.");
        }

        /// <summary>Forces a blink immediately (used by debug controls and state changes).</summary>
        public void TriggerBlink()
        {
            if (_paused || _blinkActive)
            {
                return;
            }
            StartBlink();
        }

        /// <summary>Called when the avatar starts speaking / alert states to freshen the eyes.</summary>
        public void NoteActive()
        {
            // Small chance to blink shortly after entering an active state.
            if (!_paused && !_blinkActive && Random.value < 0.6f)
            {
                ScheduleNext(0.2f, 0.9f);
            }
        }

        /// <summary>Pauses blinking (eyes stay open) - used during cutscenes / expressions.</summary>
        public void SetPaused(bool paused)
        {
            _paused = paused;
            if (paused && _blinkActive)
            {
                _blinkActive = false;
            }
        }

        private void Update()
        {
            if (_facialController == null)
            {
                return;
            }

            if (_paused)
            {
                return;
            }

            float now = Time.time;

            if (_blinkActive)
            {
                float left;
                float right;
                if (!EvalBlink(now - _blinkStartTime, out left, out right))
                {
                    // Blink finished.
                    _blinkActive = false;
                    _facialController.SetBlinkValues(0f, 0f);
                    ScheduleNext(_minInterval, _maxInterval);
                    return;
                }

                _facialController.SetBlinkValues(left, right);
            }
            else if (now >= _nextBlinkTime)
            {
                StartBlink();
            }
        }

        private void StartBlink()
        {
            _blinkStartTime = Time.time;
            _blinkActive = true;
        }

        private void ScheduleNext(float min, float max)
        {
            _nextBlinkTime = Time.time + Random.Range(min, max);
        }

        /// <summary>Evaluates natural blink amounts for both eyes. Returns false when done.</summary>
        private bool EvalBlink(float t, out float left, out float right)
        {
            left = 0f;
            right = 0f;

            float total = _closeDuration + _holdDuration + _openDuration;
            if (t >= total)
            {
                return false;
            }

            float amount;
            if (t < _closeDuration)
            {
                float k = Mathf.Clamp01(t / Mathf.Max(0.0001f, _closeDuration));
                amount = Mathf.Sin(k * Mathf.PI * 0.5f);
            }
            else if (t < _closeDuration + _holdDuration)
            {
                amount = 1f;
            }
            else
            {
                float k = Mathf.Clamp01((t - _closeDuration - _holdDuration) / Mathf.Max(0.0001f, _openDuration));
                amount = 1f - Mathf.Sin(k * Mathf.PI * 0.5f);
            }

            // Slight right-eye lag for natural asymmetry.
            float rightDelay = _eyeOffsets[1];
            float rightAmount = amount;
            if (rightDelay > 0f && t < rightDelay)
            {
                rightAmount *= Mathf.Clamp01(t / rightDelay);
            }

            left = amount;
            right = rightAmount;
            return true;
        }
    }
}