using UnityEngine;
using AvatarUnity.Config;
using AvatarUnity.Diagnostics;
using Random = UnityEngine.Random;

namespace AvatarUnity.Face
{
    /// <summary>
    /// Eye / head look-at behaviour.
    ///
    /// The avatar looks toward a target (by default a camera or a configured
    /// LookTarget transform). Look is smoothed, clamped to MaxYaw/MaxPitch, and
    /// softened with small random micro-deviations so the character never stares
    /// unnaturally. Uses Animator IK when the rig is humanoid, otherwise falls back
    /// to direct bone rotation. Missing bones cause a graceful downgrade, not an error.
    /// </summary>
    [DisallowMultipleComponent]
    public sealed class EyeLookController : MonoBehaviour
    {
        [SerializeField] private Transform lookTarget;

        [Tooltip("Optional explicit head bone. Resolved from the Animator if left empty.")]
        [SerializeField] private Transform headBone;

        [Tooltip("Optional explicit eye bones. Resolved from the Animator if left empty.")]
        [SerializeField] private Transform leftEyeBone;
        [SerializeField] private Transform rightEyeBone;

        [SerializeField] private bool lookEnabled = true;

        private Animator _animator;
        private AvatarConfig _config;
        private bool _initialized;
        private bool _useAnimatorIk;

        private float _maxYaw = 25f;
        private float _maxPitch = 18f;
        private float _headWeight = 0.6f;
        private float _eyeWeight = 0.9f;
        private float _lookSmoothSpeed = 6f;
        private float _targetDistance = 1.8f;
        private float _microDeviation = 0.12f;

        private Vector3 _smoothedLookPoint;
        private Vector3 _microOffset;
        private Vector3 _microOffsetTarget;
        private float _nextMicroChangeTime;

        public bool IsEnabled => lookEnabled;
        public bool HasLookTarget => lookTarget != null || (_animator != null && Camera.main != null);

        public void Initialize(Animator animator, AvatarConfig config)
        {
            _animator = animator;
            _config = config;

            if (config != null)
            {
                _maxYaw = Mathf.Clamp(config.MaxYaw, 5f, 80f);
                _maxPitch = Mathf.Clamp(config.MaxPitch, 5f, 60f);
                _headWeight = Mathf.Clamp01(config.HeadWeight);
                _eyeWeight = Mathf.Clamp01(config.EyeWeight);
                _lookSmoothSpeed = Mathf.Max(0.5f, config.LookSmoothSpeed);
                _targetDistance = Mathf.Max(0.5f, config.LookTargetDistance);
                _microDeviation = Mathf.Max(0f, config.MicroLookDeviation);
            }

            if (_animator != null)
            {
                _useAnimatorIk = _animator.isHuman;
                if (headBone == null)
                {
                    headBone = _animator.GetBoneTransform(HumanBodyBones.Head);
                }
                if (leftEyeBone == null)
                {
                    leftEyeBone = _animator.GetBoneTransform(HumanBodyBones.LeftEye);
                }
                if (rightEyeBone == null)
                {
                    rightEyeBone = _animator.GetBoneTransform(HumanBodyBones.RightEye);
                }
            }

            if (lookTarget == null)
            {
                Camera cam = Camera.main;
                if (cam != null)
                {
                    lookTarget = cam.transform;
                }
            }

            _smoothedLookPoint = ComputeDesiredLookPoint();
            _initialized = true;

            string mode = _useAnimatorIk ? "Animator IK" : (headBone != null ? "Bone fallback" : "Disabled");
            AvatarLogger.LogInfo($"EyeLookController initialized (mode: {mode}).");
        }

        /// <summary>Assigns (or reassigns) the world-space look target.</summary>
        public void SetLookTarget(Transform target)
        {
            lookTarget = target;
            if (_initialized)
            {
                _smoothedLookPoint = ComputeDesiredLookPoint();
            }
        }

        /// <summary>Enables / disables look behaviour at runtime.</summary>
        public void SetLookEnabled(bool enabled)
        {
            lookEnabled = enabled;
        }

