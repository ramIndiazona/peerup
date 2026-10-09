namespace AvatarUnity.Face
{
    /// <summary>
    /// Logical facial channels that can be mapped to blend shapes. Nothing here is
    /// hardcoded to a numeric blend-shape index; the <see cref="Config.AvatarFaceConfig"/>
    /// maps each channel to an actual blend shape by name at initialization.
    /// </summary>
    public enum FaceChannel
    {
        None = 0,

        // Mouth / speech
        JawOpen = 1,
        MouthClose = 2,
        MouthFunnel = 3,
        MouthPucker = 4,
        MouthSmile = 5,
        MouthFrown = 6,
        MouthSmileLeft = 7,
        MouthSmileRight = 8,
        MouthFrownLeft = 9,
        MouthFrownRight = 10,

        // Eyes
        EyeBlinkLeft = 20,
        EyeBlinkRight = 21,
        EyeSquintLeft = 22,
        EyeSquintRight = 23,

        // Brows
        BrowUpLeft = 30,
        BrowUpRight = 31,
        BrowDownLeft = 32,
        BrowDownRight = 33,

        // Cheeks / nose
        CheekRaiseLeft = 40,
        CheekRaiseRight = 41,
        NoseWrinkleLeft = 42,
        NoseWrinkleRight = 43,
        MouthDimple = 44
    }
}