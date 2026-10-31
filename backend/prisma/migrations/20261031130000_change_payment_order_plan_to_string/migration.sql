-- Change PaymentOrder.plan from the SubscriptionPlan enum to a plain text
-- column so it can store the billing plan chosen for each order
-- ('monthly' / 'yearly'). The price behind each plan remains server-controlled.

-- AlterTable
ALTER TABLE "PaymentOrder" ALTER COLUMN "plan" TYPE text USING "plan"::text;
