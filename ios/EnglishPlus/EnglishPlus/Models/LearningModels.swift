import Foundation

struct MoodCheckIn: Identifiable, Codable, Equatable {
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

struct DailyMission: Identifiable, Codable, Equatable {
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

struct MissionAttempt: Identifiable, Codable, Equatable {
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

struct StudentSupportRequest: Identifiable, Codable, Equatable {
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

struct SupportReply: Identifiable, Codable, Equatable {
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

struct StaffDashboardMetrics: Equatable {
    let studentCount: Int
    let highRiskCount: Int
    let waitingHelpCount: Int
    let repliedCount: Int
    let questionCount: Int
    let averageMoodText: String
}

struct VolunteerDashboardMetrics: Equatable {
    let waitingCount: Int
    let highPriorityCount: Int
    let repliedByVolunteerCount: Int
    let syncRecordCount: Int
}

struct QuestionBankTypeOverview: Identifiable, Equatable {
    let type: QuestionType
    let totalCount: Int
    let levelCounts: [QuestionLevel: Int]

    var id: String {
        type.id
    }

    var levelSummary: String {
        QuestionLevel.allCases
            .map { "\($0.uiTitle) \(levelCounts[$0, default: 0])" }
            .joined(separator: " · ")
    }
}

struct ClassroomReportExport: Equatable {
    let title: String
    let classCode: String
    let generatedAtText: String
    let metrics: [ClassroomReportMetric]
    let priorityStudents: [ClassroomReportStudentRow]
    let questionBankRows: [ClassroomReportQuestionBankRow]
    let recommendedActions: [String]

    var shareText: String {
        let metricLines = metrics.map { "- \($0.label): \($0.value) \($0.detail)" }
        let studentLines = priorityStudents.isEmpty
            ? ["- 目前沒有待回應學生。"]
            : priorityStudents.map { "- \($0.studentName): \($0.priorityText)｜\($0.summary)" }
        let questionLines = questionBankRows.map { "- \($0.typeTitle): \($0.totalCount) 題｜\($0.levelSummary)" }
        let actionLines = recommendedActions.map { "- \($0)" }

        return ([
            "# \(title)",
            "班級: \(classCode)",
            "產生時間: \(generatedAtText)",
            "",
            "## 班級狀態",
        ] + metricLines + [
            "",
            "## 優先學生",
        ] + studentLines + [
            "",
            "## 題庫狀態",
        ] + questionLines + [
            "",
            "## 建議下一步",
        ] + actionLines).joined(separator: "\n")
    }

    var htmlBody: String {
        """
        <html>
        <head>
          <meta charset="utf-8">
          <title>\(title)</title>
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; line-height: 1.6; color: #183047; padding: 24px; }
            h1 { color: #143B5B; }
            h2 { margin-top: 28px; color: #1D7D7A; }
            li { margin-bottom: 8px; }
          </style>
        </head>
        <body>
          <h1>\(title)</h1>
          <p>班級：\(classCode)<br>產生時間：\(generatedAtText)</p>
          <h2>班級狀態</h2>
          <ul>\(metrics.map { "<li>\($0.label): \($0.value) \($0.detail)</li>" }.joined())</ul>
          <h2>優先學生</h2>
          <ul>\(priorityStudents.isEmpty ? "<li>目前沒有待回應學生。</li>" : priorityStudents.map { "<li>\($0.studentName): \($0.priorityText)｜\($0.summary)</li>" }.joined())</ul>
          <h2>題庫狀態</h2>
          <ul>\(questionBankRows.map { "<li>\($0.typeTitle): \($0.totalCount) 題｜\($0.levelSummary)</li>" }.joined())</ul>
          <h2>建議下一步</h2>
          <ul>\(recommendedActions.map { "<li>\($0)</li>" }.joined())</ul>
        </body>
        </html>
        """
    }
}

struct ClassroomReportMetric: Identifiable, Equatable {
    let id: String
    let label: String
    let value: String
    let detail: String
}

struct ClassroomReportStudentRow: Identifiable, Equatable {
    let id: String
    let studentName: String
    let classCode: String
    let priorityText: String
    let statusText: String
    let summary: String
}

struct ClassroomReportQuestionBankRow: Identifiable, Equatable {
    let id: String
    let typeTitle: String
    let totalCount: Int
    let levelSummary: String
}

struct LocalLearningSnapshot: Codable, Equatable {
    let currentCheckIn: MoodCheckIn?
    let currentMission: DailyMission?
    let missionAttempts: [MissionAttempt]
    let supportRequests: [StudentSupportRequest]
    let savedAt: Date

    init(
        currentCheckIn: MoodCheckIn?,
        currentMission: DailyMission?,
        missionAttempts: [MissionAttempt],
        supportRequests: [StudentSupportRequest],
        savedAt: Date
    ) {
        self.currentCheckIn = currentCheckIn
        self.currentMission = currentMission
        self.missionAttempts = missionAttempts
        self.supportRequests = supportRequests
        self.savedAt = savedAt
    }

    init(snapshot: LearningRepositorySnapshot, savedAt: Date = Date()) {
        self.init(
            currentCheckIn: snapshot.currentCheckIn,
            currentMission: snapshot.currentMission,
            missionAttempts: snapshot.missionAttempts,
            supportRequests: snapshot.supportRequests,
            savedAt: savedAt
        )
    }

    var repositorySnapshot: LearningRepositorySnapshot {
        LearningRepositorySnapshot(
            currentCheckIn: currentCheckIn,
            currentMission: currentMission,
            missionAttempts: missionAttempts,
            supportRequests: supportRequests
        )
    }
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
