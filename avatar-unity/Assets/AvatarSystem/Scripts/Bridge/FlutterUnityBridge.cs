using System;
using UnityEngine;
using AvatarUnity.Audio;
using AvatarUnity.Core;
using AvatarUnity.Diagnostics;
using AvatarUnity.Face;
using AvatarUnity.LipSync;

namespace AvatarUnity.Bridge
{
    /// <summary>
    /// Platform-neutral bridge between Unity and Flutter.
    ///
    /// - Receives JSON messages (see FLUTTER_BRIDGE_PROTOCOL.md) and routes them to
    ///   the avatar controller / audio player / lip-sync.
    /// - Emits JSON messages through <see cref="IExternalMessageBridge"/> (the Flutter
    ///   plugin adapter) and through the <see cref="OnOutboundMessage"/> C# event.
    ///
    /// All inbound JSON parsing goes through <see cref="BridgeMessageParser"/>.
    /// Malformed input never crashes Unity.
    /// </summary>
    [DisallowMultipleComponent]
    public sealed class FlutterUnityBridge : MonoBehaviour
    {
        /// <summary>Raised whenever an outbound JSON message is produced.</summary>
        public event Action<string> OnOutboundMessage;

        [SerializeField] private bool emitIncomingToLog;

        private AvatarController _controller;
        private IExternalMessageBridge _externalBridge;
        private bool _speechInProgress;
        private string _activeRequestId = string.Empty;

        /// <summary>The currently wired external bridge (may be null until Flutter connects).</summary>
        public IExternalMessageBridge ExternalBridge => _externalBridge;

        /// <summary>Wires the Flutter plugin adapter. Sends unity.ready after wiring.</summary>
        public void SetExternalBridge(IExternalMessageBridge bridge)
        {
            _externalBridge = bridge;
            if (bridge != null)
            {
                AvatarLogger.LogInfo("External message bridge attached.");
                SendUnityReady();
            }
        }

        /// <summary>Binds the avatar controller this bridge drives. Called by bootstrap.</summary>
        public void SetTarget(AvatarController controller)
        {
            _controller = controller;
        }

        // ------------------------------------------------------------------
        // Inbound
        // ------------------------------------------------------------------

        /// <summary>
        /// Enters a JSON message from Flutter. Safe to call from any thread; all
        /// effects are marshalled to the Unity main thread.
        /// </summary>
        public void HandleIncoming(string json)
        {
            if (UnityMainThreadDispatcher.IsMainThread)
            {
                HandleIncomingInternal(json);
            }
            else
            {
                string captured = json;
                UnityMainThreadDispatcher.ExecuteOnMainThread(() => HandleIncomingInternal(captured));
            }
        }

        private void HandleIncomingInternal(string json)
        {
            AvatarDiagnostics diagnostics = _controller != null ? _controller.Diagnostics : null;
            diagnostics?.RecordBridgeMessage();

            if (emitIncomingToLog)
            {
                AvatarLogger.LogVerbose($"Bridge << {json}");
            }

            InboundBridgeMessage message;
            string error;
            if (!BridgeMessageParser.TryParseInbound(json, out message, out error))
            {
                diagnostics?.RecordMalformedMessage();
                AvatarLogger.LogWarning($"Bridge rejected malformed message: {error}");
                SendWarning(AvatarErrorCode.InvalidBridgeMessage.ToString(), error);
                return;
            }

            _activeRequestId = message.requestId ?? string.Empty;

            if (!BridgeMessageParser.IsKnownType(message.type))
            {
                AvatarLogger.LogWarning($"Bridge: unknown message type '{message.type}' (ignored).");
                return;
            }

            RouteMessage(message.type, message.payload);
        }

        private void RouteMessage(string type, BridgeCommandPayload p)
        {
            switch (type)
            {
                case BridgeMessageTypes.AvatarState:
                    RouteStateCommand(p.state);
                    break;
                case BridgeMessageTypes.AvatarEmotion:
                    RouteEmotionCommand(p);
                    break;
                case BridgeMessageTypes.AvatarGesture:
                    RouteGestureCommand(p.gesture);
                    break;
                case BridgeMessageTypes.AudioConfigure:
                    RouteAudioConfigure(p);
                    break;
                case BridgeMessageTypes.AudioChunk:
                    RouteAudioChunk(p);
                    break;
                case BridgeMessageTypes.AudioStop:
                    RouteAudioStop();
                    break;
                case BridgeMessageTypes.SpeechInterrupt:
                    _controller?.InterruptSpeech();
                    SendSpeechInterrupted();
                    break;
                case BridgeMessageTypes.VisemeBatch:
                    RouteVisemeBatch(p);
                    break;
                case BridgeMessageTypes.AvatarLogLevel:
                    RouteLogLevel(p.level);
                    break;
                case BridgeMessageTypes.AvatarQuality:
                    RouteQuality(p.qualityLevel);
                    break;
                case BridgeMessageTypes.DiagnosticsGet:
                    SendDiagnostics(_activeRequestId);
                    break;
            }
        }

