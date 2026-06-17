import Foundation

enum PrivacyConsentCategory: String, CaseIterable, Identifiable, Codable {
    case identity
    case schoolContext
    case learningRecords
    case moodCheckIn
    case supportThreads
    case aiAssistance

    var id: String { rawValue }
}

enum GuardianConsentStatus: String, Codable {
    case required
    case received
    case schoolApproved
    case notRequiredForDemo
}

enum ConsentSource: String, Codable {
    case inAppCheckbox
    case schoolImport
    case adminReview
}

struct PrivacyConsentRecord: Identifiable, Codable, Equatable {
    static let currentVersion = "privacy-v1-2026-06"

    let id: String
    let version: String
    let accepted: Bool
    let acceptedAt: Date
    let acceptedByUid: String
    let actorRole: UserRole
    let classId: String
    let consentSource: ConsentSource
    let schoolApprovalRef: String
    let guardianConsentStatus: GuardianConsentStatus
    let policyUrl: String
    let categoriesAccepted: [PrivacyConsentCategory]

    static func accepted(
        uid: String,
        role: UserRole,
        classId: String,
        categories: [PrivacyConsentCategory],
        acceptedAt: Date = Date()
    ) -> PrivacyConsentRecord {
        PrivacyConsentRecord(
            id: currentVersion,
            version: currentVersion,
            accepted: true,
            acceptedAt: acceptedAt,
            acceptedByUid: uid,
            actorRole: role,
            classId: classId,
            consentSource: .inAppCheckbox,
            schoolApprovalRef: "school-approval-required-before-real-pilot",
            guardianConsentStatus: .notRequiredForDemo,
            policyUrl: "https://example.edu/englishplus/privacy",
            categoriesAccepted: categories
        )
    }
}

enum PrivacyPolicyCopy {
    static let primaryAgreement = "我已了解 English+ 會使用我的姓名、班級/學校/年級、學習紀錄、心情檢測與求助紀錄，提供英文練習、老師/志工協助與 AI 學習建議。"
    static let moodAndAiAgreement = "我同意 English+ 使用我的心情檢測結果與作答狀況，幫我安排今日任務，並讓老師、志工與後台系統在需要時協助我。"
    static let refusalPath = "如果不同意，請告訴老師或專案負責人；你仍可以詢問是否有不記名或紙本練習方式。"
}
