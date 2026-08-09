import { calculateCosts, formatMoney, getInspectionIssues, getRequiredConflicts } from "./calculations";
import type { AppState, Listing } from "./domain";

const escapeHtml = (value: string) => value.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;");

export function buildDecisionReport(state: AppState) {
  const { task } = state;
  const finalListing = task.listings.find((listing) => listing.id === task.finalListingId);
  const listingHtml = (listing: Listing) => {
    const costs = calculateCosts(listing, task.expectedMonths);
    return `<section><h2>${escapeHtml(listing.name)}</h2><p>状态：${listing.id === task.finalListingId ? "最终房源" : listing.status === "eliminated" ? "已淘汰" : "候选"}</p><p>月租：${formatMoney(listing.rent)}；月均居住成本：${formatMoney(costs.monthlyHousing)}；首期现金：${formatMoney(costs.firstCash)}</p><p>单程通勤：${listing.commuteMinutes ?? "未知"} 分钟；通勤支出：${listing.commuteFare === undefined ? "未知" : `${formatMoney(listing.commuteFare)}/次`}</p><p>硬性条件风险：${
      getRequiredConflicts(task, listing)
        .map((item) => escapeHtml(item.name))
        .join("、") || "无已知冲突"
    }</p><p>看房异常：${
      getInspectionIssues(listing)
        .map((item) => `${escapeHtml(item.name)}${item.note ? `（${escapeHtml(item.note)}）` : ""}`)
        .join("、") || "无已记录异常"
    }</p><p>未知费用：${costs.unknowns.map(escapeHtml).join("、") || "无"}</p>${
      listing.status === "eliminated" ? `<p>淘汰原因：${escapeHtml(listing.eliminationReason || "未填写")}</p>` : ""
    }</section>`;
  };
  return `<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>${escapeHtml(task.title)} · 决策结果</title><style>body{font-family:-apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif;max-width:760px;margin:40px auto;padding:0 24px;color:#1d1d1f}section{padding:20px 0;border-bottom:1px solid #ddd}small{color:#6e6e73}</style><body><h1>${escapeHtml(task.title)}</h1><p>城市：${escapeHtml(task.city)}；预计租期：${task.expectedMonths} 个月；通勤目的地：${escapeHtml(task.commuteDestination)}</p><h2>最终决定</h2><p>${finalListing ? escapeHtml(finalListing.name) : "尚未确认"}</p><p>选择理由：${escapeHtml(task.finalReason || "未填写")}</p>${task.listings.map(listingHtml).join("")}<small>本报告不包含原始截图或看房照片。数据由用户在当前设备整理，系统未替用户给出综合评分或推荐。</small></body></html>`;
}

export function downloadText(filename: string, content: string, type = "text/html") {
  const link = document.createElement("a");
  link.href = URL.createObjectURL(new Blob([content], { type }));
  link.download = filename;
  link.click();
  URL.revokeObjectURL(link.href);
}

export function buildTestSummary(state: AppState) {
  const { task } = state;
  return {
    testId: state.feedback.testId,
    listingCount: task.listings.length,
    comparedAtLeastTwo: task.events.some((event) => event.type === "compared"),
    recordedInspectionIssue: task.listings.some((listing) =>
      listing.inspections.some((inspection) => inspection.state === "issue"),
    ),
    adjustedFocusOrElimination: task.events.some((event) =>
      ["focused", "unfocused", "eliminated", "restored"].includes(event.type),
    ),
    finalDecisionMade: task.events.some((event) => event.type === "confirmed"),
    exportedAt: new Date().toISOString(),
  };
}
