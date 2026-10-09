namespace AvatarUnity.Bridge
{
    /// <summary>
    /// Abstraction over whatever channel carries JSON messages to Flutter
    /// (Unity as a Library native bridge, a message channel, a socket, etc.).
    /// The avatar system only talks to this interface — it never depends on a
    /// specific Flutter plugin.
    /// </summary>
    public interface IExternalMessageBridge
    {
        /// <summary>Sends one JSON message to the host application (Flutter).</summary>
        void SendMessage(string json);
    }
}