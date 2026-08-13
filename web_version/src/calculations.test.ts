import { describe, expect, it } from "vitest";
import { calculateCosts, getRequiredConflicts } from "./calculations";
import { initialState } from "./domain";

describe("真实成本", () => {
  it("可退押金只进入首期现金，不摊入月均成本", () => {
    const listing = structuredClone(initialState.task.listings[1]);
    const result = calculateCosts(listing, 12);
    expect(result.monthlyHousing).toBe(8380);
    expect(result.firstCash).toBe(8200);
  });

  it("未知费用不会按 0 处理", () => {
    const result = calculateCosts(structuredClone(initialState.task.listings[2]), 12);
    expect(result.unknowns).toContain("押金");
  });

  it("首期现金不再要求或计算预付租金", () => {
    const listing = structuredClone(initialState.task.listings[1]);
    listing.prepaidRentMonths = undefined;
    const result = calculateCosts(listing, 12);
    expect(result.firstCash).toBe(8200);
    expect(result.unknowns).not.toContain("预付租金月数");
  });

  it("硬性条件未知也会保留为风险", () => {
    const task = structuredClone(initialState.task);
    task.listings[0].conditionResults.commute = "unknown";
    expect(getRequiredConflicts(task, task.listings[0]).map((item) => item.id)).toContain("commute");
  });

  it("每日、季度、半年和年度费用会折算为月均成本", () => {
    const listing = structuredClone(initialState.task.listings[1]);
    listing.costs = [
      { id: "daily", name: "日租服务", amount: 10, cadence: "daily", refundable: false, confirmed: true },
      { id: "quarter", name: "季度服务", amount: 300, cadence: "quarterly", refundable: false, confirmed: true },
      { id: "half", name: "半年服务", amount: 600, cadence: "semiAnnual", refundable: false, confirmed: true },
      { id: "annual", name: "年度服务", amount: 1200, cadence: "annual", refundable: false, confirmed: true },
    ];
    expect(calculateCosts(listing, 12).monthlyFees).toBe(600);
  });
});
