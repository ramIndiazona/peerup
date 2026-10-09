using System;
using UnityEngine;
using AvatarUnity.Diagnostics;

namespace AvatarUnity.Core
{
    /// <summary>
    /// Maintains the avatar's overall behavioural state and enforces the
    /// transition rules defined in <see cref="AvatarStateRules"/>.
    ///
    /// This component is the single source of truth for the avatar state.
    /// All other systems observe it through the <see cref="StateChanged"/> event
    /// or by polling <see cref="CurrentState"/>.
    /// </summary>
    [DisallowMultipleComponent]
    public sealed class AvatarStateController : MonoBehaviour
    {
        /// <summary>Raised whenever the state actually changes. Args: (previous, next).</summary>
        public event Action<AvatarState, AvatarState> StateChanged;

        [SerializeField] private AvatarState initialState = AvatarState.Initializing;

        private AvatarState _current;

        /// <summary>The current avatar state.</summary>
        public AvatarState CurrentState => _current;

        private void OnEnable()
        {
            if (_current == AvatarState.Initializing)
            {
                return;
            }
        }

        /// <summary>
        /// Sets the very first state. Only valid while still <see cref="AvatarState.Initializing"/>.
        /// Returns false if the avatar is already initialized.
        /// </summary>
        public bool Begin(AvatarState start)
        {
            if (_current != AvatarState.Initializing && _current != AvatarState.Error)
            {
                AvatarLogger.LogWarning("AvatarStateController.Begin called after initialization.");
                return TrySetState(start);
            }

            AvatarState previous = _current;
            _current = start;
            AvatarLogger.LogInfo($"Avatar state begin: {previous} -> {start}");
            StateChanged?.Invoke(previous, start);
            return true;
        }

        /// <summary>
        /// Attempts a transition. Invalid transitions are rejected and only logged at
        /// a low verbosity level, they never throw.
        /// </summary>
        public bool TrySetState(AvatarState next)
        {
            if (!AvatarStateRules.IsAllowed(_current, next))
            {
                AvatarLogger.LogVerbose($"Ignored invalid avatar transition {_current} -> {next}");
                return false;
            }

            if (_current == next)
            {
                return true;
            }

            AvatarState previous = _current;
            _current = next;
            AvatarLogger.LogInfo($"Avatar state: {previous} -> {next}");
            StateChanged?.Invoke(previous, next);
            return true;
        }

        /// <summary>
        /// Forces a state change bypassing the transition table.
        /// Intended for error handling / emergency resets, never for normal flow.
        /// </summary>
        public void SetState(AvatarState next)
        {
            if (_current == next)
            {
                return;
            }

            AvatarState previous = _current;
            _current = next;
            AvatarLogger.LogWarning($"Avatar state forced: {previous} -> {next}");
            StateChanged?.Invoke(previous, next);
        }
    }
}