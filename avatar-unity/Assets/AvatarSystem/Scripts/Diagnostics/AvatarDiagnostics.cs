using System;
using UnityEngine;
using AvatarUnity.Animation;
using AvatarUnity.Audio;
using AvatarUnity.Core;
using AvatarUnity.Face;
using AvatarUnity.LipSync;

namespace AvatarUnity.Diagnostics
{
    /// <summary>
    /// Tracks structured diagnostics for the whole avatar.
    /// Produces JSON snapshots that can be pushed to Flutter.
    /// </summary>
    [DisallowMultipleComponent]
    public sealed class AvatarDiagnostics : MonoBehaviour
    {
        [Serializable]
        public struct Snapshot
        {
            public string state;
            public float fps;
            public double audioPlaybackTime;
            public float audioBufferSeconds;
            public int audioUnderruns;
            public int queuedVisemes;
            public int bridgeMessagesReceived;
            public int malformedMessages;
            public int interruptions;
            public int errors;
            public string lastErrorCode;
            public string emotion;
            public string gesture;
        }

        private AvatarController _controller;

        // Counters
        private float _fps;
        private float _fpsAccumulatedFrames;
        private float _fpsAccumulatedTime;
        private int _audioUnderruns;
        private int _visemesQueued;
        private int _bridgeMessagesReceived;
        private int _malformedMessages;
        private int _interruptions;
        private int _errorCount;
        private string _lastErrorCode = "None";

        public int AudioUnderrunCount => _audioUnderruns;
        public int QueuedVisemeCount => _visemesQueued;
        public int BridgeMessagesReceivedCount => _bridgeMessagesReceived;
        public int MalformedMessageCount => _malformedMessages;
        public int InterruptionCount => _interruptions;
        public int ErrorCount => _errorCount;

        public void Initialize(AvatarController controller)
        {
            _controller = controller;
        }

        private void Update()
        {
            _fpsAccumulatedFrames += 1f;
            _fpsAccumulatedTime += Time.unscaledDeltaTime;
            if (_fpsAccumulatedTime >= 0.5f)
            {
                _fps = _fpsAccumulatedFrames / _fpsAccumulatedTime;
                _fpsAccumulatedFrames = 0f;
                _fpsAccumulatedTime = 0f;
            }
        }

        internal void OnAvatarStateChanged(AvatarState previous, AvatarState next)
        {
            // State is read live from the controller; nothing to store here.
        }

        public void RecordBridgeMessage() => _bridgeMessagesReceived++;
        public void RecordMalformedMessage() => _malformedMessages++;
        public void RecordInterruption() => _interruptions++;
        public void RecordVisemesQueued(int count) => _visemesQueued += Mathf.Max(0, count);

        public void RecordError(in Core.AvatarError error)
        {
            _errorCount++;
            _lastErrorCode = error.Code.ToString();
        }

        public void RecordAudioUnderrun()
        {
            _audioUnderruns++;
        }

        /// <summary>Builds a current snapshot of the avatar diagnostics.</summary>
        public Snapshot GetSnapshot()
        {
            var snap = new Snapshot();
            snap.state = _controller != null ? _controller.CurrentState.ToString() : AvatarState.Initializing.ToString();
            snap.fps = _fps;
            snap.audioUnderruns = _audioUnderruns;
            snap.queuedVisemes = _visemesQueued;
            snap.bridgeMessagesReceived = _bridgeMessagesReceived;
            snap.malformedMessages = _malformedMessages;
            snap.interruptions = _interruptions;
            snap.errors = _errorCount;
            snap.lastErrorCode = _lastErrorCode;

            if (_controller != null)
            {
                AvatarAudioPlayer player = _controller.AudioPlayer;
                if (player != null)
                {
                    snap.audioPlaybackTime = player.PlaybackTimeSeconds;
                    snap.audioBufferSeconds = player.BufferedDurationSeconds;
                }

                LipSyncController lips = _controller.LipSync;
                if (lips != null)
                {
                    snap.queuedVisemes = lips.QueuedCount;
                }

                EmotionController emotions = _controller.Emotions;
                if (emotions != null)
                {
                    snap.emotion = emotions.CurrentEmotion.ToString();
                }

                GestureController gestures = _controller.Gestures;
                if (gestures != null)
                {
                    snap.gesture = gestures.ActiveGesture.ToString();
                }
            }

            return snap;
        }

        /// <summary>Serializes a snapshot to JSON (for the Flutter bridge).</summary>
        public string GetMetricsJson()
        {
            return JsonUtility.ToJson(GetSnapshot());
        }
    }
}