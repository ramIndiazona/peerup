namespace AvatarUnity.Core
{
    /// <summary>
    /// Structured error codes used across the avatar system. Errors are reported
    /// through diagnostics and optionally the Flutter bridge. No subsystem is
    /// allowed to throw an exception purely because one of these occurred.
    /// </summary>
    public enum AvatarErrorCode
    {
        Unknown = 0,
        MissingAnimator = 1,
        MissingFaceRenderer = 2,
        InvalidAudioConfiguration = 3,
        InvalidBridgeMessage = 4,
        InvalidViseme = 5,
        AudioBufferFailure = 6,
        InitializationFailure = 7
    }

    /// <summary>
    /// Immutable description of an avatar error.
    /// </summary>
    public readonly struct AvatarError
    {
        public AvatarErrorCode Code { get; }
        public string Message { get; }
        public double TimestampSeconds { get; }

        public AvatarError(AvatarErrorCode code, string message, double timestampSeconds)
        {
            Code = code;
            Message = message ?? string.Empty;
            TimestampSeconds = timestampSeconds;
        }

        public override string ToString()
        {
            return $"[{Code}] {Message}";
        }
    }
}