import { describe, expect, it } from "vitest";
import { formatCommuteMode, getComparisonListings, initialState, normalizeTask } from "./domain";

describe("候选池状态", () => {
  it("淘汰房源会退出比较且不再作为基准", () => {
    const task = structuredClone(initialState.task);
    task.listings[0].status = "eliminated";
    const normalized = normalizeTask(task);
    expect(normalized.comparisonIds).not.toContain("xuhui");
    expect(normalized.baselineId).toBe("jingan");
  });

  it("撤回最终选择后可保持任务继续进行", () => {
    const task = structuredClone(initialState.task);
    task.finalListingId = undefined;
    task.completed = false;
    expect(normalizeTask(task).completed).toBe(false);
  });

  it("比较上限固定为 5 套", () => {
    const task = structuredClone(initialState.task);
    task.comparisonIds = ["1", "2", "3", "4", "5", "6"];
    task.listings = task.comparisonIds.map((id) => ({ ...structuredClone(task.listings[0]), id }));
    expect(normalizeTask(task).comparisonIds).toHaveLength(5);
  });

  it("更换基准后会把基准房源固定在比较首位", () => {
    const task = structuredClone(initialState.task);
    task.baselineId = "jingan";
    expect(getComparisonListings(task).map((listing) => listing.id)).toEqual(["jingan", "xuhui"]);
  });

  it("旧本地记录缺少照片集合时仍可正常归一化", () => {
    const task = structuredClone(initialState.task);
    delete task.listings[0].photoIds;
    expect(normalizeTask(task).listings[0].photoIds).toEqual([]);
  });

  it("通勤方式使用用户可见的中文文案", () => {
    expect(formatCommuteMode("subway")).toBe("地铁");
    expect(formatCommuteMode("walking")).toBe("步行");
    expect(formatCommuteMode("driving")).toBe("开车");
  });
});
