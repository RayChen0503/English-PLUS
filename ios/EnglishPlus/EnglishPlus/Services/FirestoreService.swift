import Foundation

protocol FirestoreService {
    func hasAcceptedRequiredConsent(uid: String) -> Bool
    func saveConsent(_ record: PrivacyConsentRecord)
    func consentRecord(uid: String) -> PrivacyConsentRecord?
}
