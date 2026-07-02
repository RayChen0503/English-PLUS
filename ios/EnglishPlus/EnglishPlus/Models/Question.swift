import Foundation

enum QuestionType: String, CaseIterable, Identifiable, Codable {
    case vocabulary
    case grammar
    case fillBlank
    case cloze
    case reading
    case translation
    case dialogue

    var id: String { rawValue }

    var title: String {
        switch self {
        case .vocabulary:
            return "單字"
        case .grammar:
            return "文法選擇"
        case .fillBlank:
            return "填空"
        case .cloze:
            return "克漏字"
        case .reading:
            return "閱讀理解"
        case .translation:
            return "翻譯 / 句子重組"
        case .dialogue:
            return "情境對話"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case "vocabulary", "單字":
            self = .vocabulary
        case "choice", "grammar", "multipleChoice", "文法", "文法選擇", "選擇":
            self = .grammar
        case "fillBlank", "fill_blank", "填空":
            self = .fillBlank
        case "cloze", "克漏字":
            self = .cloze
        case "reading", "閱讀", "閱讀理解":
            self = .reading
        case "translation", "翻譯", "翻譯/句子重組", "翻譯 / 句子重組":
            self = .translation
        case "dialogue", "對話", "情境對話":
            self = .dialogue
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown question type: \(value)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum QuestionLevel: String, CaseIterable, Identifiable, Codable {
    case a1 = "A1"
    case a2 = "A2"
    case b1 = "B1"
    case b2 = "B2"

    var id: String { rawValue }

    var uiTitle: String {
        switch self {
        case .a1:
            return "基礎"
        case .a2:
            return "穩定"
        case .b1:
            return "會考挑戰"
        case .b2:
            return "進階挑戰"
        }
    }
}

enum ReviewState: String, Codable {
    case draft
    case approved
    case archived
}

struct Question: Codable, Equatable {
    let prompt: String
    let type: QuestionType
    let options: [String]
    let answer: String
    let acceptedAnswers: [String]
    let explanation: String
    let concept: String
    let repairHint: String
}

struct QuestionBankSeed: SeedLoadable {
    static let seedFileName = "question_bank_seed"

    let questionBankSchemaVersion: Int
    let app: String
    let items: [QuestionBankItem]
}

struct QuestionBankItem: Identifiable, Codable, Equatable {
    let id: String
    let level: QuestionLevel
    let unit: String
    let skill: String
    let source: String
    let reviewState: ReviewState
    let importBatchId: String
    let updatedAt: Date
    let question: Question
}

struct QuestionPracticeSet: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let type: QuestionType
    let level: QuestionLevel
    let skill: String
    let items: [QuestionBankItem]

    var questionIds: [String] {
        items.map(\.id)
    }

    var questionCount: Int {
        items.count
    }

    var estimatedMinutes: Int {
        max(3, min(18, items.count * 2))
    }

    var previewText: String {
        items.first?.question.concept ?? skill
    }

    static func catalog(
        from items: [QuestionBankItem],
        maxQuestionsPerSet: Int = 12
    ) -> [QuestionPracticeSet] {
        let approved = items.filter { $0.reviewState == .approved }
        let grouped = Dictionary(grouping: approved) { item in
            PracticeSetGroupKey(
                type: item.question.type,
                level: item.level,
                skill: normalizedSkill(item.skill)
            )
        }

        let sortedGroups = grouped.sorted { lhs, rhs in
            if lhs.key.type.rawValue != rhs.key.type.rawValue {
                return lhs.key.type.rawValue < rhs.key.type.rawValue
            }
            if lhs.key.level.rawValue != rhs.key.level.rawValue {
                return lhs.key.level.rawValue < rhs.key.level.rawValue
            }
            return lhs.key.skill < rhs.key.skill
        }

        return sortedGroups.enumerated().flatMap { groupIndex, entry in
            entry.value
                .sorted { $0.id < $1.id }
                .chunked(size: max(1, maxQuestionsPerSet))
                .enumerated()
                .map { chunkIndex, chunk in
                    let first = chunk[0]
                    let skill = first.skill.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? first.question.concept
                        : first.skill
                    let setIndex = chunkIndex + 1
                    return QuestionPracticeSet(
                        id: "practice-set-\(groupIndex)-\(setIndex)",
                        title: "\(first.question.type.title) / \(skill)",
                        subtitle: "\(first.level.uiTitle) / \(chunk.count) 題 / 約 \(max(3, min(18, chunk.count * 2))) 分鐘",
                        type: first.question.type,
                        level: first.level,
                        skill: skill,
                        items: chunk
                    )
                }
        }
    }

    private static func normalizedSkill(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "general" : trimmed.lowercased()
    }
}

private struct PracticeSetGroupKey: Hashable {
    let type: QuestionType
    let level: QuestionLevel
    let skill: String
}

private extension Array {
    func chunked(size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map { start in
            Array(self[start..<Swift.min(start + size, count)])
        }
    }
}
