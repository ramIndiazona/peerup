namespace AvatarUnity.Animation
{
    /// <summary>
    /// Body gestures the avatar can perform. Gestures map onto the gesture layer of
    /// the Animator Controller through <see cref="AvatarAnimatorController"/>.
    /// </summary>
    public enum AvatarGesture
    {
        None = 0,
        Welcome = 1,
        Explain = 2,
        Point = 3,
        Nod = 4,
        Agree = 5,
        Think = 6,
        Celebrate = 7,
        Question = 8,
        Encourage = 9
    }
}