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
            return "單字選擇"
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
}

struct Question: Identifiable, Codable, Equatable {
    let id: String
    let type: QuestionType
    let prompt: String
    let difficulty: String
}
