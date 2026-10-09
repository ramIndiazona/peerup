using System;
using UnityEngine;
using AvatarUnity.Config;
using AvatarUnity.Diagnostics;

namespace AvatarUnity.Audio
{
    /// <summary>
    /// Realtime streaming PCM audio player designed for AI speech.
    ///
    /// - Enqueue raw PCM chunks (16-bit mono recommended) from any thread.
    /// - Playback begins once a minimum buffer threshold has been reached.
    /// - A thread-safe ring buffer feeds Unity's native audio pipeline through
    ///   <see cref="OnAudioFilterRead"/>.
    /// - Exposes an authoritative <see cref="PlaybackTimeSeconds"/> clock driven by
    ///   <see cref="AudioSettings.dspTime"/> — lip-sync timestamps are scheduled
    ///   against this clock, never against network arrival time.
    /// - Handles pause, resume, stop, flush and full barge-in interruption.
    /// </summary>
    [DisallowMultipleComponent]
    [RequireComponent(typeof(AudioSource))]
    public sealed class AvatarAudioPlayer : MonoBehaviour
    {
        public event Action OnPlaybackStarted;
        public event Action OnPlaybackStopped;
        public event Action OnPlaybackCompleted;
        public event Action OnBufferUnderrun;

        [SerializeField] private AudioSource audioSource;
        [SerializeField] private int sampleRate = 24000;
        [SerializeField] private int channels = 1;
        [SerializeField] private float bufferThresholdSeconds = 0.12f;
        [SerializeField] private int ringBufferSeconds = 4;
        [SerializeField] private float underrunToleranceSeconds = 0.5f;

        private readonly object _sync = new object();

        private float[] _ringBuffer;
        private int _ringSize;
        private int _writePos;
        private int _readPos;
        private int _count;

        private readonly float[] _scratchMono = new float[8192];

        private double _playStartDsp;
        private double _totalPauseDsp;
        private double _pauseEntryDsp;
        private bool _isPaused;
        private bool _playing;
        private bool _acceptingWrites;
        private bool _allDataWritten;
        private bool _shouldComplete;

        private float _underrunSilentTime;
        private int _underrunCount;
        private float _currentAmplitude;

        private AvatarConfig _config;
        private bool _initialized;

        /// <summary>Authoritative playback clock in seconds since the utterance started.</summary>
        public double PlaybackTimeSeconds
        {
            get
            {
                lock (_sync)
                {
                    if (!_playing)
                    {
                        return 0d;
                    }
                    double now = _isPaused ? _pauseEntryDsp : AudioSettings.dspTime;
                    double elapsed = now - _playStartDsp - _totalPauseDsp;
                    return elapsed < 0d ? 0d : elapsed;
                }
            }
        }

        /// <summary>Buffered audio duration in seconds (ring buffer).</summary>
        public float BufferedDurationSeconds
        {
            get
            {
                lock (_sync)
                {
                    return _count / (float)sampleRate;
                }
            }
        }

        public bool IsPlaying => _playing && !_isPaused;

        /// <summary>True while audio is warming up below the playback threshold.</summary>
        public bool IsBuffering => !_playing && _count > 0 && !_warmPaused && !_isPaused;

        private bool _warmPaused;

        /// <summary>True when unplayed samples still exist in the buffer.</summary>
        public bool HasBufferedData
        {
            get
            {
                lock (_sync)
                {
                    return _count > 0;
                }
            }
        }

        /// <summary>Smoothed amplitude (0..1) of the audio currently being written out.</summary>
        public float CurrentAmplitude => _currentAmplitude;

        /// <summary>Total number of buffer underruns encountered.</summary>
        public int UnderrunCount
        {
            get
            {
                lock (_sync)
                {
                    return _underrunCount;
                }
            }
        }

        public int SampleRate => sampleRate;
        public int Channels => channels;

