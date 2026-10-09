using System;
using System.Collections.Generic;

namespace AvatarUnity.LipSync
{
    /// <summary>
    /// Pure, dependency-free scheduler for viseme events.
    ///
    /// Maintains a time-ordered queue and samples the "active" and "next" viseme for
    /// a given playback time, plus a blend factor for smooth transitions.
    /// Kept outside MonoBehaviour so it can be unit-tested without a Unity scene.
    /// </summary>
    public sealed class VisemeScheduler
    {
        private readonly List<VisemeEvent> _events = new List<VisemeEvent>();
        private readonly object _lock = new object();
        private readonly double _expireWindowMs;
        private readonly double _maxLookaheadMs;

        public VisemeScheduler(double expireWindowMs, double maxLookaheadMs = 300d)
        {
            _expireWindowMs = expireWindowMs;
            _maxLookaheadMs = maxLookaheadMs;
        }

        /// <summary>Number of still-relevant queued visemes.</summary>
        public int Count
        {
            get
            {
                lock (_lock)
                {
                    return _events.Count;
                }
            }
        }

        /// <summary>Queues a viseme in timestamp order.</summary>
        public void Queue(VisemeEvent viseme)
        {
            if (viseme == null)
            {
                return;
            }
            lock (_lock)
            {
                InsertSorted(viseme);
            }
        }

        /// <summary>Queues a batch of visemes.</summary>
        public void QueueRange(IEnumerable<VisemeEvent> visemes)
        {
            if (visemes == null)
            {
                return;
            }
            lock (_lock)
            {
                foreach (VisemeEvent e in visemes)
                {
                    if (e != null)
                    {
                        _events.Add(e);
                    }
                }
                _events.Sort(CompareEvents);
            }
        }

        /// <summary>Removes all queued visemes.</summary>
        public void Clear()
        {
            lock (_lock)
            {
                _events.Clear();
            }
        }

        /// <summary>
        /// Samples the current viseme window at <paramref name="nowMs"/>.
        ///
        /// Returns true when an active viseme exists. <paramref name="active"/> and
        /// <paramref name="next"/> may be null; <paramref name="blend"/> is 0..1,
        /// where 1 means fully on the next viseme.
        /// </summary>
        public bool TrySample(double nowMs, out VisemeEvent active, out VisemeEvent next, out float blend)
        {
            lock (_lock)
            {
                active = null;
                next = null;
                blend = 0f;

                double pruneBefore = nowMs - _expireWindowMs;
                PruneBefore(pruneBefore);

                if (_events.Count == 0)
                {
                    return false;
                }

                for (int i = 0; i < _events.Count; i++)
                {
                    VisemeEvent e = _events[i];
                    if (e.timestampMs <= nowMs)
                    {
                        active = e;
                    }
                    else
                    {
                        next = e;
                        break;
                    }
                }

                if (active == null)
                {
                    return false;
                }

                if (next == null)
                {
                    blend = 1f;
                    return true;
                }

                double span = next.timestampMs - active.timestampMs;
                blend = span > 0.0001
                    ? MathfClamp01((float)((nowMs - active.timestampMs) / span))
                    : 1f;
                return true;
            }
        }

        /// <summary>
        /// True when there is an active viseme or one arriving within the lookahead
        /// window. Used to decide whether explicit visemes are "driving" the mouth.
        /// </summary>
        public bool HasActiveWithin(double nowMs, double lookaheadMs)
        {
            lock (_lock)
            {
                double pruneBefore = nowMs - _expireWindowMs;
                PruneBefore(pruneBefore);
                if (_events.Count == 0)
                {
                    return false;
                }
                VisemeEvent e = _events[0];
                if (e.timestampMs <= nowMs)
                {
                    return true;
                }
                return e.timestampMs - nowMs <= lookaheadMs;
            }
        }

        private void InsertSorted(VisemeEvent viseme)
        {
            int index = _events.BinarySearch(viseme, EventComparer.Instance);
            if (index < 0)
            {
                index = ~index;
            }
            _events.Insert(index, viseme);
        }

        private void PruneBefore(double timestampMs)
        {
            int removeCount = 0;
            for (int i = 0; i < _events.Count; i++)
            {
                if (_events[i].timestampMs < timestampMs)
                {
                    removeCount++;
                }
                else
                {
                    break;
                }
            }
            if (removeCount > 0)
            {
                _events.RemoveRange(0, removeCount);
            }
        }

        private static int CompareEvents(VisemeEvent a, VisemeEvent b)
        {
            int cmp = a.timestampMs.CompareTo(b.timestampMs);
            if (cmp != 0)
            {
                return cmp;
            }
            return a.visemeId.CompareTo(b.visemeId);
        }

        private sealed class EventComparer : IComparer<VisemeEvent>
        {
            public static readonly EventComparer Instance = new EventComparer();
            public int Compare(VisemeEvent x, VisemeEvent y)
            {
                if (ReferenceEquals(x, y)) return 0;
                if (x == null) return -1;
                if (y == null) return 1;
                int cmp = x.timestampMs.CompareTo(y.timestampMs);
                return cmp != 0 ? cmp : x.visemeId.CompareTo(y.visemeId);
            }
        }

        private static float MathfClamp01(float value)
        {
            return value < 0f ? 0f : (value > 1f ? 1f : value);
        }
    }
}