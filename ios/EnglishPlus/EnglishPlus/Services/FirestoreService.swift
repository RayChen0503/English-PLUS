import Foundation

protocol FirestoreService {
    func hasAcceptedRequiredConsent(uid: String) -> Bool
    func loadConsentRecord(uid: String) async -> PrivacyConsentRecord?
    func saveConsent(_ record: PrivacyConsentRecord) async throws
    func consentRecord(uid: String) -> PrivacyConsentRecord?
}
