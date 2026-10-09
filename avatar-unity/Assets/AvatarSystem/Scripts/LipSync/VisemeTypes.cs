using System;

namespace AvatarUnity.LipSync
{
    /// <summary>
    /// A single scheduled viseme event. Timestamps are in milliseconds relative to the
    /// audio stream start (which the audio player exposes as PlaybackTimeSeconds).
    /// </summary>
    [Serializable]
    public class VisemeEvent
    {
        public int visemeId;
        public double timestampMs;
        public float weight;

        public VisemeEvent()
        {
        }

        public VisemeEvent(int visemeId, double timestampMs, float weight)
        {
            this.visemeId = visemeId;
            this.timestampMs = timestampMs;
            this.weight = weight;
        }
    }

    /// <summary>
    /// Provider-neutral viseme groups. Concrete providers map their own IDs onto these
    /// (or directly onto face channels) through VisemeMappingConfig.
    /// </summary>
    public enum NormalizedViseme
    {
        Neutral = 0,
        A = 1,
        E = 2,
        I = 3,
        O = 4,
        U = 5,
        M = 6,
        F = 7,
        S = 8,
        T = 9,
        N = 10,
        L = 11,
        CH = 12,
        Unknown = 127
    }
}