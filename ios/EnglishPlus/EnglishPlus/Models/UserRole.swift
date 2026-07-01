import Foundation

enum UserRole: String, CaseIterable, Identifiable, Codable {
    case student
    case teacher
    case volunteer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .student:
            return "學生"
        case .teacher:
            return "老師"
        case .volunteer:
            return "志工"
        }
    }

    var shortPurpose: String {
        switch self {
        case .student:
            return "先完成心情檢測，再進入今日任務與自由練習。"
        case .teacher:
            return "查看需要接力的學生，整理回饋與班級狀態。"
        case .volunteer:
            return "陪伴卡住的學生，提供鼓勵與練習建議。"
        }
    }
}