        public void Initialize(AvatarConfig config)
        {
            _config = config;
            if (config != null)
            {
                sampleRate = config.AudioSampleRate;
                channels = Mathf.Clamp(config.AudioChannels, 1, 2);
                bufferThresholdSeconds = Mathf.Max(0.01f, config.AudioBufferThresholdSeconds);
                ringBufferSeconds = Mathf.Max(1, config.AudioRingBufferSeconds);
                underrunToleranceSeconds = Mathf.Max(0.1f, config.AudioUnderrunToleranceSeconds);
            }

            EnsureAudioSource();
            RecreateRingBuffer();
            RecreateSilenceClip();

            _initialized = true;
            AvatarLogger.LogInfo($"AvatarAudioPlayer initialized: {sampleRate}Hz, {channels}ch, ring={ringBufferSeconds}s.");
        }

        // ------------------------------------------------------------------
        // Configuration
        // ------------------------------------------------------------------

        /// <summary>
        /// Reconfigures audio format (e.g. 24000 Hz mono). Flushes the buffer.
        /// Returns false for invalid configurations.
        /// </summary>
        public bool Configure(int newSampleRate, int newChannels)
        {
            if (newSampleRate <= 0 || newSampleRate > 192000)
            {
                AvatarLogger.LogError($"Invalid audio sample rate: {newSampleRate}.");
                return false;
            }
            if (newChannels < 1 || newChannels > 2)
            {
                AvatarLogger.LogError($"Unsupported channel count: {newChannels}.");
                return false;
            }

            lock (_sync)
            {
                StopInternal(_playing);
                sampleRate = newSampleRate;
                channels = newChannels;
                RecreateRingBuffer();
                RecreateSilenceClip();
            }
            AvatarLogger.LogInfo($"Audio reconfigured: {sampleRate}Hz, {channels}ch.");
            return true;
        }

        // ------------------------------------------------------------------
        // Enqueue
        // ------------------------------------------------------------------

        /// <summary>Enqueues raw 16-bit PCM bytes (little-endian).</summary>
        public void EnqueuePcm(byte[] pcm, int offset = 0, int byteCount = -1)
        {
            if (pcm == null)
            {
                AvatarLogger.LogWarning("EnqueuePcm received null buffer.");
                return;
            }
            int length = byteCount < 0 ? pcm.Length : Mathf.Min(byteCount, pcm.Length - offset);
            if (length <= 0)
            {
                return;
            }

            lock (_sync)
            {
                _acceptingWrites = true;
                _allDataWritten = false;
                int sampleCount = length / 2;
                for (int i = 0; i < sampleCount; i++)
                {
                    int byteIndex = offset + i * 2;
                    if (byteIndex + 1 >= pcm.Length)
                    {
                        break;
                    }
                    short s = (short)(pcm[byteIndex] | (pcm[byteIndex + 1] << 8));
                    float v = s / 32768f;
                    WriteSample(v);
                }
            }
        }

        /// <summary>Enqueues decoded float samples (range -1..1).</summary>
        public void EnqueueSamples(float[] samples)
        {
            if (samples == null)
            {
                return;
            }
            lock (_sync)
            {
                _acceptingWrites = true;
                _allDataWritten = false;
                for (int i = 0; i < samples.Length; i++)
                {
                    WriteSample(samples[i]);
                }
            }
        }

        /// <summary>Enqueues decoded 16-bit integer samples.</summary>
        public void EnqueueSamples(short[] samples)
        {
            if (samples == null)
            {
                return;
            }
            lock (_sync)
            {
                _acceptingWrites = true;
                _allDataWritten = false;
                for (int i = 0; i < samples.Length; i++)
                {
                    WriteSample(samples[i] / 32768f);
                }
            }
        }

        /// <summary>
        /// Signals that no more PCM will be appended for the current utterance.
        /// Playback still drains to the end and then completes normally.
        /// </summary>
        public void EndOfStream()
        {
            lock (_sync)
            {
                _allDataWritten = true;
            }
        }

