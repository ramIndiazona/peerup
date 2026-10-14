-- CreateTable
CREATE TABLE "tongue_twisters" (
    "id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "text" TEXT NOT NULL,
    "level" TEXT NOT NULL DEFAULT 'beginner',
    "seconds" INTEGER NOT NULL DEFAULT 60,
    "xp" INTEGER NOT NULL DEFAULT 10,
    "color" TEXT NOT NULL DEFAULT '#625FE8',
    "icon" TEXT NOT NULL DEFAULT 'record_voice_over',
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "tongue_twisters_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "tongue_twisters_level_idx" ON "tongue_twisters"("level");

-- CreateIndex
CREATE INDEX "tongue_twisters_isActive_idx" ON "tongue_twisters"("isActive");
