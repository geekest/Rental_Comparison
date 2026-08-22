import Foundation
import Observation

@MainActor
@Observable
final class AppStore {
    private(set) var state: DecisionAppState
    private(set) var saveError: String?
    let persistence: DecisionPersistenceClient
    private var taskStates: [DecisionAppState]
    private var currentTaskID: UUID
    private(set) var preferences: DecisionPreferences
    private(set) var pendingImportURL: URL?

    init(persistence: DecisionPersistenceClient = .live, useFixtures: Bool = ProcessInfo.processInfo.arguments.contains("-uiTesting")) {
        self.persistence = persistence
        saveError = nil
        pendingImportURL = nil
        var initialState: DecisionAppState
        var loadedStates: [DecisionAppState] = []
        var selectedTaskID: UUID?
        var loadedPreferences = DecisionPreferences()
        if useFixtures {
            initialState = DecisionModelMigration.migrate(Fixtures.initialState)
            initialState.privacyAcknowledged = true
        } else {
            do {
                if let loaded = try DecisionPersistenceClient.loadOrMigrate(using: persistence) {
                    initialState = loaded.state
                    if case let .v1Fallback(message) = loaded.source {
                        saveError = "已暂时读取旧数据，但升级保存失败：\(message)"
                    }
                } else {
                    initialState = DecisionModelMigration.migrate(Fixtures.initialState)
                }
                if let workspace = try persistence.loadWorkspace(), !workspace.tasks.isEmpty {
                    loadedStates = workspace.tasks
                    selectedTaskID = workspace.currentTaskID
                    loadedPreferences = workspace.preferences
                    initialState = workspace.tasks.first(where: { $0.hunt.id == workspace.currentTaskID }) ?? workspace.tasks[0]
                }
            } catch {
                initialState = DecisionModelMigration.migrate(Fixtures.initialState)
                saveError = "读取本地数据失败：\(error.localizedDescription)"
            }
        }
        let states = loadedStates.isEmpty ? [initialState] : loadedStates
        let selectedState = states.first(where: { $0.hunt.id == (selectedTaskID ?? initialState.hunt.id) }) ?? states[0]
        state = selectedState
        taskStates = states
        currentTaskID = selectedState.hunt.id
        preferences = loadedPreferences
        refreshDecisionSupport()
    }

    var task: RentalTask { DecisionLegacyProjection.task(from: state) }
    var candidateListings: [Listing] { task.listings.filter { $0.status == .candidate } }
    var comparisonListings: [Listing] { DecisionEngine.comparisonListings(in: task) }
    var tasks: [RentalTask] { taskStates.map(DecisionLegacyProjection.task(from:)) }

    func acceptPrivacy() {
        state.privacyAcknowledged = true
        persist()
    }

    func receiveSharedURL(_ url: URL) {
        pendingImportURL = url
    }

    func clearPendingImportURL() {
        pendingImportURL = nil
    }

    func createTask(title: String, city: String, destination: String, expectedMonths: Int) {
        let now = Date.now
        let taskID = UUID()
        let task = Hunt(
            id: taskID,
            title: title.nilIfBlank ?? "新的选房任务",
            regionTemplateID: state.hunt.regionTemplateID,
            city: city.nilIfBlank ?? "",
            defaultCurrency: preferences.defaultCurrency,
            expectedStayMonths: expectedMonths,
            primaryDestination: destination.nilIfBlank,
            optionIDs: [], criterionIDs: [], comparisonOptionIDs: [], baselineOptionID: nil,
            finalOptionID: nil, finalReason: nil, status: .active, createdAt: now, updatedAt: now
        )
        let newState = DecisionAppState(
            privacyAcknowledged: state.privacyAcknowledged,
            hunt: task,
            options: [], facts: [], evidence: [], criteria: [], unknowns: [], verificationTasks: [], events: []
        )
        taskStates.append(newState)
        state = newState
        currentTaskID = taskID
        persist()
    }

    func switchTask(to id: UUID) {
        guard let next = taskStates.first(where: { $0.hunt.id == id }) else { return }
        syncCurrentTask()
        state = next
        currentTaskID = id
        refreshDecisionSupport()
        persist()
    }

