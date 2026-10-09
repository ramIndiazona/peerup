using System;
using System.Collections.Generic;
using UnityEngine;
using AvatarUnity.Face;

namespace AvatarUnity.Config
{
    /// <summary>
    /// Maps provider viseme IDs (for example Azure Speech viseme IDs, or a future
    /// custom phoneme engine) to logical face channels / blend shapes.
    ///
    /// The core lip-sync code never assumes a specific provider's scheme — it always
    /// resolves provider IDs through this configuration.
    /// </summary>
    [CreateAssetMenu(fileName = "VisemeMappingConfig", menuName = "Avatar System/Viseme Mapping Config")]
    public sealed class VisemeMappingConfig : ScriptableObject
    {
        [Header("Neutral (idle mouth)")]
        [SerializeField] private int neutralProviderId = 0;

        [Header("Provider id -> channels")]
        [SerializeField] private List<VisemeMapping> visemes = new List<VisemeMapping>();

        public int NeutralProviderId => neutralProviderId;
        public IReadOnlyList<VisemeMapping> Visemes => visemes;

        /// <summary>Returns the mapping for a provider viseme id, or null.</summary>
        public VisemeMapping FindByProviderId(int providerId)
        {
            for (int i = 0; i < visemes.Count; i++)
            {
                if (visemes[i].ProviderVisemeId == providerId && visemes[i].Enabled)
                {
                    return visemes[i];
                }
            }
            return null;
        }
    }

    /// <summary>A single provider viseme mapped onto face channels.</summary>
    [Serializable]
    public sealed class VisemeMapping
    {
        [SerializeField] private int providerVisemeId;
        [SerializeField] private string name = "Viseme";
        [SerializeField] private bool enabled = true;
        [SerializeField] private List<VisemeChannelValue> channels = new List<VisemeChannelValue>();

        public int ProviderVisemeId => providerVisemeId;
        public string Name => name;
        public bool Enabled => enabled;
        public IReadOnlyList<VisemeChannelValue> Channels => channels;
    }

    /// <summary>Weight of one face channel inside a viseme mapping.</summary>
    [Serializable]
    public sealed class VisemeChannelValue
    {
        [SerializeField] private FaceChannel channel;
        [SerializeField, Range(0f, 1f)] private float weight = 0f;

        public FaceChannel Channel => channel;
        public float Weight => weight;
    }
}