-- CreateEnum
CREATE TYPE "FriendRequestStatus" AS ENUM ('PENDING', 'ACCEPTED', 'DECLINED', 'CANCELLED');

-- CreateTable
CREATE TABLE "FriendRequest" (
    "id" TEXT NOT NULL,
    "senderId" TEXT NOT NULL,
    "receiverId" TEXT NOT NULL,
    "status" "FriendRequestStatus" NOT NULL DEFAULT 'PENDING',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "FriendRequest_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "DirectConversation" (
    "id" TEXT NOT NULL,
    "userOneId" TEXT NOT NULL,
    "userTwoId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "DirectConversation_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "DirectMessage" (
    "id" TEXT NOT NULL,
    "conversationId" TEXT NOT NULL,
    "senderId" TEXT NOT NULL,
    "text" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "readAt" TIMESTAMP(3),

    CONSTRAINT "DirectMessage_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "FriendRequest_receiverId_status_idx" ON "FriendRequest"("receiverId", "status");

-- CreateIndex
CREATE INDEX "FriendRequest_senderId_status_idx" ON "FriendRequest"("senderId", "status");

-- CreateIndex
CREATE UNIQUE INDEX "DirectConversation_userOneId_userTwoId_key" ON "DirectConversation"("userOneId", "userTwoId");

-- CreateIndex
CREATE INDEX "DirectMessage_conversationId_createdAt_idx" ON "DirectMessage"("conversationId", "createdAt");

-- AddForeignKey
ALTER TABLE "FriendRequest" ADD CONSTRAINT "FriendRequest_senderId_fkey" FOREIGN KEY ("senderId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FriendRequest" ADD CONSTRAINT "FriendRequest_receiverId_fkey" FOREIGN KEY ("receiverId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DirectMessage" ADD CONSTRAINT "DirectMessage_conversationId_fkey" FOREIGN KEY ("conversationId") REFERENCES "DirectConversation"("id") ON DELETE CASCADE ON UPDATE CASCADE;
