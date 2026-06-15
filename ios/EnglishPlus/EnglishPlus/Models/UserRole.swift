import Foundation

enum UserRole: String, CaseIterable, Identifiable {
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
            return "完成今日任務，慢慢修復英文斷點"
        case .teacher:
            return "查看需要先接住的學生與待回應求助"
        case .volunteer:
            return "接力陪伴，給學生清楚鼓勵與支持"
        }
    }
}
