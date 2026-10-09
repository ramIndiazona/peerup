using NUnit.Framework;
using AvatarUnity.Bridge;
using AvatarUnity.Animation;
using AvatarUnity.Face;

namespace AvatarUnity.Tests
{
    public class BridgeMessageParserTests
    {
        [Test]
        public void Parses_AvatarState_Command()
        {
            const string json = "{\"type\":\"avatar.state\",\"requestId\":\"123\",\"payload\":{\"state\":\"listening\"}}";
            InboundBridgeMessage message;
            string error;
            Assert.IsTrue(BridgeMessageParser.TryParseInbound(json, out message, out error));
            Assert.AreEqual("avatar.state", message.type);
            Assert.AreEqual("123", message.requestId);
            Assert.AreEqual("listening", message.payload.state);
        }

        [Test]
        public void Parses_Emotion_Command()
        {
            const string json = "{\"type\":\"avatar.emotion\",\"requestId\":\"124\",\"payload\":{\"emotion\":\"happy\",\"intensity\":0.8,\"transitionMs\":300}}";
            InboundBridgeMessage message;
            string error;
            Assert.IsTrue(BridgeMessageParser.TryParseInbound(json, out message, out error));
            Assert.AreEqual("avatar.emotion", message.type);
            Assert.AreEqual(0.8f, message.payload.intensity, 0.001f);
            Assert.AreEqual(300, message.payload.transitionMs);
        }

        [Test]
        public void Parses_VisemeBatch()
        {
            const string json = "{\"type\":\"viseme.batch\",\"payload\":{\"items\":[{\"id\":4,\"timestampMs\":80,\"weight\":1},{\"id\":12,\"timestampMs\":140,\"weight\":0.9}]}}";
            InboundBridgeMessage message;
            string error;
            Assert.IsTrue(BridgeMessageParser.TryParseInbound(json, out message, out error));
            Assert.IsNotNull(message.payload.items);
            Assert.AreEqual(2, message.payload.items.Length);
            Assert.AreEqual(4, message.payload.items[0].id);
            Assert.AreEqual(80d, message.payload.items[0].timestampMs, 0.001d);
            Assert.AreEqual(140d, message.payload.items[1].timestampMs, 0.001d);
        }

        [Test]
        public void Rejects_EmptyJson()
        {
            InboundBridgeMessage message;
            string error;
            Assert.IsFalse(BridgeMessageParser.TryParseInbound(string.Empty, out message, out error));
        }

        [Test]
        public void Rejects_MalformedJson()
        {
            InboundBridgeMessage message;
            string error;
            Assert.IsFalse(BridgeMessageParser.TryParseInbound("{this is not json", out message, out error));
        }

        [Test]
        public void Rejects_MissingType()
        {
            InboundBridgeMessage message;
            string error;
            Assert.IsFalse(BridgeMessageParser.TryParseInbound("{\"requestId\":\"x\",\"payload\":{}}", out message, out error));
        }

        [Test]
        public void UnknownType_ParsesButIsNotKnown()
        {
            InboundBridgeMessage message;
            string error;
            Assert.IsTrue(BridgeMessageParser.TryParseInbound("{\"type\":\"totally.unknown\"}", out message, out error));
            Assert.IsFalse(BridgeMessageParser.IsKnownType(message.type));
        }

        [Test]
        public void KnownMessageTypes_AreKnown()
        {
            Assert.IsTrue(BridgeMessageParser.IsKnownType(BridgeMessageTypes.AudioChunk));
            Assert.IsTrue(BridgeMessageParser.IsKnownType(BridgeMessageTypes.SpeechInterrupt));
            Assert.IsTrue(BridgeMessageParser.IsKnownType(BridgeMessageTypes.VisemeBatch));
        }

        [Test]
        public void GestureParsing_IsCaseInsensitive()
        {
            AvatarGesture gesture;
            Assert.IsTrue(BridgeMessageParser.TryParseGesture("nod", out gesture));
            Assert.AreEqual(AvatarGesture.Nod, gesture);
        }

        [Test]
        public void InvalidGesture_ReturnsFalse()
        {
            AvatarGesture gesture;
            Assert.IsFalse(BridgeMessageParser.TryParseGesture("moonwalk", out gesture));
        }

        [Test]
        public void EmotionParsing_IsCaseInsensitive()
        {
            AvatarEmotion emotion;
            Assert.IsTrue(BridgeMessageParser.TryParseEmotion("EnCoUrAgInG", out emotion));
            Assert.AreEqual(AvatarEmotion.Encouraging, emotion);
        }

        [Test]
        public void InvalidEmotion_ReturnsFalse()
        {
            AvatarEmotion emotion;
            Assert.IsFalse(BridgeMessageParser.TryParseEmotion("raging", out emotion));
        }

        [Test]
        public void ComposeMessage_ProducesValidEnvelope()
        {
            string json = BridgeMessageParser.ComposeTypedMessage(
                BridgeMessageTypes.AudioStarted,
                "req-1",
                new AudioStartedPayload { playbackTime = 0.25d });

            Assert.IsTrue(json.Contains("\"type\":\"audio.started\""));
            Assert.IsTrue(json.Contains("\"requestId\":\"req-1\""));
            Assert.IsTrue(json.Contains("\"payload\":{"));
        }

        [Test]
        public void InterruptMessage_Parses()
        {
            InboundBridgeMessage message;
            string error;
            Assert.IsTrue(BridgeMessageParser.TryParseInbound("{\"type\":\"speech.interrupt\"}", out message, out error));
            Assert.AreEqual(BridgeMessageTypes.SpeechInterrupt, message.type);
        }
    }
}