import type { Listing, RentalTask } from "./domain";

export interface CostSummary {
  monthlyHousing?: number;
  firstCash?: number;
  monthlyFees: number;
  amortizedOneTime: number;
  prepaidRent?: number;
  firstCashExtras: number;
  unknowns: string[];
}

export function calculateCosts(listing: Listing, expectedMonths: number): CostSummary {
  const unknowns = listing.costs
    .filter((item) => !item.confirmed || item.amount === undefined)
    .map((item) => item.name);
  if (listing.prepaidRentMonths === undefined) unknowns.unshift("预付租金月数");
  const known = listing.costs.filter((item) => item.confirmed && item.amount !== undefined);
  const monthly = known.filter((item) => item.cadence === "monthly").reduce((sum, item) => sum + (item.amount ?? 0), 0);
  const amortized = known
    .filter((item) => item.cadence === "oneTime" && !item.refundable)
    .reduce((sum, item) => sum + (item.amount ?? 0) / Math.max(expectedMonths, 1), 0);
  const firstCashExtra = known
    .filter((item) => item.cadence === "oneTime")
    .reduce((sum, item) => sum + (item.amount ?? 0), 0);
  return {
    monthlyHousing: listing.rent + monthly + amortized,
    firstCash:
      listing.prepaidRentMonths === undefined ? undefined : listing.rent * listing.prepaidRentMonths + firstCashExtra,
    monthlyFees: monthly,
    amortizedOneTime: amortized,
    prepaidRent: listing.prepaidRentMonths === undefined ? undefined : listing.rent * listing.prepaidRentMonths,
    firstCashExtras: firstCashExtra,
    unknowns,
  };
}

export const formatMoney = (value?: number) =>
  value === undefined ? "待补充" : `¥${Math.round(value).toLocaleString("zh-CN")}`;

export function getRequiredConflicts(task: RentalTask, listing: Listing) {
  return task.conditions.filter(
    (condition) => condition.importance === "required" && listing.conditionResults[condition.id] !== "met",
  );
}

export function getInspectionIssues(listing: Listing) {
  return listing.inspections.filter((item) => !item.hidden && item.state === "issue");
}
