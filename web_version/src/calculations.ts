import type { Listing, RentalTask } from "./domain";

export interface CostSummary {
  monthlyHousing?: number;
  firstCash?: number;
  monthlyFees: number;
  amortizedOneTime: number;
  firstCashExtras: number;
  unknowns: string[];
}

export function calculateCosts(listing: Listing, expectedMonths: number): CostSummary {
  const unknowns = listing.costs
    .filter((item) => !item.confirmed || item.amount === undefined)
    .map((item) => item.name);
  const known = listing.costs.filter((item) => item.confirmed && item.amount !== undefined);
  const monthly = known
    .filter((item) => item.cadence !== "oneTime")
    .reduce((sum, item) => sum + toMonthlyAmount(item.amount ?? 0, item.cadence), 0);
  const amortized = known
    .filter((item) => item.cadence === "oneTime" && !item.refundable)
    .reduce((sum, item) => sum + (item.amount ?? 0) / Math.max(expectedMonths, 1), 0);
  const firstCashExtra = known
    .filter((item) => item.cadence === "oneTime")
    .reduce((sum, item) => sum + (item.amount ?? 0), 0);
  return {
    monthlyHousing: listing.rent + monthly + amortized,
    firstCash: firstCashExtra,
    monthlyFees: monthly,
    amortizedOneTime: amortized,
    firstCashExtras: firstCashExtra,
    unknowns,
  };
}

export function toMonthlyAmount(amount: number, cadence: Listing["costs"][number]["cadence"]): number {
  switch (cadence) {
    case "daily":
      return amount * 30;
    case "quarterly":
      return amount / 3;
    case "semiAnnual":
      return amount / 6;
    case "annual":
      return amount / 12;
    case "monthly":
    case "oneTime":
      return amount;
  }
}

export const formatMoney = (value?: number, currency = "CNY") => {
  if (value === undefined) return "待补充";
  const prefix =
    currency === "CNY" || currency === "人民币"
      ? "¥"
      : currency === "USD"
        ? "US$"
        : currency === "EUR"
          ? "€"
          : `${currency} `;
  return `${prefix}${Math.round(value).toLocaleString("zh-CN")}`;
};

export function getRequiredConflicts(task: RentalTask, listing: Listing) {
  return task.conditions.filter(
    (condition) => condition.importance === "required" && listing.conditionResults[condition.id] !== "met",
  );
}

export function getInspectionIssues(listing: Listing) {
  return listing.inspections.filter((item) => !item.hidden && item.state === "issue");
}
