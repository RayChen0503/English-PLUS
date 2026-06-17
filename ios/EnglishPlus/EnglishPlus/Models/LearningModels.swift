import Foundation

struct MoodCheckIn: Identifiable, Equatable {
    let id: String
    let studentUid: String
    let dateKey: String
    let moodScore: Int
    let availableTimeLevel: Int
    let wantsChallenge: Bool
    let preferredQuestionTypes: [QuestionType]
    let recommendedMinutes: Int
    let createdAt: Date
}

struct DailyMission: Identifiable, Equatable {
    let id: String
    let studentUid: String
    let dateKey: String
    let sourceCheckInId: String
    let track: MissionTrack
    let targetCorrectCount: Int
    let recommendedMinutes: Int
    let questions: [QuestionBankItem]
    let createdAt: Date
    var completedAt: Date?

    var status: MissionStatus {
        completedAt == nil ? .active : .completed
    }
}

struct MissionAttempt: Identifiable, Equatable {
    let id: String
    let missionId: String
    let questionId: String
    let prompt: String
    let selectedAnswer: String
    let acceptedAnswer: String
    let isCorrect: Bool
    let attemptNumber: Int
    let explanation: String
    let repairHint: String
    let createdAt: Date
}

struct StudentProgressSnapshot: Equatable {
    let correctCount: Int
    let targetCorrectCount: Int
    let status: MissionStatus

    var progressFraction: Double {
        guard targetCorrectCount > 0 else { return 0 }
        return min(Double(correctCount) / Double(targetCorrectCount), 1)
    }

    var progressText: String {
        "答對 \(correctCount) / \(targetCorrectCount)"
    }
}

struct StudentSupportRequest: Identifiable, Equatable {
    let id: String
    let studentUid: String
    let studentName: String
    let classCode: String
    let reason: SupportReason
    let route: SupportRoute
    var priority: RiskLevel
    var status: SupportThreadStatus
    var studentMessage: String
    var moodScore: Int?
    var latestQuestionId: String?
    let createdAt: Date
    var updatedAt: Date
    var replies: [SupportReply]
}

struct SupportReply: Identifiable, Equatable {
    let id: String
    let authorUid: String
    let authorName: String
    let authorRole: UserRole
    let body: String
    let visibleToStudent: Bool
    let createdAt: Date
}

struct StaffStudentSummary: Identifiable, Equatable {
    let id: String
    let studentUid: String
    let studentName: String
    let classCode: String
    let moodScore: Int?
    let riskLevel: RiskLevel
    let missionProgress: String
    let nextAction: String
}

extension QuestionType {
    var checkInLabel: String {
        title
    }
}

extension RiskLevel {
    var uiTitle: String {
        switch self {
        case .low:
            return "穩定"
        case .medium:
            return "留意"
        case .high:
            return "優先"
        }
    }
}

extension SupportThreadStatus {
    var uiTitle: String {
        switch self {
        case .open:
            return "已送出"
        case .waitingForStaff:
            return "待回應"
        case .replied:
            return "已有回覆"
        case .readByStudent:
            return "學生已讀"
        case .closed:
            return "已完成"
        }
    }
}

extension MissionTrack {
    var uiTitle: String {
        switch self {
        case .repair:
            return "修復任務"
        case .steady:
            return "穩定任務"
        case .challenge:
            return "挑戰任務"
        }
    }
}
