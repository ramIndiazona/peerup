using UnityEngine;
using AvatarUnity.Config;
using AvatarUnity.Core;
using AvatarUnity.Diagnostics;

namespace AvatarUnity.Face
{
    /// <summary>
    /// Subtle procedural "idle life" behaviour: breathing, micro motion and tiny
    /// head sway. Everything is configurable and intentionally small in amplitude.
    /// The controller is active for Idle / Listening / Thinking and uses a reduced
    /// profile while Speaking.
    /// </summary>
    [DisallowMultipleComponent]
    public sealed class IdleBehaviourController : MonoBehaviour
    {
        [Tooltip("Root under which the avatar model sits. Breathed via subtle rotation/scale.")]
        [SerializeField] private Transform idleMotionRoot;

        [Tooltip("Optional head bone for micro head sway.")]
        [SerializeField] private Transform headBone;

        private Animator _animator;
        private AvatarConfig _config;

        private bool _breathingEnabled = true;
        private float _breathAmplitude = 0.18f;
        private float _breathFrequency = 0.55f;
        private float _breathPhase;
        private bool _microMotionEnabled = true;
        private float _microAmplitude = 0.12f;
        private bool _useIdleAnimations = true;
        private float _speakingScale = 0.3f;

        private float _phase;
        private float _microPhase;
        private float _idleAnimCooldown;
        private bool _active;
        private bool _initialized;

        private int _idleTriggerHash;
        private bool _hasIdleTrigger;

        private Quaternion _startRotation;
        private Vector3 _startScale;

        public bool IsActive => _active;

        public void Initialize(Animator animator, AvatarConfig config)
        {
            _animator = animator;
            _config = config;

            if (idleMotionRoot == null)
            {
                idleMotionRoot = transform;
            }

            if (config != null)
            {
                _breathingEnabled = config.IdleBreathingEnabled;
                _breathAmplitude = Mathf.Clamp(config.BreathingAmplitude, 0f, 3f);
                _breathFrequency = Mathf.Clamp(config.BreathingFrequency, 0.1f, 2f);
                _breathPhase = config.BreathingCyclePhase;
                _microMotionEnabled = config.IdleMicroMotionEnabled;
                _microAmplitude = Mathf.Clamp(config.MicroMotionAmplitude, 0f, 2f);
                _useIdleAnimations = config.UseIdleAnimations;
                _speakingScale = Mathf.Clamp01(config.IdleMotionSpeakingScale);
            }

            CacheStartPose();
            ResolveIdleTrigger();

            _active = true;
            _initialized = true;
            AvatarLogger.LogVerbose("IdleBehaviourController initialized.");
        }

        /// <summary>Called by the avatar controller on state changes.</summary>
        public void ApplyState(AvatarState state)
        {
            if (!_initialized)
            {
                return;
            }
            bool idle = state == AvatarState.Idle || state == AvatarState.Listening || state == AvatarState.Thinking;
            _active = idle;
            RestorePose();
        }

        /// <summary>How strong idle motion should be right now (1 while idle, reduced while speaking).</summary>
        public float CurrentMotionScale()
        {
            return _active ? 1f : _speakingScale;
        }

        private void Update()
        {
            if (!_initialized)
            {
                return;
            }

            float scale = CurrentMotionScale();
            if (scale <= 0.001f)
            {
                RestorePose();
                return;
            }

            _phase += Time.deltaTime * _breathFrequency * 2f * Mathf.PI;
            _microPhase += Time.deltaTime * 0.6f;

            if (_breathingEnabled && idleMotionRoot != null)
            {
                float breath = Mathf.Sin(_phase + _breathPhase) * _breathAmplitude * scale;
                Quaternion target = Quaternion.Euler(breath * 0.5f, breath * -0.2f, 0f);
                idleMotionRoot.localRotation = target;

                if (_startScale.sqrMagnitude > 0f)
                {
                    float pulse = 1f + Mathf.Sin(_phase + _breathPhase) * 0.0006f * _breathAmplitude * scale;
                    Vector3 s = _startScale;
                    s.y *= pulse;
                    idleMotionRoot.localScale = s;
                }
            }

            if (_microMotionEnabled && headBone != null)
            {
                float swayX = Mathf.Sin(_microPhase * 1.3f) * 0.4f * _microAmplitude * scale;
                float swayY = Mathf.Sin(_microPhase * 0.9f + 1.2f) * 0.3f * _microAmplitude * scale;
                headBone.localEulerAngles += new Vector3(swayX, swayY, 0f);
            }

            MaybeTriggerIdleAnimation();
        }

        private void MaybeTriggerIdleAnimation()
        {
            if (!_useIdleAnimations || !_hasIdleTrigger || _animator == null || !_active)
            {
                return;
            }
            if (Time.time < _idleAnimCooldown)
            {
                return;
            }
            _animator.SetTrigger(_idleTriggerHash);
            _idleAnimCooldown = Time.time + Random.Range(8f, 16f);
        }

        private void ResolveIdleTrigger()
        {
            _idleTriggerHash = Animator.StringToHash("IdleTrigger");
            if (_animator != null)
            {
                foreach (AnimatorControllerParameter parameter in _animator.parameters)
                {
                    if (parameter.type == AnimatorControllerParameterType.Trigger &&
                        parameter.nameHash == _idleTriggerHash)
                    {
                        _hasIdleTrigger = true;
                        break;
                    }
                }
            }
        }

        private void CacheStartPose()
        {
            if (idleMotionRoot != null)
            {
                _startRotation = idleMotionRoot.localRotation;
                _startScale = idleMotionRoot.localScale;
            }
        }

        private void RestorePose()
        {
            if (idleMotionRoot != null && _startScale.sqrMagnitude > 0f)
            {
                idleMotionRoot.localRotation = _startRotation;
                idleMotionRoot.localScale = _startScale;
            }
        }
    }
}