import SwiftUI

struct ResultView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let finalListingID: UUID
    @State private var showingWithdraw = false
    @State private var reportURL: URL?

    private var finalListing: Listing? { store.task.listings.first { $0.id == finalListingID } }

    var body: some View {
        List {
            if let finalListing {
                Section {
                    ListingImageView(listing: finalListing)
                        .frame(height: 220)
                        .listRowInsets(EdgeInsets())
                    Label("最终房源", systemImage: "checkmark.seal.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                    Text(finalListing.name).font(.title2.bold())
                    if let reason = store.task.finalReason { Text(reason).foregroundStyle(.secondary) }
                }
                let costs = DecisionEngine.calculateCosts(for: finalListing, expectedMonths: store.task.expectedMonths)
                Section("关键数据") {
                    LabeledContent("月均居住成本", value: costs.monthlyHousing.formattedMoney(currency: finalListing.currency))
                    LabeledContent("首期现金", value: costs.firstCash.formattedMoney(currency: finalListing.currency))
                    LabeledContent("单程通勤", value: finalListing.commuteMinutes.map { "\($0) 分钟" } ?? "待补充")
                    LabeledContent("未知费用", value: costs.unknowns.isEmpty ? "无" : "\(costs.unknowns.count) 项")
                    LabeledContent("看房异常", value: "\(DecisionEngine.inspectionIssues(in: finalListing).count) 项")
                }
                Section {
                    if let reportURL {
                        ShareLink(item: reportURL) {
                            Label("导出决策报告", systemImage: "square.and.arrow.up")
                        }
                        .accessibilityIdentifier("shareReportButton")
                    } else {
                        Button("准备决策报告", systemImage: "doc") { prepareReport() }
                    }
                } footer: {
                    Text("报告不会包含原始截图或看房照片。")
                }
                Section {
                    Button("撤回最终选择") { showingWithdraw = true }
                }
            } else {
                ContentUnavailableView("最终房源不存在", systemImage: "house.slash")
            }
        }
        .navigationTitle("决策结果")
        .onAppear { prepareReport() }
        .alert("撤回最终选择？", isPresented: $showingWithdraw) {
            Button("取消", role: .cancel) {}
            Button("撤回") {
                store.withdrawFinal()
                dismiss()
            }
        } message: {
            Text("任务会恢复为进行中，房源和比较记录不会丢失。")
        }
    }

    private func prepareReport() {
        reportURL = try? ReportBuilder.writeTemporaryReport(for: store.state)
    }
}
