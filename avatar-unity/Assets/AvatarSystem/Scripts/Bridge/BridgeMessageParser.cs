using System;
using System.Collections.Generic;
using System.Text;
using UnityEngine;

namespace AvatarUnity.Bridge
{
    /// <summary>
    /// Central message parsing and JSON composition. Every inbound message in the
    /// whole avatar system goes through this class — nothing else parses JSON.
    /// Malformed messages are reported, never thrown.
    /// </summary>
    public static class BridgeMessageParser
    {
        /// <summary>
        /// Parses a raw inbound JSON string. Returns false (and sets <paramref name="error"/>)
        /// for malformed input. Well-formed but unknown message types still parse
        /// successfully and are reported later by the dispatcher.
        /// </summary>
        public static bool TryParseInbound(string json, out InboundBridgeMessage message, out string error)
        {
            message = null;
            error = null;

            if (string.IsNullOrWhiteSpace(json))
            {
                error = "Empty message.";
                return false;
            }

            try
            {
                message = JsonUtility.FromJson<InboundBridgeMessage>(json);
            }
            catch (Exception ex)
            {
                error = "Malformed JSON: " + ex.Message;
                message = null;
                return false;
            }

            if (message == null)
            {
                error = "Malformed message.";
                return false;
            }

            if (string.IsNullOrEmpty(message.type))
            {
                error = "Message is missing 'type' field.";
                return false;
            }

            // Reserved check: requestId is optional but when present should be a string.
            return true;
        }

        /// <summary>True when the message type is recognized by the dispatcher.</summary>
        public static bool IsKnownType(string type)
        {
            switch (type)
            {
                case BridgeMessageTypes.AvatarState:
                case BridgeMessageTypes.AvatarEmotion:
                case BridgeMessageTypes.AvatarGesture:
                case BridgeMessageTypes.AudioConfigure:
                case BridgeMessageTypes.AudioChunk:
                case BridgeMessageTypes.AudioStop:
                case BridgeMessageTypes.SpeechInterrupt:
                case BridgeMessageTypes.VisemeBatch:
                case BridgeMessageTypes.AvatarLogLevel:
                case BridgeMessageTypes.AvatarQuality:
                case BridgeMessageTypes.DiagnosticsGet:
                    return true;
                default:
                    return false;
            }
        }

        /// <summary>Parses a gesture string into an AvatarGesture, tolerantly.</summary>
        public static bool TryParseGesture(string value, out AvatarUnity.Animation.AvatarGesture gesture)
        {
            if (Enum.TryParse(value, true, out gesture))
            {
                return Enum.IsDefined(typeof(AvatarUnity.Animation.AvatarGesture), gesture);
            }
            return false;
        }

        /// <summary>Parses an emotion string into an AvatarEmotion, tolerantly.</summary>
        public static bool TryParseEmotion(string value, out AvatarUnity.Face.AvatarEmotion emotion)
        {
            if (Enum.TryParse(value, true, out emotion))
            {
                return Enum.IsDefined(typeof(AvatarUnity.Face.AvatarEmotion), emotion);
            }
            return false;
        }

        /// <summary>Composes a compact outbound JSON envelope.</summary>
        public static string ComposeMessage(string type, string requestId, string payloadJson)
        {
            var sb = new StringBuilder(96);
            sb.Append("{\"type\":\"");
            sb.Append(type);
            sb.Append('"');
            if (!string.IsNullOrEmpty(requestId))
            {
                sb.Append(",\"requestId\":\"");
                sb.Append(requestId);
                sb.Append('"');
            }
            if (!string.IsNullOrEmpty(payloadJson))
            {
                sb.Append(",\"payload\":");
                sb.Append(payloadJson);
            }
            sb.Append('}');
            return sb.ToString();
        }

        /// <summary>Serializes any object to JSON and wraps it in the outbound envelope.</summary>
        public static string ComposeTypedMessage(string type, string requestId, object payloadObject)
        {
            string payloadJson = payloadObject != null ? JsonUtility.ToJson(payloadObject) : null;
            return ComposeMessage(type, requestId, payloadJson);
        }
    }
}