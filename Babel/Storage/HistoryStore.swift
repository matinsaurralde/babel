import Foundation
import SwiftData

@Model
final class Dictation {
    var id: UUID
    var createdAt: Date
    var modeRaw: String
    var engineName: String
    var rawTranscript: String
    var finalText: String
    var durationSeconds: Double
    var insertedIntoBundleID: String?

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        mode: BabelMode,
        engineName: String,
        rawTranscript: String,
        finalText: String,
        durationSeconds: Double,
        insertedIntoBundleID: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.modeRaw = mode.rawValue
        self.engineName = engineName
        self.rawTranscript = rawTranscript
        self.finalText = finalText
        self.durationSeconds = durationSeconds
        self.insertedIntoBundleID = insertedIntoBundleID
    }

    var mode: BabelMode {
        BabelMode(rawValue: modeRaw) ?? .fast
    }
}

@MainActor
enum HistoryStore {
    static let sharedContainer: ModelContainer = {
        do {
            let schema = Schema([Dictation.self])
            let config = ModelConfiguration("Babel", schema: schema)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // SwiftData setup failures on a clean install are almost always developer errors
            // (bad schema, corrupt file). Fail loudly in debug so we notice.
            fatalError("Babel: failed to build SwiftData container — \(error)")
        }
    }()

    static func save(_ dictation: Dictation) {
        let ctx = sharedContainer.mainContext
        ctx.insert(dictation)
        try? ctx.save()
    }
}
