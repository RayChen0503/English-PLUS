import Foundation

enum PrivacyConsentCategory: String, CaseIterable, Identifiable, Codable {
    case identity
    case schoolContext
    case learningRecords
    case moodCheckIn
    case supportThreads
    case aiAssistance
    case volunteerEvidence

    var id: String { rawValue }
}

enum GuardianConsentStatus: String, Codable {
    case required
    case received
    case schoolApproved
    case notRequired
    case notRequiredForDemo
}

enum ConsentSource: String, Codable {
    case inAppCheckbox
    case schoolImport
    case adminReview
}

struct PrivacyConsentRecord: Identifiable, Codable, Equatable {
    static let currentVersion = "privacy-v3-2026-07-16"

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
    let studentAccessPath: StudentAccountAccessPath
    let policyUrl: String
    let categoriesAccepted: [PrivacyConsentCategory]

    static func accepted(
        uid: String,
        role: UserRole,
        classId: String,
        categories: [PrivacyConsentCategory],
        guardianConsentStatus: GuardianConsentStatus,
        studentAccessPath: StudentAccountAccessPath? = nil,
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
            schoolApprovalRef: "",
            guardianConsentStatus: guardianConsentStatus,
            studentAccessPath: studentAccessPath
                ?? (role == .student ? .legacyUnspecified : .notApplicable),
            policyUrl: LegalSupportConfiguration.privacyPolicyURL.absoluteString,
            categoriesAccepted: categories
        )
    }
}

enum LegalSupportConfiguration {
    static let policyEffectiveDate = "2026 年 7 月 16 日"
    static let supportEmail = "englishplus.tw@gmail.com"

    static let privacyPolicyURL = publicPageURL(pathComponent: "隱私政策")
    static let supportURL = publicPageURL(pathComponent: "支援與聯絡")

    static func supportEmailURL(role: UserRole? = nil) -> URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        let roleContext = role.map { "（\($0.title)端）" } ?? ""
        components.queryItems = [
            URLQueryItem(name: "subject", value: "English+ 使用協助\(roleContext)")
        ]
        return components.url ?? URL(fileURLWithPath: "/")
    }

    private static func publicPageURL(pathComponent: String) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "sites.google.com"
        components.path = "/view/englishplus-privacy/\(pathComponent)"
        return components.url ?? URL(fileURLWithPath: "/")
    }
}

enum PrivacyPolicyCopy {
    static func primaryAgreement(for role: UserRole) -> String {
        switch role {
        case .student:
            return "我同意 English+ 保存帳號、作答、學習進度、心情檢測、班級任務，以及我主動送出的求助內容，用來提供個人學習與真人回覆。"
        case .teacher:
            return "我同意 English+ 保存帳號、教育機構、班級、指派任務與回覆紀錄，用來管理我建立的班級及回應學生主動送出的求助。"
        case .volunteer:
            return "我同意 English+ 保存帳號、志工申請、資格證明與回覆紀錄，用來完成審核並在核准後處理獲授權的學生求助。"
        }
    }

    static func aiAgreement(for role: UserRole) -> String {
        switch role {
        case .student:
            return "我同意把完成該次功能所需的最少學習內容，經 English+ 的 Cloudflare 後端傳送給 Groq AI，以產生每日任務、錯題說明與學習建議。姓名、Email 與志工證明不會放進 AI 提示。"
        case .teacher, .volunteer:
            return "我同意把完成該次功能所需的最少題目與學習情境，經 English+ 的 Cloudflare 後端傳送給 Groq AI，以產生可自行修改的回覆草稿與摘要。AI 不會自動替我送出內容。"
        }
    }

    static func requiredCategories(for role: UserRole) -> [PrivacyConsentCategory] {
        switch role {
        case .student:
            return [.identity, .schoolContext, .learningRecords, .moodCheckIn, .supportThreads, .aiAssistance]
        case .teacher:
            return [.identity, .schoolContext, .learningRecords, .supportThreads, .aiAssistance]
        case .volunteer:
            return [.identity, .supportThreads, .aiAssistance, .volunteerEvidence]
        }
    }

    static let guardianAgreement = "我確認自己已滿 13 歲。未滿 13 歲者需要由學校或監護人協助建立受管理帳號，不能以公開註冊入口自行建立帳號。"
    static let aiAccuracyNotice = "AI 內容可能不完全正確；請先確認再採用。English+ 不會只因心情分數自動通知老師、志工或緊急單位。"
    static let refusalPath = "你可以先閱讀完整政策或離開此頁；未同意前，English+ 不會開始保存新的學習與支持資料。"
}
