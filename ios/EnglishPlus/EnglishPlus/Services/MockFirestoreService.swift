import Foundation

final class MockFirestoreService: FirestoreService {
    private var consentRecords: [String: PrivacyConsentRecord] = [:]

    func hasAcceptedRequiredConsent(uid: String) -> Bool {
        guard let record = consentRecords[uid] else {
            return false
        }
        return record.accepted && record.version == PrivacyConsentRecord.currentVersion
    }

    func loadConsentRecord(uid: String) async -> PrivacyConsentRecord? {
        consentRecord(uid: uid)
    }

    func saveConsent(_ record: PrivacyConsentRecord) {
        consentRecords[record.acceptedByUid] = record
    }

    func consentRecord(uid: String) -> PrivacyConsentRecord? {
        consentRecords[uid]
    }
}
