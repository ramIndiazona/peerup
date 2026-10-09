using System;
using System.Collections.Concurrent;
using System.Threading;
using UnityEngine;

namespace AvatarUnity.Core
{
    /// <summary>
    /// Lightweight main-thread action dispatcher.
    ///
    /// Incoming bridge / network / audio events may arrive from any thread.
    /// Any code that touches Unity objects must run on the Unity main thread.
    /// Enqueue work here and it will be executed in <see cref="Update"/>.
    /// </summary>
    [DefaultExecutionOrder(-1000)]
    public sealed class UnityMainThreadDispatcher : MonoBehaviour
    {
        private static UnityMainThreadDispatcher _instance;

        private readonly ConcurrentQueue<Action> _queue = new ConcurrentQueue<Action>();
        private readonly object _gate = new object();
        private bool _disposed;

        /// <summary>Singleton accessor. Creates a persistent instance if needed.</summary>
        public static UnityMainThreadDispatcher Instance
        {
            get
            {
                if (_instance == null)
                {
                    var go = new GameObject("UnityMainThreadDispatcher");
                    _instance = go.AddComponent<UnityMainThreadDispatcher>();
                    DontDestroyOnLoad(go);
                }
                return _instance;
            }
        }

        /// <summary>True when called from the Unity main thread.</summary>
        public static bool IsMainThread => _mainThreadId == Thread.CurrentThread.ManagedThreadId;

        private static int _mainThreadId;

        private void Awake()
        {
            _mainThreadId = Thread.CurrentThread.ManagedThreadId;
            if (_instance != null && _instance != this)
            {
                Destroy(gameObject);
                return;
            }
            _instance = this;
            DontDestroyOnLoad(gameObject);
        }

        /// <summary>Queue an action to run on the Unity main thread.</summary>
        public void Enqueue(Action action)
        {
            if (action == null)
            {
                return;
            }
            if (IsMainThread)
            {
                // Execute immediately on main thread - avoids a frame of latency.
                ExecuteSafely(action);
                return;
            }
            _queue.Enqueue(action);
        }

        /// <summary>Static helper mirroring <see cref="Enqueue"/>.</summary>
        public static void ExecuteOnMainThread(Action action)
        {
            Instance.Enqueue(action);
        }

        private void Update()
        {
            // Drain a bounded number of queued actions per frame to remain frame-time friendly.
            int budget = 64;
            while (budget-- > 0 && _queue.TryDequeue(out Action action))
            {
                ExecuteSafely(action);
            }
        }

        private static void ExecuteSafely(Action action)
        {
            try
            {
                action?.Invoke();
            }
            catch (Exception ex)
            {
                Debug.LogWarning($"[AvatarUnity] Exception escaped main-thread dispatch: {ex}");
            }
        }

        private void OnDestroy()
        {
            lock (_gate)
            {
                _disposed = true;
                if (_instance == this)
                {
                    _instance = null;
                }
            }
        }
    }
}