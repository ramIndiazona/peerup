/*
  Warnings:

  - Added the required column `profileId` to the `UserInterest` table without a default value. This is not possible if the table is not empty.

*/
-- DropForeignKey
ALTER TABLE "UserInterest" DROP CONSTRAINT "UserInterest_profile_fkey";

-- AlterTable
ALTER TABLE "UserInterest" ADD COLUMN     "profileId" TEXT NOT NULL;

-- CreateIndex
CREATE INDEX "UserInterest_profileId_idx" ON "UserInterest"("profileId");

-- AddForeignKey
ALTER TABLE "UserInterest" ADD CONSTRAINT "UserInterest_profileId_fkey" FOREIGN KEY ("profileId") REFERENCES "Profile"("id") ON DELETE CASCADE ON UPDATE CASCADE;
