import Foundation

indirect enum LearningMirrorValue: Codable, Equatable {
    case text(String), integer(Int), number(Double), flag(Bool), date(Date), null
    case array([LearningMirrorValue]), object([String: LearningMirrorValue])

    init(_ value: Any) throws {
        switch value {
        case let value as Date: self = .date(value)
        case is NSNull: self = .null
        case let value as String: self = .text(value)
        case let value as Bool: self = .flag(value)
        case let value as Int: self = .integer(value)
        case let value as Double where value.isFinite: self = .number(value)
        case let value as [Any]: self = .array(try value.map(LearningMirrorValue.init))
        case let value as [String: Any]: self = .object(try value.mapValues(LearningMirrorValue.init))
        default: throw CocoaError(.coderInvalidValue)
        }
    }

    var value: Any {
        switch self {
        case .text(let value): return value
        case .integer(let value): return value
        case .number(let value): return value
        case .flag(let value): return value
        case .date(let value): return value
        case .null: return NSNull()
        case .array(let values): return values.map(\.value)
        case .object(let values): return values.mapValues(\.value)
        }
    }
}

struct LearningMirrorDocument: Codable, Equatable {
    let path: String
    let fields: [String: LearningMirrorValue]
    let requiresExistingDocument: Bool
    let masteryMutation: LearningMasteryMutation?

    init(path: String, data: [String: Any], requiresExistingDocument: Bool = false, masteryMutation: LearningMasteryMutation? = nil) throws {
        self.path = path
        self.requiresExistingDocument = requiresExistingDocument
        self.masteryMutation = masteryMutation
        fields = try data.mapValues(LearningMirrorValue.init)
    }

    var data: [String: Any] { fields.mapValues(\.value) }
}

struct LearningMirrorBatch: Codable, Equatable, Identifiable {
    let id: UUID
    var documents: [LearningMirrorDocument]
    var createdAt: Date = Date()

    var receiptData: [String: Any] {
        ["operationId": id.uuidString, "createdAt": createdAt]
    }
}

@MainActor
final class LearningMirrorWriteQueue {
    private struct State: Codable {
        var batches: [LearningMirrorBatch] = []
        var failed = false
    }

    private let defaults: UserDefaults
    private let prefix = "englishplus.learning.pendingWrites.v1."
    private var states: [String: State] = [:]

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    static func scope(uid: String, classId: String?) -> String {
        Data(uid.utf8).base64EncodedString() + ":" + Data((classId ?? "personal").utf8).base64EncodedString()
    }

    static func belongs(_ scope: String, to uid: String) -> Bool {
        guard let owner = scope.split(separator: ":", omittingEmptySubsequences: false).first,
              let data = Data(base64Encoded: String(owner)) else { return false }
        return String(data: data, encoding: .utf8) == uid
    }

    func batches(scope: String) -> [LearningMirrorBatch] { state(scope).batches }
    func hasFailure(scope: String) -> Bool { state(scope).failed }

    func append(_ documents: [LearningMirrorDocument], scope: String) {
        guard !documents.isEmpty else { return }
        var current = state(scope)
        current.batches.append(LearningMirrorBatch(id: UUID(), documents: documents))
        store(current, scope: scope)
    }

    func fail(id: UUID, scope: String) {
        var current = state(scope)
        guard current.batches.first?.id == id else { return }
        current.failed = true
        store(current, scope: scope)
    }

    func acknowledge(id: UUID, scope: String) {
        var current = state(scope)
        guard current.batches.first?.id == id else { return }
        current.batches.removeFirst()
        current.failed = false
        store(current, scope: scope)
    }

    func retry(scope: String) {
        var current = state(scope)
        current.failed = false
        store(current, scope: scope)
    }

    @discardableResult
    func replaceHead(_ batch: LearningMirrorBatch, scope: String) -> Bool {
        var current = state(scope)
        guard current.batches.first?.id == batch.id else { return false }
        current.batches[0] = batch
        current.failed = false
        store(current, scope: scope)
        return true
    }

    func clear(uid: String) {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            let scope = String(key.dropFirst(prefix.count))
            if Self.belongs(scope, to: uid) { defaults.removeObject(forKey: key) }
        }
        states = states.filter { !Self.belongs($0.key, to: uid) }
    }

    private func state(_ scope: String) -> State {
        if let cached = states[scope] { return cached }
        let restored = defaults.data(forKey: prefix + scope).flatMap {
            try? JSONDecoder().decode(State.self, from: $0)
        } ?? State()
        states[scope] = restored
        return restored
    }

    private func store(_ state: State, scope: String) {
        states[scope] = state
        if state.batches.isEmpty {
            defaults.removeObject(forKey: prefix + scope)
        } else {
            do {
                defaults.set(try JSONEncoder().encode(state), forKey: prefix + scope)
            } catch {
                // Keep the operation visible and retryable instead of discarding it.
                states[scope]?.failed = true
            }
        }
    }
}

struct LearningMasteryMutation: Codable, Equatable {
    let studentUid: String
    let item: QuestionBankItem
    let isCorrect: Bool
    let firstTryCorrect: Bool
    let source: LearningAttemptSource
    let answeredAt: Date

    func rebased(over current: SkillMasteryRecord) -> SkillMasteryRecord? {
        guard current.studentUid == studentUid, current.curriculumKey == item.curriculumKey else { return nil }
        let projectionDate = max(answeredAt, current.updatedAt.addingTimeInterval(0.001))
        return SpacedRepetitionEngine.recording(
            existing: current, studentUid: studentUid, item: item,
            isCorrect: isCorrect, firstTryCorrect: firstTryCorrect,
            source: source, at: projectionDate
        )
    }
}
