using NUnit.Framework;
using UnityEngine;
using AvatarUnity.LipSync;
using AvatarUnity.Audio;

namespace AvatarUnity.Tests
{
    public class VisemeSchedulerTests
    {
        [Test]
        public void Events_AreOrderedByTimestamp()
        {
            var scheduler = new VisemeScheduler(500d);
            scheduler.Queue(new VisemeEvent(4, 300, 1f));
            scheduler.Queue(new VisemeEvent(1, 80, 1f));
            scheduler.Queue(new VisemeEvent(12, 140, 0.9f));

            Assert.AreEqual(3, scheduler.Count);

            VisemeEvent active;
            VisemeEvent next;
            float blend;
            Assert.IsTrue(scheduler.TrySample(80d, out active, out next, out blend));
            Assert.AreEqual(1, active.visemeId);
            Assert.AreEqual(12, next.visemeId);
        }

        [Test]
        public void Sample_BetweenEvents_BlendsForward()
        {
            var scheduler = new VisemeScheduler(500d);
            scheduler.QueueRange(new[]
            {
                new VisemeEvent(1, 100, 1f),
                new VisemeEvent(2, 200, 1f)
            });

            VisemeEvent active;
            VisemeEvent next;
            float blend;
            Assert.IsTrue(scheduler.TrySample(185d, out active, out next, out blend));
            Assert.AreEqual(1, active.visemeId);
            Assert.AreEqual(2, next.visemeId);
            Assert.IsTrue(blend > 0.5f && blend < 1f);
        }

        [Test]
        public void NoActiveEvent_ReturnsFalse()
        {
            var scheduler = new VisemeScheduler(500d);
            scheduler.Queue(new VisemeEvent(9, 500, 1f));

            VisemeEvent active;
            VisemeEvent next;
            float blend;
            Assert.IsFalse(scheduler.TrySample(50d, out active, out next, out blend));

            // Active once time reaches it.
            Assert.IsTrue(scheduler.TrySample(500d, out active, out next, out blend));
            Assert.AreEqual(9, active.visemeId);
        }

        [Test]
        public void Clear_RemovesEverything()
        {
            var scheduler = new VisemeScheduler(500d);
            scheduler.QueueRange(new[]
            {
                new VisemeEvent(1, 100, 1f),
                new VisemeEvent(2, 200, 1f)
            });
            scheduler.Clear();
            Assert.AreEqual(0, scheduler.Count);

            VisemeEvent active;
            VisemeEvent next;
            float blend;
            Assert.IsFalse(scheduler.TrySample(150d, out active, out next, out blend));
        }

        [Test]
        public void HasActiveWithin_SeesLookahead()
        {
            var scheduler = new VisemeScheduler(500d);
            scheduler.Queue(new VisemeEvent(5, 300, 1f));
            Assert.IsTrue(scheduler.HasActiveWithin(260d, 50d));
            Assert.IsFalse(scheduler.HasActiveWithin(100d, 50d));
        }

        [Test]
        public void Interruption_ClearsFutureVisemes()
        {
            var scheduler = new VisemeScheduler(500d);
            scheduler.QueueRange(new[]
            {
                new VisemeEvent(1, 100, 1f),
                new VisemeEvent(2, 900, 1f),
                new VisemeEvent(3, 1800, 1f)
            });

            // Barge-in: clear everything.
            scheduler.Clear();
            Assert.AreEqual(0, scheduler.Count);

            VisemeEvent active;
            VisemeEvent next;
            float blend;
            Assert.IsFalse(scheduler.TrySample(1000d, out active, out next, out blend));
        }

        [Test]
        public void ExpiredEvents_ArePruned()
        {
            var scheduler = new VisemeScheduler(200d);
            scheduler.Queue(new VisemeEvent(4, 100, 1f));
            scheduler.Queue(new VisemeEvent(3, 300, 1f));
            Assert.AreEqual(2, scheduler.Count);

            // Sampling far into the future prunes everything older than now - 200ms.
            scheduler.TrySample(1000d, out _, out _, out _);
            Assert.AreEqual(0, scheduler.Count);
        }
    }

    public class PcmDecoderTests
    {
        [Test]
        public void Decodes_Base64Pcm16_CorrectLength()
        {
            // A single 440Hz sine burst, 1 second @ 8000Hz mono, 16-bit.
            int sampleRate = 8000;
            var samples = new short[sampleRate];
            for (int i = 0; i < sampleRate; i++)
            {
                samples[i] = (short)(Mathf.Sin(2f * Mathf.PI * 440f * i / sampleRate) * 32000f);
            }

            var bytes = new byte[samples.Length * 2];
            for (int i = 0; i < samples.Length; i++)
            {
                short s = samples[i];
                bytes[i * 2] = (byte)(s & 0xFF);
                bytes[i * 2 + 1] = (byte)((s >> 8) & 0xFF);
            }

            string base64 = System.Convert.ToBase64String(bytes);
            float[] decoded = PcmDecoder.DecodeBase64Pcm16(base64, 0, -1, 1);

            Assert.IsNotNull(decoded);
            Assert.AreEqual(sampleRate, decoded.Length);

            // Value near first peak.
            Assert.IsTrue(decoded[200] < 0.9f || decoded[200] > 0.05f);
        }

        [Test]
        public void Rejects_InvalidBase64()
        {
            Assert.IsNull(PcmDecoder.DecodeBase64Pcm16("!!!notbase64!!!", 0, -1, 1));
        }

        [Test]
        public void BytesToSeconds_IsCorrect()
        {
            // 8000 samples = 1 second mono 16-bit.
            Assert.AreEqual(1f, PcmDecoder.BytesToSeconds(16000, 1, 8000), 0.0001f);
        }
    }
}