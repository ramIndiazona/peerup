namespace AvatarUnity.Audio
{
    /// <summary>
    /// Pure PCM decoding helpers (no Unity objects). Kept in a static class so the
    /// bridge can decode base64 PCM chunks without MonoBehaviour state, and so the
    /// logic can be unit-tested in EditMode.
    /// </summary>
    public static class PcmDecoder
    {
        /// <summary>Decodes little-endian 16-bit PCM bytes into float samples (-1..1).</summary>
        public static float[] DecodeSample16ToFloat(byte[] pcm, int offset, int count, int channels)
        {
            if (pcm == null)
            {
                return null;
            }
            int sampleFrames = count / (2 * channels);
            if (sampleFrames <= 0)
            {
                return null;
            }

            var result = new float[sampleFrames];
            for (int f = 0; f < sampleFrames; f++)
            {
                long sum = 0;
                for (int c = 0; c < channels; c++)
                {
                    int byteIndex = offset + (f * channels + c) * 2;
                    short s = (short)(pcm[byteIndex] | (pcm[byteIndex + 1] << 8));
                    sum += s;
                }
                if (channels > 1)
                {
                    sum /= channels;
                }
                result[f] = (float)(sum / 32768.0);
            }
            return result;
        }

        /// <summary>Decodes a base64 string containing little-endian 16-bit PCM.</summary>
        public static float[] DecodeBase64Pcm16(string base64, int offset, int byteCount, int channels)
        {
            if (string.IsNullOrEmpty(base64))
            {
                return null;
            }
            try
            {
                byte[] bytes = System.Convert.FromBase64String(base64);
                if (bytes == null || bytes.Length == 0)
                {
                    return null;
                }
                int length = byteCount < 0 ? bytes.Length : (byteCount < bytes.Length ? byteCount : bytes.Length);
                return DecodeSample16ToFloat(bytes, offset, length, channels);
            }
            catch (System.FormatException)
            {
                return null;
            }
        }

        /// <summary>Estimates how many seconds of audio a byte count represents.</summary>
        public static float BytesToSeconds(int byteCount, int channels, int sampleRate)
        {
            if (sampleRate <= 0 || channels <= 0)
            {
                return 0f;
            }
            return byteCount / (float)(2 * channels * sampleRate);
        }
    }
}