        /// <summary>Unity IK callback - used automatically for humanoid rigs.</summary>
        private void OnAnimatorIK(int layerIndex)
        {
            if (!_initialized || !_useAnimatorIk || !lookEnabled)
            {
                return;
            }

            UpdateLookPosition();

            _animator.SetLookAtWeight(
                _headWeight,
                0.4f * _headWeight,   // body
                _headWeight,          // head
                _eyeWeight,           // eyes
                0f);                  // clamp

            _animator.SetLookAtPosition(_smoothedLookPoint);
        }

        private void Update()
        {
            if (!_initialized || _useAnimatorIk || !lookEnabled)
            {
                return;
            }

            UpdateLookPosition();

            Vector3 lookDir = (_smoothedLookPoint - HeadPosition()).normalized;

            if (headBone != null)
            {
                ApplyBoneLook(headBone, lookDir, _headWeight);
            }

            if (leftEyeBone != null && rightEyeBone != null)
            {
                ApplyBoneLook(leftEyeBone, lookDir, _eyeWeight);
                ApplyBoneLook(rightEyeBone, lookDir, _eyeWeight);
            }
        }

        private void UpdateLookPosition()
        {
            Vector3 desired = ComputeDesiredLookPoint();

            float smoothingFactor = 1f - Mathf.Exp(-Time.deltaTime * _lookSmoothSpeed);
            _smoothedLookPoint = Vector3.Lerp(_smoothedLookPoint, desired, smoothingFactor);

            RefreshMicroOffset();
            _smoothedLookPoint += _microOffset;
        }

        private Vector3 ComputeDesiredLookPoint()
        {
            Vector3 basePoint;
            if (lookTarget != null)
            {
                basePoint = lookTarget.position + Vector3.up * 0.05f;
            }
            else
            {
                basePoint = HeadPosition() + HeadForward() * _targetDistance;
            }

            Vector3 dir = basePoint - HeadPosition();
            float distance = dir.magnitude;
            if (distance < 0.001f)
            {
                return basePoint;
            }

            Quaternion inverseRotation = Quaternion.Inverse(transform.rotation);
            Vector3 localDir = inverseRotation * (dir / distance);

            float yaw = Mathf.Atan2(localDir.x, localDir.z) * Mathf.Rad2Deg;
            float pitch = Mathf.Atan2(localDir.y, localDir.z) * Mathf.Rad2Deg;

            yaw = Mathf.Clamp(yaw, -_maxYaw, _maxYaw);
            pitch = Mathf.Clamp(pitch, -_maxPitch, _maxPitch);

            Vector3 clampedDir = Quaternion.Euler(pitch, yaw, 0f) * Vector3.forward;
            return HeadPosition() + (transform.rotation * clampedDir) * _targetDistance;
        }

        private void RefreshMicroOffset()
        {
            if (Time.time >= _nextMicroChangeTime)
            {
                _microOffsetTarget = Random.insideUnitSphere * _microDeviation;
                _nextMicroChangeTime = Time.time + Random.Range(0.9f, 1.8f);
            }
            float factor = 1f - Mathf.Exp(-Time.deltaTime * 2.5f);
            _microOffset = Vector3.Lerp(_microOffset, _microOffsetTarget, factor);
        }

        private void ApplyBoneLook(Transform bone, Vector3 lookDirection, float weight)
        {
            if (bone == null)
            {
                return;
            }

            Vector3 boneDir = bone.rotation * Vector3.forward;
            Vector3 desired = Vector3.RotateTowards(boneDir, lookDirection, Mathf.Deg2Rad * 90f, 0f);

            Quaternion targetRotation = Quaternion.LookRotation(desired, Vector3.up);
            float t = 1f - Mathf.Exp(-Time.deltaTime * _lookSmoothSpeed);
            bone.rotation = Quaternion.Slerp(bone.rotation, targetRotation, t * Mathf.Clamp01(weight));
        }

        private Vector3 HeadPosition()
        {
            if (headBone != null)
            {
                return headBone.position;
            }
            return transform.position + Vector3.up * 1.6f;
        }

        private Vector3 HeadForward()
        {
            if (headBone != null)
            {
                return headBone.forward;
            }
            return transform.forward;
        }

        private void OnDestroy()
        {
            // No resources to release; kept for symmetry.
        }
    }
}