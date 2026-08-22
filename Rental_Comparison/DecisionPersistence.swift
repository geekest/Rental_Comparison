import Foundation

struct DecisionPersistenceClient {
    var loadV2: () throws -> DecisionAppState?
    var loadV1: () throws -> AppState?
    var saveV2: (DecisionAppState) throws -> Void
    var loadWorkspace: () throws -> DecisionWorkspace? = { nil }
    var saveWorkspace: (DecisionWorkspace) throws -> Void = { _ in }

    static let live = DecisionPersistenceClient(
        loadV2: { try load(DecisionAppState.self, from: stateV2URL()) },
        loadV1: { try load(AppState.self, from: PersistenceClient.stateURL()) },
        saveV2: { state in
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(state).write(to: try stateV2URL(), options: .atomic)
        },
        loadWorkspace: { try load(DecisionWorkspace.self, from: workspaceURL()) },
        saveWorkspace: { workspace in
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(workspace).write(to: try workspaceURL(), options: .atomic)
        }
    )

    static func loadOrMigrate(using client: DecisionPersistenceClient = .live, now: Date = .now) throws -> DecisionLoadResult? {
        if let v2 = try client.loadV2() {
            return .init(state: v2, source: .v2)
        }
        guard let v1 = try client.loadV1() else { return nil }
        let migrated = DecisionModelMigration.migrate(v1, now: now)
        do {
            try client.saveV2(migrated)
            return .init(state: migrated, source: .migratedV1)
        } catch {
            return .init(state: migrated, source: .v1Fallback(error.localizedDescription))
        }
    }

    static func stateV2URL() throws -> URL {
        try PersistenceClient.stateURL().deletingLastPathComponent().appending(path: "state-v2.json")
    }

    static func workspaceURL() throws -> URL {
        try PersistenceClient.stateURL().deletingLastPathComponent().appending(path: "decision-workspace-v1.json")
    }

    private static func load<T: Decodable>(_ type: T.Type, from url: URL) throws -> T? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: Data(contentsOf: url))
    }
}
struct DecisionLoadResult {
    enum Source: Equatable {
        case v2
        case migratedV1
        case v1Fallback(String)
    }

    var state: DecisionAppState
    var source: Source
}
