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
    const text = JSON.stringify(buildTestSummary(structuredClone(initialState)));
    expect(text).not.toContain("7800");
    expect(text).not.toContain("徐汇");
    expect(text).not.toContain("上海");
  });
});
