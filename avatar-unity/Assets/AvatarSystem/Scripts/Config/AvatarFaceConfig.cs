using System;
using System.Collections.Generic;
using UnityEngine;
using AvatarUnity.Face;

namespace AvatarUnity.Config
{
    /// <summary>
    /// Defines how logical face channels map to real blend shapes by name.
    ///
    /// Renderer keys are logical names (for example "FaceMesh"). The runtime
    /// <see cref="Face.FacialExpressionController"/> binds renderers to keys at
    /// initialization by matching the keys with its own assigned mesh renderers.
    /// Blend-shape indexes are resolved by name once at initialization — no fixed
    /// numeric blend-shape indexes anywhere.
    /// </summary>
    [CreateAssetMenu(fileName = "AvatarFaceConfig", menuName = "Avatar System/Avatar Face Config")]
    public sealed class AvatarFaceConfig : ScriptableObject
    {
        [Header("Renderer keys in priority order")]
        [Tooltip("Logical names of the SkinnedMeshRenderers that carry facial blend shapes. "
                 + "The runtime controller binds its assigned renderers to these keys by index "
                 + "or by GameObject name.")]
        [SerializeField] private List<string> rendererKeys = new List<string> { "FaceMesh" };

        [Header("Blend-shape channel mappings")]
        [SerializeField] private List<FaceShapeMapping> channelMappings = new List<FaceShapeMapping>();

        [Header("Emotion definitions")]
        [SerializeField] private List<EmotionChannelMapping> emotionMappings = new List<EmotionChannelMapping>();

        public IReadOnlyList<string> RendererKeys => rendererKeys;
        public IReadOnlyList<FaceShapeMapping> ChannelMappings => channelMappings;
        public IReadOnlyList<EmotionChannelMapping> EmotionMappings => emotionMappings;

        /// <summary>Finds the mapping for a channel, or null.</summary>
        public FaceShapeMapping FindChannelMapping(FaceChannel channel)
        {
            for (int i = 0; i < channelMappings.Count; i++)
            {
                if (channelMappings[i].Channel == channel)
                {
                    return channelMappings[i];
                }
            }
            return null;
        }

        /// <summary>Finds the emotion definition, or null.</summary>
        public EmotionChannelMapping FindEmotion(AvatarEmotion emotion)
        {
            for (int i = 0; i < emotionMappings.Count; i++)
            {
                if (emotionMappings[i].Emotion == emotion)
                {
                    return emotionMappings[i];
                }
            }
            return null;
        }
    }

    /// <summary>Binds a single logical channel to a blend shape on a renderer key.</summary>
    [Serializable]
    public sealed class FaceShapeMapping
    {
        [SerializeField] private FaceChannel channel;
        [Tooltip("Renderer key from AvatarFaceConfig.rendererKeys. Empty = first renderer.")]
        [SerializeField] private string rendererKey;
        [SerializeField] private string blendShapeName;
        [SerializeField, Range(0f, 1f)] private float defaultWeight = 0f;
        [SerializeField, Range(0f, 1f)] private float maxWeight = 1f;
        [SerializeField] private bool applySmoothing = true;

        public FaceChannel Channel => channel;
        public string RendererKey => rendererKey ?? string.Empty;
        public string BlendShapeName => blendShapeName;
        public float DefaultWeight => defaultWeight;
        public float MaxWeight => maxWeight;
        public bool ApplySmoothing => applySmoothing;
    }

    /// <summary>Defines the facial channel targets that make up an emotion.</summary>
    [Serializable]
    public sealed class EmotionChannelMapping
    {
        [SerializeField] private AvatarEmotion emotion;
        [SerializeField] private List<EmotionChannelWeight> channels = new List<EmotionChannelWeight>();

        public AvatarEmotion Emotion => emotion;
        public IReadOnlyList<EmotionChannelWeight> Channels => channels;
    }

    /// <summary>A single normalized weight (0..1) for a face channel inside an emotion.</summary>
    [Serializable]
    public sealed class EmotionChannelWeight
    {
        [SerializeField] private FaceChannel channel;
        [SerializeField, Range(0f, 1f)] private float weight = 0f;

        public FaceChannel Channel => channel;
        public float Weight => weight;
    }
}