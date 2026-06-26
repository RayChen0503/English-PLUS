import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

enum FirebaseFirestoreServiceError: Error, Equatable {
    case firebaseSDKUnavailable
    case notConfigured
    case permissionDenied
}

final class FirebaseFirestoreService: FirestoreService {
    private let fallback: MockFirestoreService
    private var cachedConsentRecords: [String: PrivacyConsentRecord] = [:]

    #if canImport(FirebaseFirestore)
    private let db: Firestore?
    private var consentListeners: [String: ListenerRegistration] = [:]
    #endif

    init(fallback: MockFirestoreService = MockFirestoreService()) {
        self.fallback = fallback
        #if canImport(FirebaseFirestore)
        db = FirebaseAppConfigurator.hasBundledConfig ? Firestore.firestore() : nil
        #endif
    }

    func hasAcceptedRequiredConsent(uid: String) -> Bool {
        if let cached = cachedConsentRecords[uid] {
            return cached.accepted && cached.version == PrivacyConsentRecord.currentVersion
        }
        return fallback.hasAcceptedRequiredConsent(uid: uid)
    }

    func saveConsent(_ record: PrivacyConsentRecord) {
        cachedConsentRecords[record.acceptedByUid] = record
        fallback.saveConsent(record)

        #if canImport(FirebaseFirestore)
        guard let db else { return }
        let userPath = FirestorePath.userConsent(
            uid: record.acceptedByUid,
            consentVersion: record.version
        )
        let studentPath = FirestorePath.studentConsent(
            classId: record.classId,
            studentUid: record.acceptedByUid,
            consentVersion: record.version
        )
        let data = firestoreConsentData(from: record)
        db.document(userPath).setData(data, merge: true)
        db.document(studentPath).setData(data, merge: true)
        #endif
    }

    func consentRecord(uid: String) -> PrivacyConsentRecord? {
        cachedConsentRecords[uid] ?? fallback.consentRecord(uid: uid)
    }

    func startConsentListener(uid: String) -> FirestoreServiceListenerToken {
        #if canImport(FirebaseFirestore)
        guard let db else {
            return AnyFirestoreServiceListenerToken {}
        }

        let path = FirestorePath.userConsent(
            uid: uid,
            consentVersion: PrivacyConsentRecord.currentVersion
        )
        let registration = db.document(path).addSnapshotListener { [weak self] snapshot, error in
            guard error == nil,
                  let data = snapshot?.data(),
                  let record = PrivacyConsentRecord.firestoreRecord(
                    uid: uid,
                    data: data
                  )
            else { return }
            self?.cachedConsentRecords[uid] = record
        }
        consentListeners[uid] = registration
        return AnyFirestoreServiceListenerToken {
            registration.remove()
        }
        #else
        return AnyFirestoreServiceListenerToken {}
        #endif
    }

    #if canImport(FirebaseFirestore)
    private func firestoreConsentData(from record: PrivacyConsentRecord) -> [String: Any] {
        [
            "version": record.version,
            "accepted": record.accepted,
            "acceptedAt": record.acceptedAt,
            "acceptedByUid": record.acceptedByUid,
            "actorRole": record.actorRole.rawValue,
            "classId": record.classId,
            "consentSource": record.consentSource.rawValue,
            "schoolApprovalRef": record.schoolApprovalRef,
            "guardianConsentStatus": record.guardianConsentStatus.rawValue,
            "policyUrl": record.policyUrl,
            "categoriesAccepted": record.categoriesAccepted.map(\.rawValue),
        ]
    }
    #endif
}

protocol FirestoreServiceListenerToken {
    func cancel()
}

final class AnyFirestoreServiceListenerToken: FirestoreServiceListenerToken {
    private let onCancel: () -> Void

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    func cancel() {
        onCancel()
    }
}

private extension PrivacyConsentRecord {
    static func firestoreRecord(uid: String, data: [String: Any]) -> PrivacyConsentRecord? {
        guard
            let version = data["version"] as? String,
            let accepted = data["accepted"] as? Bool,
            let actorRoleRaw = data["actorRole"] as? String,
            let actorRole = UserRole(rawValue: actorRoleRaw),
            let sourceRaw = data["consentSource"] as? String,
            let source = ConsentSource(rawValue: sourceRaw),
            let guardianRaw = data["guardianConsentStatus"] as? String,
            let guardian = GuardianConsentStatus(rawValue: guardianRaw),
            let policyUrl = data["policyUrl"] as? String
        else {
            return nil
        }

        let categories = (data["categoriesAccepted"] as? [String] ?? [])
            .compactMap(PrivacyConsentCategory.init(rawValue:))
        let acceptedAt = data["acceptedAt"] as? Date ?? Date()

        return PrivacyConsentRecord(
            id: version,
            version: version,
            accepted: accepted,
            acceptedAt: acceptedAt,
            acceptedByUid: uid,
            actorRole: actorRole,
            classId: data["classId"] as? String ?? FirebaseBackendConfig.firstClassId,
            consentSource: source,
            schoolApprovalRef: data["schoolApprovalRef"] as? String ?? "",
            guardianConsentStatus: guardian,
            policyUrl: policyUrl,
            categoriesAccepted: categories
        )
    }
}
