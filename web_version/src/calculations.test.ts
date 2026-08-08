import { describe, expect, it } from "vitest";
import { calculateCosts, getRequiredConflicts } from "./calculations";
import { initialState } from "./domain";

describe("真实成本", () => {
  it("可退押金只进入首期现金，不摊入月均成本", () => {
    const listing = structuredClone(initialState.task.listings[1]);
    const result = calculateCosts(listing, 12);
    expect(result.monthlyHousing).toBe(8380);
    expect(result.firstCash).toBe(16400);
  });

  it("未知费用不会按 0 处理", () => {
    const result = calculateCosts(structuredClone(initialState.task.listings[2]), 12);
    expect(result.unknowns).toContain("押金");
  });

  it("硬性条件未知也会保留为风险", () => {
    const task = structuredClone(initialState.task);
    task.listings[0].conditionResults.commute = "unknown";
    expect(getRequiredConflicts(task, task.listings[0]).map((item) => item.id)).toContain("commute");
  });
});