        // ------------------------------------------------------------------
        // Playback control
        // ------------------------------------------------------------------

        public void Pause()
        {
            lock (_sync)
            {
                if (_isPaused)
                {
                    return;
                }
                if (_playing)
                {
                    _pauseEntryDsp = AudioSettings.dspTime;
                    audioSource.Pause();
                }
                else
                {
                    _warmPaused = true;
                }
                _isPaused = true;
            }
        }

        public void Resume()
        {
            lock (_sync)
            {
                if (!_isPaused)
                {
                    return;
                }
                if (_playing)
                {
                    _totalPauseDsp += AudioSettings.dspTime - _pauseEntryDsp;
                    audioSource.UnPause();
                }
                _warmPaused = false;
                _isPaused = false;
            }
        }

        /// <summary>Stops and flushes all audio. No "completed" event is raised.</summary>
        public void Stop()
        {
            lock (_sync)
            {
                StopInternal(true);
            }
        }

        /// <summary>
        /// Barge-in: immediately stops playback, flushes the buffer and resets the
        /// playback clock so the next utterance begins at timestamp zero.
        /// </summary>
        public void Interrupt()
        {
            lock (_sync)
            {
                StopInternal(true);
                _acceptingWrites = false;
                _allDataWritten = true;
            }
            AvatarLogger.LogInfo("AvatarAudioPlayer interrupted (barge-in).");
        }

        /// <summary>Clears buffered PCM but leaves the AudioSource playing state intact.</summary>
        public void Clear()
        {
            lock (_sync)
            {
                ClearRingBuffer();
                _currentAmplitude = 0f;
            }
        }

        // ------------------------------------------------------------------
        // Internal
        // ------------------------------------------------------------------

        private void EnsureAudioSource()
        {
            if (audioSource == null)
            {
                audioSource = GetComponent<AudioSource>();
            }
            if (audioSource == null)
            {
                audioSource = gameObject.AddComponent<AudioSource>();
            }

            audioSource.playOnAwake = false;
            audioSource.loop = true;
            audioSource.spatialBlend = 0f;
            audioSource.volume = 1f;
            audioSource.bypassEffects = true;
            audioSource.bypassListenerEffects = true;
            audioSource.bypassReverbZones = true;
            audioSource.priority = 0;
        }

        private void RecreateRingBuffer()
        {
            _ringSize = Mathf.Max(1024, sampleRate * ringBufferSeconds);
            _ringBuffer = new float[_ringSize];
            _writePos = 0;
            _readPos = 0;
            _count = 0;
        }

        private void RecreateSilenceClip()
        {
            if (audioSource == null)
            {
                return;
            }

            int clipLength = Mathf.Clamp(sampleRate / 4, 1024, 32768);
            AudioClip clip = AudioClip.Create("AvatarStreamSilence", clipLength, 1, sampleRate, false);
            audioSource.clip = clip;
        }

        private void WriteSample(float value)
        {
            _ringBuffer[_writePos] = value;
            _writePos = (_writePos + 1) % _ringSize;
            if (_count == _ringSize)
            {
                _readPos = (_readPos + 1) % _ringSize; // drop oldest to keep latency low
            }
            else
            {
                _count++;
            }
        }

        private int ReadSamples(float[] dest, int count)
        {
            int available = _count < count ? _count : count;
            for (int i = 0; i < available; i++)
            {
                dest[i] = _ringBuffer[_readPos];
                _readPos = (_readPos + 1) % _ringSize;
            }
            _count -= available;
            return available;
        }

        private void ClearRingBuffer()
        {
            _writePos = 0;
            _readPos = 0;
            _count = 0;
        }

        private void StartPlaybackInternal()
        {
            if (_isPaused || _warmPaused)
            {
                return;
            }
            if (_playing)
            {
                return;
            }

            _playStartDsp = AudioSettings.dspTime;
            _totalPauseDsp = 0d;
            _underrunSilentTime = 0f;

            audioSource.Play();
            _playing = true;

            AvatarLogger.LogInfo("Audio playback started.");
            OnPlaybackStarted?.Invoke();
        }

