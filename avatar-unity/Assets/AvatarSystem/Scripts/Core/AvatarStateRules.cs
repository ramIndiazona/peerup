namespace AvatarUnity.Core
{
    /// <summary>
    /// Pure, side-effect free state transition rules for <see cref="AvatarState"/>.
    /// Kept separate from the controller so EditMode unit tests can validate the
    /// rules without constructing Unity objects.
    /// </summary>
    public static class AvatarStateRules
    {
        private const int StateCount = 7;

        private enum S : int
        {
            Initializing = 0,
            Idle = 1,
            Listening = 2,
            Thinking = 3,
            Speaking = 4,
            Interrupted = 5,
            Error = 6
        }

        // Row = source state, Column = destination state. True means allowed.
        private static readonly bool[,] TransitionTable = BuildTable();

        private static bool[,] BuildTable()
        {
            var t = new bool[StateCount, StateCount];
            Set(t, S.Initializing, S.Idle);
            Set(t, S.Idle, S.Listening);
            Set(t, S.Listening, S.Thinking);
            Set(t, S.Listening, S.Speaking);
            Set(t, S.Listening, S.Idle);
            Set(t, S.Thinking, S.Speaking);
            Set(t, S.Thinking, S.Listening);
            Set(t, S.Thinking, S.Idle);
            Set(t, S.Speaking, S.Idle);
            Set(t, S.Speaking, S.Interrupted);
            Set(t, S.Interrupted, S.Listening);
            // Any -> Error
            for (int i = 0; i < StateCount; i++)
            {
                // Re-entering Error is also technically "allowed" but issue nothing.
                t[i, (int)S.Error] = true;
            }
            // Recovery out of Error
            Set(t, S.Error, S.Idle);
            Set(t, S.Error, S.Listening);
            return t;
        }

        private static void Set(bool[,] table, S from, S to)
        {
            table[(int)from, (int)to] = true;
        }

        public static bool IsAllowed(AvatarState from, AvatarState to)
        {
            int f = (int)from;
            int d = (int)to;
            if (f < 0 || f >= StateCount || d < 0 || d >= StateCount)
            {
                return false;
            }
            if (f == d)
            {
                return true;
            }
            return TransitionTable[f, d];
        }
    }
}