        private void RouteStateCommand(string state)
        {
            if (_controller == null)
            {
                return;
            }
            switch (state)
            {
                case "idle":
                    _controller.ReturnToIdle();
                    break;
                case "listening":
                    _controller.StartListening();
                    break;
                case "thinking":
                    _controller.StartThinking();
                    break;
                case "speaking":
                    _controller.StartSpeaking();
                    break;
                case "interrupted":
                    _controller.InterruptSpeech();
                    SendSpeechInterrupted();
                    break;
                default:
                    AvatarLogger.LogWarning($"Bridge: unknown avatar.state '{state}' (ignored).");
                    break;
            }
        }

        private void RouteEmotionCommand(BridgeCommandPayload p)
        {
            if (_controller == null)
            {
                return;
            }
            AvatarEmotion emotion;
            if (!BridgeMessageParser.TryParseEmotion(p.emotion, out emotion))
            {
                AvatarLogger.LogWarning($"Bridge: unknown emotion '{p.emotion}' (ignored).");
                return;
            }
            float transition = p.transitionSeconds > 0f
                ? p.transitionSeconds
                : (p.transitionMs > 0 ? p.transitionMs / 1000f : 0.4f);
            _controller.SetEmotion(emotion, p.intensity, transition);
        }

        private void RouteGestureCommand(string gestureString)
        {
            if (_controller == null)
            {
                return;
            }
            AvatarUnity.Animation.AvatarGesture gesture;
            if (!BridgeMessageParser.TryParseGesture(gestureString, out gesture))
            {
                AvatarLogger.LogWarning($"Bridge: unknown gesture '{gestureString}' (ignored).");
                return;
            }
            _controller.PlayGesture(gesture);
        }

        private void RouteAudioConfigure(BridgeCommandPayload p)
        {
            if (_controller == null || _controller.AudioPlayer == null)
            {
                return;
            }
            bool ok = _controller.AudioPlayer.Configure(p.sampleRate, p.channels);
            if (!ok)
            {
                SendAvatarError(AvatarErrorCode.InvalidAudioConfiguration, "audio.configure rejected.");
            }
        }

        private void RouteAudioChunk(BridgeCommandPayload p)
        {
            if (_controller == null || _controller.AudioPlayer == null)
            {
                return;
            }

            if (!string.Equals(p.encoding, "pcm16-base64", StringComparison.OrdinalIgnoreCase) &&
                !string.Equals(p.encoding, "pcm16", StringComparison.OrdinalIgnoreCase))
            {
                AvatarLogger.LogWarning($"Bridge: unsupported audio encoding '{p.encoding}' (expected pcm16-base64).");
                return;
            }

            float[] samples = PcmDecoder.DecodeBase64Pcm16(p.data, 0, -1, _controller.AudioPlayer.Channels);
            if (samples == null || samples.Length == 0)
            {
                AvatarLogger.LogWarning("Bridge: audio.chunk contained no decodable PCM data.");
                return;
            }

            _controller.AudioPlayer.EnqueueSamples(samples);

            // First chunk of an utterance switches the avatar into Speaking.
            if (!_speechInProgress)
            {
                _controller.StartSpeaking();
                SendSpeechStarted();
                SendAudioStarted();
            }
        }

        private void RouteAudioStop()
        {
            if (_controller == null)
            {
                return;
            }
            AvatarAudioPlayer player = _controller.AudioPlayer;
            if (player == null)
            {
                return;
            }

            player.EndOfStream();

            // If nothing is buffered / playing, finish the utterance immediately.
            if (!player.IsPlaying && !player.HasBufferedData)
            {
                FinishSpeech();
            }
        }

        private void RouteVisemeBatch(BridgeCommandPayload p)
        {
            if (_controller == null || _controller.LipSync == null)
            {
                return;
            }
            if (p.items == null || p.items.Length == 0)
            {
                AvatarLogger.LogVerbose("viseme.batch received with no items.");
                return;
            }

            var events = new VisemeEvent[p.items.Length];
            for (int i = 0; i < p.items.Length; i++)
            {
                VisemeItem item = p.items[i];
                events[i] = new VisemeEvent(item.id, item.timestampMs, item.weight);
            }

            _controller.LipSync.QueueVisemes(events);
            _controller.LipSync.StartLipSync();
            _controller.Diagnostics?.RecordVisemesQueued(events.Length);
        }

        private void RouteLogLevel(string level)
        {
            AvatarLogLevel parsed;
            if (Enum.TryParse(level, true, out parsed) && Enum.IsDefined(typeof(AvatarLogLevel), parsed))
            {
                AvatarLogger.Configure(parsed);
                AvatarLogger.LogInfo($"Log level set to {parsed} (via bridge).");
            }
            else
            {
                AvatarLogger.LogWarning($"Bridge: unknown log level '{level}' (ignored).");
            }
        }

