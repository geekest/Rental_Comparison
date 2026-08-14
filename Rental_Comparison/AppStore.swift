import Foundation
import Observation

@MainActor
@Observable
final class AppStore {
    private(set) var state: AppState
    private(set) var saveError: String?
    let persistence: PersistenceClient

    init(persistence: PersistenceClient = .live, useFixtures: Bool = ProcessInfo.processInfo.arguments.contains("-uiTesting")) {
        self.persistence = persistence
        if useFixtures {
            state = Fixtures.initialState
            state.privacyAcknowledged = true
        } else {
            state = (try? persistence.load()) ?? Fixtures.initialState
        }
    }

    var task: RentalTask { state.task }
    var candidateListings: [Listing] { task.listings.filter { $0.status == .candidate } }
    var comparisonListings: [Listing] { DecisionEngine.comparisonListings(in: task) }

    func acceptPrivacy() {
        state.privacyAcknowledged = true
        persist()
    }

    func updateTask(_ change: (inout RentalTask) -> Void) {
        change(&state.task)
        DecisionEngine.normalize(&state.task)
        persist()
    }

    func upsert(_ listing: Listing) {
        updateTask { task in
            if let index = task.listings.firstIndex(where: { $0.id == listing.id }) {
                task.listings[index] = listing
            } else {
                task.listings.append(listing)
            }
        }
    }

    func toggleComparison(_ id: UUID) -> Bool {
        guard let listing = task.listings.first(where: { $0.id == id }), listing.status == .candidate else { return false }
        if task.comparisonIDs.contains(id) {
            updateTask { $0.comparisonIDs.removeAll { $0 == id } }
            return true
        }
        guard task.comparisonIDs.count < 5 else { return false }
        updateTask { $0.comparisonIDs.append(id) }
        return true
    }

    func toggleFocus(_ id: UUID) {
        updateTask { task in
            guard let index = task.listings.firstIndex(where: { $0.id == id }) else { return }
            task.listings[index].focused.toggle()
            task.events.append(.init(type: task.listings[index].focused ? .focused : .unfocused, listingID: id))
        }
    }

    func toggleEliminated(_ id: UUID, reason: String? = nil) {
        updateTask { task in
            guard let index = task.listings.firstIndex(where: { $0.id == id }) else { return }
            let eliminating = task.listings[index].status == .candidate
            task.listings[index].status = eliminating ? .eliminated : .candidate
            task.listings[index].focused = false
            task.listings[index].eliminationReason = eliminating ? reason?.nilIfBlank : nil
            task.events.append(.init(type: eliminating ? .eliminated : .restored, listingID: id, reason: reason?.nilIfBlank))
        }
    }

    func confirmFinal(_ id: UUID, reason: String) {
        updateTask { task in
            task.finalListingID = id
            task.finalReason = reason.nilIfBlank
            task.completed = true
            task.events.append(.init(type: .confirmed, listingID: id, reason: reason.nilIfBlank))
        }
    }

    func withdrawFinal() {
        guard let id = task.finalListingID else { return }
        updateTask { task in
            task.finalListingID = nil
            task.finalReason = nil
            task.completed = false
            task.events.append(.init(type: .withdrawn, listingID: id))
        }
    }

    func resetToFixtures() {
        state = Fixtures.initialState
        persist()
    }

    func clearSaveError() {
        saveError = nil
    }

    private func persist() {
        do {
            try persistence.save(state)
            saveError = nil
        } catch {
            saveError = "保存失败：\(error.localizedDescription)"
        }
    }
}

struct PersistenceClient {
    var load: () throws -> AppState?
    var save: (AppState) throws -> Void

    static let live = PersistenceClient(
        load: {
            let url = try stateURL()
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(AppState.self, from: Data(contentsOf: url))
        },
        save: { state in
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(state).write(to: try stateURL(), options: .atomic)
        }
    )

    static func stateURL() throws -> URL {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appending(path: "RentalComparison", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "state-v1.json")
    }

    static func saveMedia(_ data: Data) throws -> String {
        let id = UUID().uuidString
        let mediaDirectory = try stateURL().deletingLastPathComponent().appending(path: "Media", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)
        try data.write(to: mediaDirectory.appending(path: "\(id).jpg"), options: .atomic)
        return id
    }

    static func mediaURL(for id: String) -> URL? {
        try? stateURL().deletingLastPathComponent().appending(path: "Media/\(id).jpg")
    }

    static func deleteMedia(_ ids: [String]) {
        for id in ids {
            guard let url = mediaURL(for: id) else { continue }
            try? FileManager.default.removeItem(at: url)
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
