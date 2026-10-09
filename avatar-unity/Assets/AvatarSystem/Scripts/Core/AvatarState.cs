namespace AvatarUnity.Core
{
    /// <summary>
    /// The high level behavioural state of the AI tutor avatar.
    /// The <see cref="AvatarStateController"/> is the single source of truth for this value.
    /// </summary>
    public enum AvatarState
    {
        Initializing = 0,
        Idle = 1,
        Listening = 2,
        Thinking = 3,
        Speaking = 4,
        Interrupted = 5,
        Error = 6
    }
}