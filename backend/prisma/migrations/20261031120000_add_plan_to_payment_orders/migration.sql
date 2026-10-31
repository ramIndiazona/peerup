-- Add the purchased billing plan to each payment order so the backend can
-- determine the subscription duration (monthly vs yearly) when verifying a
-- payment, without trusting any value supplied by the client.

-- AlterTable
ALTER TABLE "PaymentOrder" ADD COLUMN "plan" "SubscriptionPlan" NOT NULL DEFAULT 'FREE';
