using System;

namespace AvatarUnity.Bridge
{
    /// <summary>
    /// Message type constants for the Flutter &lt;-&gt; Unity JSON contract.
    /// See FLUTTER_BRIDGE_PROTOCOL.md for the exact schema.
    /// </summary>
    public static class BridgeMessageTypes
    {
        // Inbound (Flutter -> Unity)
        public const string AvatarState = "avatar.state";
        public const string AvatarEmotion = "avatar.emotion";
        public const string AvatarGesture = "avatar.gesture";
        public const string AudioConfigure = "audio.configure";
        public const string AudioChunk = "audio.chunk";
        public const string AudioStop = "audio.stop";
        public const string SpeechInterrupt = "speech.interrupt";
        public const string VisemeBatch = "viseme.batch";
        public const string AvatarLogLevel = "avatar.logLevel";
        public const string AvatarQuality = "avatar.quality";
        public const string DiagnosticsGet = "diagnostics.get";

        // Outbound (Unity -> Flutter)
        public const string UnityReady = "unity.ready";
        public const string AvatarReady = "avatar.ready";
        public const string AvatarStateChanged = "avatar.stateChanged";
        public const string AudioStarted = "audio.started";
        public const string AudioFinished = "audio.finished";
        public const string AudioBufferUnderrun = "audio.bufferUnderrun";
        public const string SpeechStarted = "speech.started";
        public const string SpeechFinished = "speech.finished";
        public const string SpeechInterrupted = "speech.interrupted";
        public const string AvatarError = "avatar.error";
        public const string AvatarWarning = "avatar.warning";
        public const string DiagnosticsMetrics = "diagnostics.metrics";
    }

    /// <summary>
    /// One inbound JSON message. The payload is deserialized into
    /// <see cref="BridgeCommandPayload"/>, whose fields are interpreted per message type.
    /// </summary>
    [Serializable]
    public class InboundBridgeMessage
    {
        public string type;
        public string requestId;
        public BridgeCommandPayload payload = new BridgeCommandPayload();
    }

    /// <summary>Union of all inbound payload fields (parsed by the type discriminator).</summary>
    [Serializable]
    public class BridgeCommandPayload
    {
        public string state;
        public string emotion;
        public float intensity = 1f;
        public int transitionMs;
        public float transitionSeconds = -1f;
        public string gesture;
        public int sampleRate;
        public int channels;
        public string encoding;
        public string data;
        public VisemeItem[] items;
        public string level;
        public int qualityLevel = -1;
    }

    /// <summary>A viseme entry inside the viseme.batch payload.</summary>
    [Serializable]
    public class VisemeItem
    {
        public int id;
        public double timestampMs;
        public float weight = 1f;
    }

    /// <summary>
    /// Simple outbound envelope. The payload is pre-serialized JSON (or null).
    /// </summary>
    [Serializable]
    public class OutboundBridgeMessage
    {
        public string type;
        public string requestId;
        public string payload;
    }

    /// <summary>Outbound payload: avatar state change.</summary>
    [Serializable]
    public class StateChangedPayload
    {
        public string from;
        public string state;
    }

    /// <summary>Outbound payload: audio playback started.</summary>
    [Serializable]
    public class AudioStartedPayload
    {
        public double playbackTime;
    }

    /// <summary>Outbound payload: buffer underrun.</summary>
    [Serializable]
    public class BufferUnderrunPayload
    {
        public int count;
        public double playbackTime;
    }

    /// <summary>Outbound payload: error / warning.</summary>
    [Serializable]
    public class AvatarIssuePayload
    {
        public string code;
        public string message;
    }

    /// <summary>Outbound payload: diagnostics.metrics.</summary>
    [Serializable]
    public class DiagnosticsPayload
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
}