        private void RouteQuality(int qualityLevel)
        {
            if (qualityLevel < 0 || qualityLevel > 2)
            {
                AvatarLogger.LogWarning($"Bridge: unknown qualityLevel '{qualityLevel}' (ignored).");
                return;
            }
            var profile = (AvatarQualityLevel)qualityLevel;
            if (_controller != null)
            {
                _controller.PerformanceProfile = profile;
            }
        }

        // ------------------------------------------------------------------
        // Outbound
        // ------------------------------------------------------------------

        /// <summary>Sends a raw outbound JSON message down the wire.</summary>
        public void SendOutbound(string json)
        {
            OnOutboundMessage?.Invoke(json);
            try
            {
                _externalBridge?.SendMessage(json);
            }
            catch (Exception ex)
            {
                AvatarLogger.LogError($"External bridge threw while sending: {ex.Message}");
            }
        }

        private void Send(string type, string requestId, object payloadObject)
        {
            string json = BridgeMessageParser.ComposeTypedMessage(type, requestId, payloadObject);
            SendOutbound(json);
        }

        public void SendUnityReady()
        {
            Send(BridgeMessageTypes.UnityReady, null, null);
        }

        public void SendAvatarReady(string displayName)
        {
            var payload = new StateChangedPayload { state = "idle" };
            Send(BridgeMessageTypes.AvatarReady, null, payload);
        }

        public void SendStateChanged(AvatarState state)
        {
            var payload = new StateChangedPayload { state = state.ToString().ToLowerInvariant() };
            Send(BridgeMessageTypes.AvatarStateChanged, _activeRequestId, payload);
        }

        public void SendAudioStarted()
        {
            var payload = new AudioStartedPayload
            {
                playbackTime = _controller != null && _controller.AudioPlayer != null
                    ? _controller.AudioPlayer.PlaybackTimeSeconds
                    : 0d
            };
            Send(BridgeMessageTypes.AudioStarted, null, payload);
        }

        public void SendAudioFinished()
        {
            Send(BridgeMessageTypes.AudioFinished, null, null);
        }

        public void SendBufferUnderrun()
        {
            var payload = new BufferUnderrunPayload
            {
                count = _controller != null && _controller.AudioPlayer != null
                    ? _controller.AudioPlayer.UnderrunCount
                    : 0,
                playbackTime = _controller != null && _controller.AudioPlayer != null
                    ? _controller.AudioPlayer.PlaybackTimeSeconds
                    : 0d
            };
            Send(BridgeMessageTypes.AudioBufferUnderrun, null, payload);

            if (_controller != null && _controller.Diagnostics != null)
            {
                _controller.Diagnostics.RecordAudioUnderrun();
            }
        }

        public void SendSpeechStarted()
        {
            _speechInProgress = true;
            Send(BridgeMessageTypes.SpeechStarted, null, null);
        }

        public void SendSpeechFinished()
        {
            if (!_speechInProgress)
            {
                return;
            }
            _speechInProgress = false;
            Send(BridgeMessageTypes.SpeechFinished, null, null);

            // Conversation naturally returns to Idle after a finished utterance.
            _controller?.ReturnToIdle();
        }

        public void SendSpeechInterrupted()
        {
            _speechInProgress = false;
            Send(BridgeMessageTypes.SpeechInterrupted, _activeRequestId, null);
        }

        public void SendAvatarError(AvatarErrorCode code, string message)
        {
            var payload = new AvatarIssuePayload { code = code.ToString(), message = message };
            Send(BridgeMessageTypes.AvatarError, null, payload);
        }

        public void SendAvatarError(in AvatarError error)
        {
            SendAvatarError(error.Code, error.Message);
        }

        public void SendWarning(string code, string message)
        {
            var payload = new AvatarIssuePayload { code = code, message = message };
            Send(BridgeMessageTypes.AvatarWarning, null, payload);
        }

        public void SendDiagnostics(string requestId)
        {
            if (_controller == null || _controller.Diagnostics == null)
            {
                return;
            }
            AvatarDiagnostics.Snapshot snapshot = _controller.Diagnostics.GetSnapshot();
            var payload = new DiagnosticsPayload
            {
                state = snapshot.state,
                fps = snapshot.fps,
                audioPlaybackTime = snapshot.audioPlaybackTime,
                audioBufferSeconds = snapshot.audioBufferSeconds,
                audioUnderruns = snapshot.audioUnderruns,
                queuedVisemes = snapshot.queuedVisemes,
                bridgeMessagesReceived = snapshot.bridgeMessagesReceived,
                malformedMessages = snapshot.malformedMessages,
                interruptions = snapshot.interruptions,
                errors = snapshot.errors,
                lastErrorCode = snapshot.lastErrorCode,
                emotion = snapshot.emotion,
                gesture = snapshot.gesture
            };
            Send(BridgeMessageTypes.DiagnosticsMetrics, requestId, payload);
        }

        /// <summary>Internal: called by the AvatarController when audio completes.</summary>
        public void NotifyAudioCompleted()
        {
            SendAudioFinished();
            SendSpeechFinished();
        }

        private void FinishSpeech()
        {
            SendAudioFinished();
            SendSpeechFinished();
        }
    }
}