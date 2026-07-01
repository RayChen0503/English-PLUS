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