    func updatePreferences(_ change: (inout DecisionPreferences) -> Void) {
        change(&preferences)
        persist()
    }

    func deleteTask(_ id: UUID) {
        guard taskStates.count > 1 else { return }
        taskStates.removeAll { $0.hunt.id == id }
        if id == currentTaskID {
            state = taskStates[0]
            currentTaskID = state.hunt.id
        }
        persist()
    }

    func updateTask(_ change: (inout RentalTask) -> Void) {
        var legacyTask = task
        change(&legacyTask)
        DecisionEngine.normalize(&legacyTask)
        let migrated = DecisionModelMigration.migrate(.init(privacyAcknowledged: state.privacyAcknowledged, task: legacyTask))
        state = DecisionModelMigration.mergeLegacyUpdate(migrated, preserving: state)
        refreshDecisionSupport()
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

    @discardableResult
    func captureOption(name: String, monthlyRent: Double?, photoIDs: [String], mediaEvidenceType: EvidenceType = .photo) -> UUID {
        let now = Date.now
        let optionID = UUID()
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var facts: [Fact] = []
        if let monthlyRent, monthlyRent > 0 {
            facts.append(.init(
                id: UUID(),
                optionID: optionID,
                key: FactKey.monthlyRent,
                value: .decimal(monthlyRent),
                sourceType: .manual,
                sourceRef: nil,
                verificationState: .userConfirmed,
                evidenceIDs: [],
                capturedAt: now,
                updatedAt: now
            ))
        }
        let evidence = photoIDs.map {
            Evidence(id: UUID(), optionID: optionID, type: mediaEvidenceType, mediaID: $0, bundledAssetName: nil, text: nil, sourceURL: nil, capturedAt: now)
        }
        state.options.append(.init(
            id: optionID,
            huntID: state.hunt.id,
            displayName: normalizedName,
            searchStage: .saved,
            decisionState: .candidate,
            isFocused: false,
            eliminationReason: nil,
            sourceRefs: [],
            factIDs: facts.map(\.id),
            evidenceIDs: evidence.map(\.id),
            verificationTaskIDs: [],
            createdAt: now,
            updatedAt: now
        ))
        state.facts.append(contentsOf: facts)
        state.evidence.append(contentsOf: evidence)
        state.hunt.optionIDs.append(optionID)
        state.hunt.updatedAt = now
        state.events.append(.init(id: UUID(), type: .captured, optionID: optionID, at: now, reason: nil))
        refreshDecisionSupport(now: now)
        persist()
        return optionID
    }

    @discardableResult
    func captureImportedOption(draft: ListingImportDraft) -> UUID {
        let now = Date.now
        let optionID = UUID()
        let sourceURL = draft.sourceURL?.absoluteString
        var evidence: [Evidence] = []
        if let sourceURL {
            evidence.append(.init(
                id: UUID(), optionID: optionID, type: .listing, mediaID: nil,
                bundledAssetName: nil, text: draft.sourceDescription.nilIfBlank,
                sourceURL: sourceURL, capturedAt: now
            ))
        }
        evidence += draft.photoIDs.map {
            .init(
                id: UUID(), optionID: optionID,
                type: draft.sourceURL == nil ? .screenshot : .photo,
                mediaID: $0, bundledAssetName: nil, text: nil,
                sourceURL: sourceURL, capturedAt: now
            )
        }
        let evidenceIDs = evidence.map(\.id)
        var facts: [Fact] = []
        func append(_ key: String, _ value: FactValue) {
            facts.append(.init(
                id: UUID(), optionID: optionID, key: key, value: value,
                sourceType: draft.sourceType, sourceRef: sourceURL,
                verificationState: .userConfirmed, evidenceIDs: evidenceIDs,
                capturedAt: now, updatedAt: now
            ))
        }
        if let city = draft.city.nilIfBlank { append(FactKey.city, .text(city)) }
        if let monthlyRent = draft.monthlyRent, monthlyRent > 0 { append(FactKey.monthlyRent, .decimal(monthlyRent)) }
        append(FactKey.rentalType, .text(draft.rentalType.rawValue))
        if let address = draft.address?.nilIfBlank { append(FactKey.address, .text(address)) }
        if let area = draft.area { append(FactKey.area, .decimal(area)) }
        if let layout = draft.layout?.nilIfBlank { append(FactKey.layout, .text(layout)) }
        if let roomCount = draft.roomCount { append(FactKey.bedroomCount, .decimal(Double(roomCount))) }
        let option = Option(
            id: optionID, huntID: state.hunt.id, displayName: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
            searchStage: .saved, decisionState: .candidate, isFocused: false, eliminationReason: nil,
            sourceRefs: sourceURL.map { [$0] } ?? [], factIDs: facts.map(\.id), evidenceIDs: evidenceIDs,
            verificationTaskIDs: [], createdAt: now, updatedAt: now
        )
        state.options.append(option)
        state.facts.append(contentsOf: facts)
        state.evidence.append(contentsOf: evidence)
        state.hunt.optionIDs.append(optionID)
        state.hunt.updatedAt = now
        state.events.append(.init(id: UUID(), type: .captured, optionID: optionID, at: now, reason: draft.provider?.title))
        refreshDecisionSupport(now: now)
        persist()
        return optionID
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
        let now = Date.now
        state.hunt.finalOptionID = id
        state.hunt.finalReason = reason.nilIfBlank
        state.hunt.status = .completed
        state.hunt.updatedAt = now
        if let index = state.options.firstIndex(where: { $0.id == id }) {
            state.options[index].decisionState = .final
            state.options[index].updatedAt = now
        }
        state.events.append(.init(id: UUID(), type: .confirmed, optionID: id, at: now, reason: reason.nilIfBlank))
        persist()
    }

    func withdrawFinal() {
        guard let id = state.hunt.finalOptionID else { return }
        let now = Date.now
        state.hunt.finalOptionID = nil
        state.hunt.finalReason = nil
        state.hunt.status = .active
        state.hunt.updatedAt = now
        if let index = state.options.firstIndex(where: { $0.id == id }) {
            state.options[index].decisionState = .candidate
            state.options[index].updatedAt = now
        }
        state.events.append(.init(id: UUID(), type: .withdrawn, optionID: id, at: now, reason: nil))
        persist()
    }

    func resetToFixtures() {
        state = DecisionModelMigration.migrate(Fixtures.initialState)
        state.privacyAcknowledged = true
        taskStates = [state]
        currentTaskID = state.hunt.id
        refreshDecisionSupport()
        persist()
    }

    func clearSaveError() {
        saveError = nil
    }

    func completeVerificationTask(_ taskID: UUID, state taskState: VerificationTaskState, result: String?, photoIDs: [String]) {
        guard let index = state.verificationTasks.firstIndex(where: { $0.id == taskID }) else { return }
        let now = Date.now
        let normalizedResult = result?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
        let optionID = state.verificationTasks[index].optionID
        let photoEvidence = photoIDs.map {
            Evidence(id: UUID(), optionID: optionID, type: .photo, mediaID: $0, bundledAssetName: nil, text: nil, sourceURL: nil, capturedAt: now)
        }
        let noteEvidence: [Evidence] = normalizedResult.map {
            [Evidence(id: UUID(), optionID: optionID, type: .userObservation, mediaID: nil, bundledAssetName: nil, text: $0, sourceURL: nil, capturedAt: now)]
        } ?? []
        let evidence: [Evidence] = photoEvidence + noteEvidence
        state.evidence.append(contentsOf: evidence)
        state.verificationTasks[index].state = taskState
        state.verificationTasks[index].result = normalizedResult
        state.verificationTasks[index].evidenceIDs.append(contentsOf: evidence.map(\.id))
        let completedTask = state.verificationTasks[index]
        if let unknownID = state.verificationTasks[index].unknownID,
           taskState == .verified || taskState == .issue,
           let unknownIndex = state.unknowns.firstIndex(where: { $0.id == unknownID }) {
            state.unknowns[unknownIndex].status = .resolved
            state.unknowns[unknownIndex].resolvedAt = now
            recordObservation(for: completedTask, state: taskState, result: normalizedResult, evidenceIDs: evidence.map(\.id), at: now)
        }
        state.events.append(.init(id: UUID(), type: .verificationCompleted, optionID: optionID, at: now, reason: normalizedResult))
        refreshDecisionSupport(now: now)
        persist()
    }

    func createUnknown(optionID: UUID, reason: String, impactLevel: UnknownImpactLevel = .high) {
        let normalizedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedReason.isEmpty else { return }
        let factKey = userUnknownFactKey(for: normalizedReason)
        let semanticKey = factKey
            .replacingOccurrences(of: "system.", with: "")
            .replacingOccurrences(of: "user.", with: "")
        guard !state.unknowns.contains(where: {
            $0.optionID == optionID && $0.status == .open && $0.factKey
                .replacingOccurrences(of: "system.", with: "")
                .replacingOccurrences(of: "user.", with: "") == semanticKey
        }), !state.facts.contains(where: {
            $0.optionID == optionID && $0.key == semanticKey &&
                ($0.verificationState == .userConfirmed || $0.verificationState == .observed)
        }) else { return }
        let now = Date.now
        state.unknowns.append(.init(
            id: UUID(),
            optionID: optionID,
            factKey: factKey,
            impactLevel: impactLevel,
            reason: normalizedReason,
            status: .open,
            createdAt: now,
            resolvedAt: nil
        ))
        state.events.append(.init(id: UUID(), type: .unknownCreated, optionID: optionID, at: now, reason: normalizedReason))
        refreshDecisionSupport(now: now)
        persist()
    }

    private func refreshDecisionSupport(now: Date = .now) {
        UnknownEngine.refresh(in: &state, now: now)
        VerificationTaskEngine.sync(in: &state)
    }

    func setSearchStage(_ stage: SearchStage, for optionID: UUID) {
        guard let index = state.options.firstIndex(where: { $0.id == optionID }) else { return }
        state.options[index].searchStage = stage
        state.options[index].updatedAt = .now
        refreshDecisionSupport()
        persist()
    }

    private func userUnknownFactKey(for reason: String) -> String {
        if reason.contains("噪音") { return "user.\(FactKey.noise)" }
        return "user.\(reason)"
    }

    private func persist() {
        do {
            syncCurrentTask()
            try persistence.saveV2(state)
            try persistence.saveWorkspace(.init(currentTaskID: currentTaskID, tasks: taskStates, preferences: preferences))
            saveError = nil
        } catch {
            saveError = "保存失败：\(error.localizedDescription)"
        }
    }

    private func syncCurrentTask() {
        guard let index = taskStates.firstIndex(where: { $0.hunt.id == currentTaskID }) else {
            taskStates = [state]
            currentTaskID = state.hunt.id
            return
        }
        taskStates[index] = state
    }

    private func recordObservation(for task: VerificationTask, state taskState: VerificationTaskState, result: String?, evidenceIDs: [UUID], at now: Date) {
        guard task.type == .observe || task.unknownID.flatMap({ id in
            state.unknowns.first(where: { $0.id == id })?.factKey.hasPrefix("user.")
        }) == true else { return }
        let key = task.unknownID
            .flatMap { id in state.unknowns.first(where: { $0.id == id })?.factKey }
            .map { $0.replacingOccurrences(of: "system.", with: "").replacingOccurrences(of: "user.", with: "") }
            ?? "observation.\(task.id.uuidString)"
        let value = result?.nilIfBlank ?? (taskState == .issue ? "发现风险" : "已现场确认")
        if let factIndex = state.facts.firstIndex(where: { $0.optionID == task.optionID && $0.key == key }) {
            state.facts[factIndex].value = .text(value)
            state.facts[factIndex].sourceType = .userObservation
            state.facts[factIndex].verificationState = .observed
            state.facts[factIndex].evidenceIDs.append(contentsOf: evidenceIDs)
            state.facts[factIndex].updatedAt = now
        } else {
            let fact = Fact(
                id: UUID(), optionID: task.optionID, key: key, value: .text(value),
                sourceType: .userObservation, sourceRef: nil, verificationState: .observed,
                evidenceIDs: evidenceIDs, capturedAt: now, updatedAt: now
            )
            state.facts.append(fact)
            if let optionIndex = state.options.firstIndex(where: { $0.id == task.optionID }) {
                state.options[optionIndex].factIDs.append(fact.id)
                state.options[optionIndex].updatedAt = now
            }
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
