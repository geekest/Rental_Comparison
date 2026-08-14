import SwiftUI

struct ListingsView: View {
    @Environment(AppStore.self) private var store
    @Binding var showingTaskSettings: Bool
    @State private var showingAdd = false
    @State private var limitMessage: String?

    private var candidates: [Listing] { store.task.listings.filter { $0.status == .candidate } }
    private var eliminated: [Listing] { store.task.listings.filter { $0.status == .eliminated } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.task.completed ? "已完成" : "正在整理")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.blue)
                    Text(store.task.title)
                        .font(.largeTitle.bold())
                    Text("\(candidates.count) 套候选 · \(candidates.filter(\.focused).count) 套重点考虑")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                if candidates.isEmpty {
                    ContentUnavailableView(
                        "还没有候选房源",
                        systemImage: "house",
                        description: Text("添加第一套房源，开始统一整理成本、通勤和看房信息。")
                    )
                    .frame(minHeight: 360)
                } else {
                    ScrollView(.horizontal) {
                        LazyHStack(alignment: .top, spacing: 16) {
                            ForEach(candidates) { listing in
                                ListingCard(listing: listing, limitMessage: $limitMessage)
                                    .containerRelativeFrame(.horizontal, count: 1, span: 1, spacing: 32)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .contentMargins(.horizontal, 20, for: .scrollContent)
                    .scrollTargetBehavior(.viewAligned)
                    .scrollIndicators(.hidden)
                }

                if !eliminated.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("已淘汰")
                            .font(.title2.bold())
                        ForEach(eliminated) { listing in
                            NavigationLink(value: listing.id) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(listing.name).font(.headline)
                                        Text(listing.eliminationReason ?? "未填写原因")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.tertiary)
                                }
                                .padding()
                                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationDestination(for: UUID.self) { ListingDetailView(listingID: $0) }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("任务设置", systemImage: "slider.horizontal.3") { showingTaskSettings = true }
                    .labelStyle(.iconOnly)
            }
            ToolbarItem(placement: .primaryAction) {
                Button("添加房源", systemImage: "plus") { showingAdd = true }
                    .accessibilityIdentifier("addListingButton")
            }
        }
        .sheet(isPresented: $showingAdd) { ListingEditorView() }
        .alert("暂时无法加入对比", isPresented: Binding(
            get: { limitMessage != nil },
            set: { if !$0 { limitMessage = nil } }
        )) {
            Button("好", role: .cancel) { limitMessage = nil }
        } message: { Text(limitMessage ?? "") }
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("listingsScreen")
    }
}

private struct ListingCard: View {
    @Environment(AppStore.self) private var store
    let listing: Listing
    @Binding var limitMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack(alignment: .topTrailing) {
                ListingImageView(listing: listing)
                    .frame(height: 260)
                if listing.focused {
                    StatusPill(text: "重点", systemImage: "star.fill", color: .orange)
                        .padding(12)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                Text(listing.name).font(.title2.bold()).lineLimit(2)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(listing.rent.formattedMoney(currency: listing.currency)).font(.title.bold())
                    Text("/ 月").foregroundStyle(.secondary)
                }
                Label {
                    Text("\(listing.commuteMode?.title ?? "方式待补充") · \(listing.commuteMinutes.map(String.init) ?? "未知") 分钟")
                } icon: {
                    Image(systemName: listing.commuteMode?.symbol ?? "clock")
                }
                Label("\(listing.roomDescription)  \(areaText)", systemImage: "house")
                if let floor = listing.floor { Label("楼层 \(floor)", systemImage: "building.2") }
                if !DecisionEngine.calculateCosts(for: listing, expectedMonths: store.task.expectedMonths).unknowns.isEmpty {
                    StatusPill(text: "费用待确认", systemImage: "exclamationmark.circle", color: .orange)
                }
                HStack {
                    Button(store.task.comparisonIDs.contains(listing.id) ? "已加入对比" : "加入对比") {
                        if !store.toggleComparison(listing.id) { limitMessage = "一次最多比较 5 套候选房源。" }
                    }
                    .buttonStyle(.bordered)
                    .disabled(store.task.comparisonIDs.contains(listing.id))
                    NavigationLink("查看详情", value: listing.id)
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding([.horizontal, .bottom])
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 20, y: 8)
        .padding(.vertical, 4)
        .accessibilityIdentifier("listingCard_\(listing.id.uuidString)")
    }

    private var areaText: String {
        guard let area = listing.area else { return "面积待补充" }
        return "\(area.formatted(.number.precision(.fractionLength(0...1)))) ㎡ \(listing.areaScope ?? "")"
    }
}

struct ListingDetailView: View {
    @Environment(AppStore.self) private var store
    let listingID: UUID
    @State private var showingEdit = false
    @State private var showingEliminate = false
    @State private var eliminationReason = ""

    private var listing: Listing? { store.task.listings.first { $0.id == listingID } }

    var body: some View {
        Group {
            if let listing {
                List {
                    ListingImageView(listing: listing)
                        .frame(height: 240)
                        .listRowInsets(EdgeInsets())
                    Section("概览") {
                        LabeledContent("月租", value: listing.rent.formattedMoney(currency: listing.currency))
                        LabeledContent("租赁方式", value: listing.roomDescription)
                        LabeledContent("面积", value: listing.area.map { "\($0.formatted()) ㎡ · \(listing.areaScope ?? "范围待补充")" } ?? "待补充")
                        LabeledContent("楼层", value: listing.floor ?? "待补充")
                        LabeledContent("地址", value: listing.address ?? "待补充")
                    }
                    Section("决策") {
                        Toggle("重点考虑", isOn: Binding(
                            get: { listing.focused },
                            set: { _ in store.toggleFocus(listing.id) }
                        ))
                        Toggle("加入本次对比", isOn: Binding(
                            get: { store.task.comparisonIDs.contains(listing.id) },
                            set: { _ in _ = store.toggleComparison(listing.id) }
                        ))
                        .disabled(listing.status == .eliminated)
                        NavigationLink("看房检查") { InspectionView(listingID: listing.id) }
                    }
                    Section {
                        Button(listing.status == .candidate ? "淘汰这套房源" : "恢复到候选池", role: listing.status == .candidate ? .destructive : nil) {
                            if listing.status == .candidate { showingEliminate = true } else { store.toggleEliminated(listing.id) }
                        }
                    }
                }
                .navigationTitle(listing.name)
                .toolbar { Button("编辑") { showingEdit = true } }
                .sheet(isPresented: $showingEdit) { ListingEditorView(existing: listing) }
                .alert("淘汰这套房源？", isPresented: $showingEliminate) {
                    TextField("原因（可选）", text: $eliminationReason)
                    Button("取消", role: .cancel) {}
                    Button("淘汰", role: .destructive) { store.toggleEliminated(listing.id, reason: eliminationReason) }
                } message: { Text("房源会退出当前对比，但可以随时恢复。") }
            } else {
                ContentUnavailableView("房源不存在", systemImage: "house.slash")
            }
        }
    }
}
