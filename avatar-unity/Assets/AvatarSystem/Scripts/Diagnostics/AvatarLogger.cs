using UnityEngine;

namespace AvatarUnity.Diagnostics
{
    /// <summary>
    /// Central logging for every avatar subsystem. Production builds should set the
    /// level to <see cref="AvatarLogLevel.Warning"/> or <see cref="AvatarLogLevel.Error"/>
    /// to avoid log spam on mobile devices.
    /// </summary>
    public static class AvatarLogger
    {
        private static AvatarLogLevel _minLevel = AvatarLogLevel.Warning;
        private static readonly object Gate = new object();
        private static string _prefix = "[AvatarUnity]";

        /// <summary>Sets the minimum level that gets emitted.</summary>
        public static void Configure(AvatarLogLevel level)
        {
            lock (Gate)
            {
                _minLevel = level;
            }
        }

        /// <summary>Sets an optional prefix for all avatar log lines.</summary>
        public static void SetPrefix(string prefix)
        {
            lock (Gate)
            {
                _prefix = string.IsNullOrEmpty(prefix) ? "[AvatarUnity]" : prefix;
            }
        }

        public static void Log(AvatarLogLevel level, string message)
        {
            if (level == AvatarLogLevel.Off)
            {
                return;
            }
            if (level > _minLevel)
            {
                return;
            }

            string line = $"{_prefix} {message}";

            switch (level)
            {
                case AvatarLogLevel.Error:
                    Debug.LogError(line);
                    break;
                case AvatarLogLevel.Warning:
                    Debug.LogWarning(line);
                    break;
                default:
                    Debug.Log(line);
                    break;
            }
        }

        public static void LogError(string message) => Log(AvatarLogLevel.Error, message);
        public static void LogWarning(string message) => Log(AvatarLogLevel.Warning, message);
        public static void LogInfo(string message) => Log(AvatarLogLevel.Info, message);
        public static void LogVerbose(string message) => Log(AvatarLogLevel.Verbose, message);
    }
}