        private void StopInternal(bool raiseEvents)
        {
            bool wasPlaying = _playing;
            if (audioSource != null && wasPlaying)
            {
                audioSource.Stop();
            }

            _playing = false;
            _isPaused = false;
            _warmPaused = false;
            _allDataWritten = false;
            _shouldComplete = false;
            ClearRingBuffer();
            _currentAmplitude = 0f;

            if (raiseEvents && wasPlaying)
            {
                OnPlaybackStopped?.Invoke();
            }
        }

        private void Update()
        {
            if (!_initialized)
            {
                return;
            }

            lock (_sync)
            {
                if (!_playing)
                {
                    // Warm-up: start once we have enough buffered audio.
                    if (!_isPaused && !_warmPaused && _count > 0)
                    {
                        float buffered = _count / (float)sampleRate;
                        if (buffered >= bufferThresholdSeconds)
                        {
                            StartPlaybackInternal();
                        }
                    }
                    return;
                }

                if (_isPaused)
                {
                    return;
                }

                // Completion handling signalled from the audio thread.
                if (_shouldComplete)
                {
                    _shouldComplete = false;
                    StopInternal(false);
                    AvatarLogger.LogInfo("Audio playback completed.");
                    OnPlaybackCompleted?.Invoke();
                    return;
                }

                // Stall handling: if the buffer starves and data was fully written,
                // drain silently up to the undermix tolerance before halting.
                if (_count == 0 && _allDataWritten)
                {
                    _underrunSilentTime += Time.deltaTime;
                    if (_underrunSilentTime >= underrunToleranceSeconds)
                    {
                        StopInternal(false);
                        AvatarLogger.LogInfo("Audio playback ended (buffer fully drained).");
                        OnPlaybackCompleted?.Invoke();
                    }
                }
                else
                {
                    _underrunSilentTime = 0f;
                }
            }
        }

        /// <summary>
        /// Unity audio-thread callback. Pulls mono samples from the ring buffer and
        /// expands them to the current mixer channel layout. Never touches Unity APIs
        /// that are forbidden on the audio thread.
        /// </summary>
        private void OnAudioFilterRead(float[] data, int outputChannels)
        {
            if (!_initialized)
            {
                return;
            }
            if (outputChannels <= 0 || data == null)
            {
                return;
            }

            int frames = data.Length / outputChannels;
            if (frames > _scratchMono.Length)
            {
                return; // extremely unlikely; skip to avoid overflow
            }

            lock (_sync)
            {
                int got = ReadSamples(_scratchMono, frames);

                if (got < frames)
                {
                    int missing = frames - got;
                    for (int i = got; i < frames; i++)
                    {
                        _scratchMono[i] = 0f;
                    }

                    if (_playing && !_isPaused)
                    {
                        if (_allDataWritten)
                        {
                            _shouldComplete = true;
                        }
                        else
                        {
                            _underrunCount++;
                        }
                    }
                }

                // Compute RMS amplitude of samples actually consumed (fallback lip-sync).
                float sum = 0f;
                for (int i = 0; i < got; i++)
                {
                    float v = _scratchMono[i];
                    sum += v * v;
                }
                float rms = got > 0 ? Mathf.Sqrt(sum / got) : 0f;
                _currentAmplitude = Mathf.Clamp01(rms * 4f);
            }

            // Expand mono -> mixer channels.
            for (int f = 0; f < frames; f++)
            {
                float sample = _scratchMono[f];
                int baseIndex = f * outputChannels;
                for (int c = 0; c < outputChannels; c++)
                {
                    data[baseIndex + c] = sample;
                }
            }
        }

        private void OnDestroy()
        {
            lock (_sync)
            {
                if (audioSource != null && audioSource.clip != null && Application.isPlaying)
                {
                    audioSource.Stop();
                }
            }
        }
    }
}