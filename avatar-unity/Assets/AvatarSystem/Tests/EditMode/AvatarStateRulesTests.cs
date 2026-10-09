using NUnit.Framework;
using AvatarUnity.Core;

namespace AvatarUnity.Tests
{
    public class AvatarStateRulesTests
    {
        [Test]
        public void InitializingToIdle_IsAllowed()
        {
            Assert.IsTrue(AvatarStateRules.IsAllowed(AvatarState.Initializing, AvatarState.Idle));
        }

        [Test]
        public void FullConversationFlow_IsAllowed()
        {
            Assert.IsTrue(AvatarStateRules.IsAllowed(AvatarState.Idle, AvatarState.Listening));
            Assert.IsTrue(AvatarStateRules.IsAllowed(AvatarState.Listening, AvatarState.Thinking));
            Assert.IsTrue(AvatarStateRules.IsAllowed(AvatarState.Thinking, AvatarState.Speaking));
            Assert.IsTrue(AvatarStateRules.IsAllowed(AvatarState.Speaking, AvatarState.Idle));
        }

        [Test]
        public void SpeakingToInterrupted_IsAllowed()
        {
            Assert.IsTrue(AvatarStateRules.IsAllowed(AvatarState.Speaking, AvatarState.Interrupted));
        }

        [Test]
        public void InterruptedToListening_IsAllowed()
        {
            Assert.IsTrue(AvatarStateRules.IsAllowed(AvatarState.Interrupted, AvatarState.Listening));
        }

        [Test]
        public void AnyToError_IsAllowed()
        {
            Assert.IsTrue(AvatarStateRules.IsAllowed(AvatarState.Speaking, AvatarState.Error));
            Assert.IsTrue(AvatarStateRules.IsAllowed(AvatarState.Listening, AvatarState.Error));
            Assert.IsTrue(AvatarStateRules.IsAllowed(AvatarState.Idle, AvatarState.Error));
            Assert.IsTrue(AvatarStateRules.IsAllowed(AvatarState.Interrupted, AvatarState.Error));
        }

        [Test]
        public void ErrorToIdle_IsAllowed_ForRecovery()
        {
            Assert.IsTrue(AvatarStateRules.IsAllowed(AvatarState.Error, AvatarState.Idle));
        }

        [Test]
        public void IdleDirectToSpeaking_IsNotAllowed()
        {
            Assert.IsFalse(AvatarStateRules.IsAllowed(AvatarState.Idle, AvatarState.Speaking));
        }

        [Test]
        public void SpeakingToThinking_IsNotAllowed()
        {
            Assert.IsFalse(AvatarStateRules.IsAllowed(AvatarState.Speaking, AvatarState.Thinking));
        }

        [Test]
        public void SameState_IsAllowed()
        {
            Assert.IsTrue(AvatarStateRules.IsAllowed(AvatarState.Idle, AvatarState.Idle));
        }

        [Test]
        public void OutOfRange_IsNotAllowed()
        {
            Assert.IsFalse(AvatarStateRules.IsAllowed((AvatarState)(-1), AvatarState.Idle));
            Assert.IsFalse(AvatarStateRules.IsAllowed(AvatarState.Idle, (AvatarState)99));
        }
    }
}