import { describe, expect, it } from "vitest";
import { initialState } from "./domain";
import { buildDecisionReport, buildTestSummary } from "./report";

describe("隐私导出", () => {
  it("决策报告不包含原始图片字段", () => {
    const state = structuredClone(initialState);
    state.task.finalListingId = "xuhui";
    const report = buildDecisionReport(state);
    expect(report).not.toContain("imageUrl");
    expect(report).not.toContain("screenshotId");
    expect(report).not.toContain("data:image");
  });

  it("测试摘要只保留计数和布尔行为", () => {
    const state = structuredClone(initialState);
    const summary = buildTestSummary(state);
    expect(summary.comparedAtLeastTwo).toBe(false);
    expect(summary.adjustedFocusOrElimination).toBe(false);
    state.task.events.push({ id: "event-1", type: "compared", listingId: "xuhui", at: "2026-08-09" });
    expect(buildTestSummary(state).comparedAtLeastTwo).toBe(true);
    const text = JSON.stringify(summary);
    expect(text).not.toContain("7800");
    expect(text).not.toContain("徐汇");
    expect(text).not.toContain("上海");
  });

  it("决策报告包含淘汰原因", () => {
    const state = structuredClone(initialState);
    state.task.listings[2].status = "eliminated";
    state.task.listings[2].eliminationReason = "通勤超出硬性上限";
    expect(buildDecisionReport(state)).toContain("通勤超出硬性上限");
  });
});
