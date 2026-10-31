-- CreateEnum
CREATE TYPE "CallReaction" AS ENUM ('LIKE', 'DISLIKE');

-- CreateTable
CREATE TABLE "CallFeedback" (
    "id" TEXT NOT NULL,
    "dedupeKey" TEXT NOT NULL,
    "senderId" TEXT NOT NULL,
    "receiverId" TEXT NOT NULL,
    "callSessionId" TEXT,
    "reaction" "CallReaction",
    "feedback" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "addToFriends" BOOLEAN NOT NULL DEFAULT false,
    "connectAgain" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CallFeedback_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "CallFeedback_dedupeKey_key" ON "CallFeedback"("dedupeKey");

-- CreateIndex
CREATE INDEX "CallFeedback_senderId_createdAt_idx" ON "CallFeedback"("senderId", "createdAt");

-- CreateIndex
CREATE INDEX "CallFeedback_receiverId_createdAt_idx" ON "CallFeedback"("receiverId", "createdAt");

-- CreateIndex
CREATE INDEX "CallFeedback_callSessionId_idx" ON "CallFeedback"("callSessionId");

-- AddForeignKey
ALTER TABLE "CallFeedback" ADD CONSTRAINT "CallFeedback_senderId_fkey" FOREIGN KEY ("senderId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CallFeedback" ADD CONSTRAINT "CallFeedback_receiverId_fkey" FOREIGN KEY ("receiverId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CallFeedback" ADD CONSTRAINT "CallFeedback_callSessionId_fkey" FOREIGN KEY ("callSessionId") REFERENCES "CallSession"("id") ON DELETE SET NULL ON UPDATE CASCADE;
