using System.Collections.Generic;
using UnityEngine;
using AvatarUnity.Core;
using AvatarUnity.Diagnostics;

namespace AvatarUnity.Animation
{
    /// <summary>
    /// Bridges avatar behavioural state into a Unity <see cref="Animator"/>.
    ///
    /// Expected Animator parameters (all optional):
    ///   AvatarState     (int)      = Idle=0, Listening=1, Thinking=2, Speaking=3
    ///   IsListening     (bool)
    ///   IsThinking      (bool)
    ///   IsSpeaking      (bool)
    ///   GestureTrigger  (trigger)
    ///   GestureId       (int)      = (int)AvatarGesture
    ///   GestureVariant  (int)
    ///
    /// No error is thrown when the Animator Controller is a placeholder or missing
    /// parameters entirely — the system degrades gracefully.
    /// </summary>
    [DefaultExecutionOrder(100)]
    [DisallowMultipleComponent]
    public sealed class AvatarAnimatorController : MonoBehaviour
    {
        public const string ParamAvatarState = "AvatarState";
        public const string ParamIsListening = "IsListening";
        public const string ParamIsThinking = "IsThinking";
        public const string ParamIsSpeaking = "IsSpeaking";
        public const string ParamGestureTrigger = "GestureTrigger";
        public const string ParamGestureId = "GestureId";
        public const string ParamGestureVariant = "GestureVariant";

        // Animator parameter contract for the AIAvatarAnimatorController:
        // AvatarState int: 0 = Idle, 1 = Listening, 2 = Thinking, 3 = Speaking.
        public const int AnimatorStateIdle = 0;
        public const int AnimatorStateListening = 1;
        public const int AnimatorStateThinking = 2;
        public const int AnimatorStateSpeaking = 3;

        /// <summary>
        /// Maps the behavioural <see cref="AvatarState"/> enum onto the Animator's
        /// AvatarState integer contract. Values outside Idle/Listening are placeholders
        /// reserved for future Thinking/Speaking states and always fall back to Idle.
        /// </summary>
        private static int ToAnimatorState(AvatarState state)
        {
            switch (state)
            {
                case AvatarState.Idle: return AnimatorStateIdle;
                case AvatarState.Listening: return AnimatorStateListening;
                case AvatarState.Thinking: return AnimatorStateThinking;
                case AvatarState.Speaking: return AnimatorStateSpeaking;
                default: return AnimatorStateIdle;
            }
        }

        private static readonly int HashAvatarState = Animator.StringToHash(ParamAvatarState);
        private static readonly int HashIsListening = Animator.StringToHash(ParamIsListening);
        private static readonly int HashIsThinking = Animator.StringToHash(ParamIsThinking);
        private static readonly int HashIsSpeaking = Animator.StringToHash(ParamIsSpeaking);
        private static readonly int HashGestureTrigger = Animator.StringToHash(ParamGestureTrigger);
        private static readonly int HashGestureId = Animator.StringToHash(ParamGestureId);
        private static readonly int HashGestureVariant = Animator.StringToHash(ParamGestureVariant);

        private Animator _animator;
        private readonly HashSet<int> _presentParameters = new HashSet<int>();

        private AvatarState _lastState = AvatarState.Initializing;
        private bool _initialized;

        /// <summary>True when an Animator is assigned and usable.</summary>
        public bool HasAnimator => _animator != null;

        public void Initialize(Animator animator)
        {
            _animator = animator;
            _initialized = true;
            _lastState = AvatarState.Initializing;

            _presentParameters.Clear();
            if (_animator != null)
            {
                for (int i = 0; i < _animator.parameters.Length; i++)
                {
                    _presentParameters.Add(_animator.parameters[i].nameHash);
                }
            }

            if (_animator != null)
            {
                AvatarLogger.LogInfo($"AvatarAnimatorController wired to Animator '{_animator.name}'.");
                if (!HasParameter(HashAvatarState))
                {
                    AvatarLogger.LogWarning(
                        $"Animator '{_animator.name}' has no '{ParamAvatarState}' parameter. " +
                        $"Add an Int parameter named '{ParamAvatarState}' to its Animator Controller " +
                        "(and Idle=0 / Listening=1 state conditions) to drive state animation.");
                }
            }
            else
            {
                AvatarLogger.LogInfo("AvatarAnimatorController initialized WITHOUT an Animator (safe placeholder mode).");
            }
        }

        private void LateUpdate()
        {
            if (!_initialized)
            {
                return;
            }
            // Nothing needed per frame for parameter bridges; kept for future cross-fade control.
        }

        /// <summary>Applies a new avatar behavioural state to the Animator parameters.</summary>
        public void OnStateChanged(AvatarState state)
        {
            if (!_initialized)
            {
                return;
            }
            if (_animator == null)
            {
                return;
            }
            if (_lastState == state)
            {
                return;
            }
            _lastState = state;

            if (HasParameter(HashAvatarState))
            {
                _animator.SetInteger(HashAvatarState, ToAnimatorState(state));
            }
            if (HasParameter(HashIsListening))
            {
                _animator.SetBool(HashIsListening, state == AvatarState.Listening);
            }
            if (HasParameter(HashIsThinking))
            {
                _animator.SetBool(HashIsThinking, state == AvatarState.Thinking);
            }
            if (HasParameter(HashIsSpeaking))
            {
                _animator.SetBool(HashIsSpeaking, state == AvatarState.Speaking);
            }

            AvatarLogger.LogVerbose($"Animator parameters updated for state {state}.");
        }

        /// <summary>
        /// Fires a gesture trigger with an optional variant index. Returns false if the
        /// Animator is missing / lacks the trigger parameters.
        /// </summary>
        public bool ApplyGesture(AvatarGesture gesture, int variant)
        {
            if (_animator == null)
            {
                return false;
            }
            if (gesture == AvatarGesture.None)
            {
                return false;
            }

            bool hasTrigger = HasParameter(HashGestureTrigger);
            if (!hasTrigger)
            {
                AvatarLogger.LogVerbose(
                    $"Gesture '{gesture}' requested but Animator has no '{ParamGestureTrigger}' parameter.");
                return false;
            }

            if (HasParameter(HashGestureId))
            {
                _animator.SetInteger(HashGestureId, (int)gesture);
            }
            if (HasParameter(HashGestureVariant))
            {
                _animator.SetInteger(HashGestureVariant, variant);
            }
            _animator.SetTrigger(HashGestureTrigger);

            AvatarLogger.LogInfo($"Gesture triggered: {gesture} (variant {variant})");
            return true;
        }

        /// <summary>Resets a gesture trigger so gestures stop repeating.</summary>
        public void ResetGestureTrigger()
        {
            if (_animator == null || !HasParameter(HashGestureTrigger))
            {
                return;
            }
            _animator.ResetTrigger(HashGestureTrigger);
        }

        private bool HasParameter(int hash)
        {
            return _animator != null && _presentParameters.Contains(hash);
        }
    }
}