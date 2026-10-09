namespace AvatarUnity.Face
{
    /// <summary>
    /// High level emotions the avatar can express. Emotions drive facial channels
    /// through the <see cref="EmotionController"/> and never overwrite lip-sync
    /// mouth channels (those are owned by the speech layer).
    /// </summary>
    public enum AvatarEmotion
    {
        Neutral = 0,
        Happy = 1,
        Encouraging = 2,
        Curious = 3,
        Thinking = 4,
        Excited = 5,
        Concerned = 6,
        Surprised = 7
    }
}