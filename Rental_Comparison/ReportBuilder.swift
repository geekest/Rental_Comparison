import Foundation

enum ReportBuilder {
    static func html(for state: DecisionAppState) -> String {
        html(for: DecisionLegacyProjection.appState(from: state))
    }

    static func html(for state: AppState) -> String {
        let task = state.task
        let finalName = task.listings.first { $0.id == task.finalListingID }?.name ?? "尚未确认"
        let sections = task.listings.map { listing in
            let costs = DecisionEngine.calculateCosts(for: listing, expectedMonths: task.expectedMonths)
            let risks = DecisionEngine.requiredConflicts(in: task, listing: listing).map(\.name).joined(separator: "、")
            let issues = DecisionEngine.inspectionIssues(in: listing).map { item in
                item.note.isEmpty ? item.name : "\(item.name)（\(item.note)）"
            }.joined(separator: "、")
            let status = listing.id == task.finalListingID ? "最终房源" : listing.status == .eliminated ? "已淘汰" : "候选"
            return """
            <section><h2>\(escape(listing.name))</h2>
            <p>状态：\(status)</p>
            <p>月租：\(listing.rent.formattedMoney(currency: listing.currency))；月均居住成本：\(costs.monthlyHousing.formattedMoney(currency: listing.currency))；首期现金：\(costs.firstCash.formattedMoney(currency: listing.currency))</p>
            <p>单程通勤：\(listing.commuteMode?.title ?? "方式待补充") · \(listing.commuteMinutes.map(String.init) ?? "未知") 分钟</p>
            <p>硬性条件风险：\(escape(risks.isEmpty ? "无已知冲突" : risks))</p>
            <p>看房异常：\(escape(issues.isEmpty ? "无已记录异常" : issues))</p>
            <p>未知费用：\(escape(costs.unknowns.isEmpty ? "无" : costs.unknowns.joined(separator: "、")))</p></section>
            """
        }.joined()

        return """
        <!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>\(escape(task.title)) · 决策结果</title>
        <style>body{font-family:-apple-system,"PingFang SC",sans-serif;max-width:760px;margin:40px auto;padding:0 24px;color:#1d1d1f}section{padding:20px 0;border-bottom:1px solid #ddd}small{color:#6e6e73}</style>
        <body><h1>\(escape(task.title))</h1><p>城市：\(escape(task.city))；预计租期：\(task.expectedMonths) 个月；通勤目的地：\(escape(task.commuteDestination))</p>
        <h2>最终决定</h2><p>\(escape(finalName))</p><p>选择理由：\(escape(task.finalReason ?? "未填写"))</p>
        \(sections)<small>本报告不包含原始截图或看房照片。数据由用户在当前设备整理，系统未替用户给出综合评分或推荐。</small></body></html>
        """
    }

    static func writeTemporaryReport(for state: AppState) throws -> URL {
        let safeTitle = state.task.title.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appending(path: "\(safeTitle)-决策报告.html")
        try html(for: state).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func writeTemporaryReport(for state: DecisionAppState) throws -> URL {
        let safeTitle = state.hunt.title.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appending(path: "\(safeTitle)-决策报告.html")
        try html(for: state).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
