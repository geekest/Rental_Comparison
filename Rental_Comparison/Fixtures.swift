import Foundation

enum Fixtures {
    static let xuhuiID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    static let jinganID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    static let putuoID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!

    static var initialState: AppState {
        var xuhui = Listing(
            id: xuhuiID,
            name: "徐汇 · 一室一厅",
            city: "上海",
            rentalType: .entire,
            rent: 7_800,
            focused: true,
            address: "徐汇区漕河泾附近",
            area: 48,
            areaScope: "整套",
            layout: "1 室 1 厅",
            floor: "8 / 18 层",
            roomCount: 1,
            commuteMinutes: 32,
            commuteFare: 6,
            commuteMode: .subway,
            bundledImageName: "xuhui",
            costs: [
                .init(name: "物业与网络", amount: 450, cadence: .monthly, refundable: false, confirmed: true),
                .init(name: "水电燃气预估", amount: 500, cadence: .monthly, refundable: false, confirmed: true),
                .init(name: "押金", amount: 7_800, cadence: .oneTime, refundable: true, confirmed: false),
                .init(name: "中介费", amount: 6_000, cadence: .oneTime, refundable: false, confirmed: true)
            ]
        )
        xuhui.conditionResults = ["budget": .met, "commute": .met, "sunlight": .met, "private": .met]

        var jingan = Listing(
            id: jinganID,
            name: "静安合租",
            city: "上海",
            rentalType: .shared,
            rent: 8_200,
            focused: true,
            address: "静安区南京西路附近",
            area: 18,
            areaScope: "私人空间",
            layout: "合租独立卧室",
            floor: "12 / 28 层",
            roomCount: 3,
            commuteMinutes: 14,
            commuteFare: 3,
            commuteMode: .walking,
            bundledImageName: "jingan",
            costs: [
                .init(name: "服务与网络", amount: 180, cadence: .monthly, refundable: false, confirmed: true),
                .init(name: "押金", amount: 8_200, cadence: .oneTime, refundable: true, confirmed: true)
            ]
        )
        jingan.conditionResults = ["budget": .met, "commute": .met, "sunlight": .unknown, "private": .met]
        jingan.inspections[1].state = .issue
        jingan.inspections[1].note = "临街，关窗后仍能听到车流声。"

        var putuo = Listing(
            id: putuoID,
            name: "普陀 · 开间",
            city: "上海",
            rentalType: .entire,
            rent: 6_900,
            area: 32,
            areaScope: "整套",
            layout: "开间",
            floor: "3 / 6 层",
            roomCount: 1,
            commuteMinutes: 46,
            commuteFare: 7,
            commuteMode: .driving,
            bundledImageName: "putuo",
            costs: [
                .init(name: "物业费", amount: 280, cadence: .monthly, refundable: false, confirmed: true),
                .init(name: "押金", cadence: .oneTime, refundable: true, confirmed: false)
            ]
        )
        putuo.conditionResults = ["budget": .met, "commute": .conflict, "sunlight": .met, "private": .met]

        return AppState(task: RentalTask(
            title: "上海租房计划",
            city: "上海",
            expectedMonths: 12,
            commuteDestination: "静安寺",
            listings: [xuhui, jingan, putuo],
            conditions: ConditionDefinition.defaults,
            comparisonIDs: [xuhuiID, jinganID],
            baselineID: xuhuiID
        ))
    }
}
