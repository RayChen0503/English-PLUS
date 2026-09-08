import Foundation

struct AccountDeletionTeacherCandidate: Decodable, Equatable, Identifiable {
    let uid: String
    let displayName: String

    var id: String { uid }
}

struct AccountDeletionOwnedClass: Decodable, Equatable, Identifiable {
    let classId: String
    let className: String
    let eligibleCoTeachers: [AccountDeletionTeacherCandidate]

    var id: String { classId }
    var requiresTransferSelection: Bool { !eligibleCoTeachers.isEmpty }
}

struct AccountDeletionPreview: Decodable, Equatable {
    let role: String
    let classMembershipCount: Int
    let ownedClassCount: Int
    let archivesOwnedClasses: Bool
    let transfersOwnedClasses: Bool
    let ownedClasses: [AccountDeletionOwnedClass]
    let removesIdentifiableData: Bool
    let retainsAnonymousAggregateOnly: Bool
    let requiresRecentSignIn: Bool
}

struct AccountDeletionReceipt: Decodable, Equatable {
    let completed: Bool
    let deletedDocuments: Int
    let redactedDocuments: Int
    let archivedOwnedClasses: Int
    let transferredOwnedClasses: Int
    let retainedData: String
}

enum AccountLifecycleError: LocalizedError, Equatable {
    case unavailable
    case unauthenticated
    case recentSignInRequired
    case policyChanged
    case classTransferSelectionRequired
    case classTransferSelectionStale
    case cleanupFailed
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "帳號管理目前無法使用，請稍後再試。"
        case .unauthenticated:
            return "登入已逾時，請重新登入後再操作。"
        case .recentSignInRequired:
            return "為了保護帳號，請先登出並重新登入，再回來刪除帳號。"
        case .policyChanged:
            return "資料刪除說明已更新，請重新閱讀後再確認。"
        case .classTransferSelectionRequired:
            return "請先為仍有共同教師的班級選擇接手老師，再繼續刪除帳號。"
        case .classTransferSelectionStale:
            return "班級接手資格剛剛有變動。請重新載入刪除影響並再次確認。"
        case .cleanupFailed:
            return "資料尚未完整刪除，系統沒有把操作標示成完成。請稍後重試。"
        case .invalidResponse:
            return "帳號管理服務回應不完整，請稍後再試。"
        }
    }
}

protocol AccountLifecycleService {
    func deletionPreview() async throws -> AccountDeletionPreview
    func deleteAccount(classTransfers: [String: String]) async throws -> AccountDeletionReceipt
}

struct UnavailableAccountLifecycleService: AccountLifecycleService {
    func deletionPreview() async throws -> AccountDeletionPreview {
        throw AccountLifecycleError.unavailable
    }

    func deleteAccount(classTransfers: [String: String]) async throws -> AccountDeletionReceipt {
        throw AccountLifecycleError.unavailable
    }
}

struct MockAccountLifecycleService: AccountLifecycleService {
    func deletionPreview() async throws -> AccountDeletionPreview {
        AccountDeletionPreview(
            role: "student",
            classMembershipCount: 0,
            ownedClassCount: 0,
            archivesOwnedClasses: false,
            transfersOwnedClasses: false,
            ownedClasses: [],
            removesIdentifiableData: true,
            retainsAnonymousAggregateOnly: true,
            requiresRecentSignIn: true
        )
    }

    func deleteAccount(classTransfers: [String: String]) async throws -> AccountDeletionReceipt {
        AccountDeletionReceipt(
            completed: true,
            deletedDocuments: 0,
            redactedDocuments: 0,
            archivedOwnedClasses: 0,
            transferredOwnedClasses: 0,
            retainedData: "anonymousAggregateOnly"
        )
    }
}

struct RemoteAccountLifecycleService: AccountLifecycleService {
    typealias IdTokenProvider = @Sendable () async throws -> String?

    private let baseURL: URL
    private let session: URLSession
    private let idTokenProvider: IdTokenProvider

    init(
        baseURL: URL,
        session: URLSession = .shared,
        idTokenProvider: @escaping IdTokenProvider
    ) {
        self.baseURL = baseURL
        self.session = session
        self.idTokenProvider = idTokenProvider
    }

    func deletionPreview() async throws -> AccountDeletionPreview {
        let token = try await currentToken()
        var request = URLRequest(
            url: baseURL
                .appendingPathComponent("account")
                .appendingPathComponent("deletion-preview")
        )
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        guard let preview = try? JSONDecoder().decode(PreviewEnvelope.self, from: data).preview else {
            throw AccountLifecycleError.invalidResponse
        }
        return preview
    }

    func deleteAccount(classTransfers: [String: String]) async throws -> AccountDeletionReceipt {
        let token = try await currentToken()
        let body = try JSONEncoder().encode(
            DeletionRequest(
                confirmation: "DELETE",
                policyVersion: "2026-07-13",
                classTransfers: classTransfers
            )
        )

        // Legacy support threads are cleaned in bounded Worker batches so a
        // large account stays below the Cloudflare subrequest limit.
        for _ in 0..<120 {
            var request = URLRequest(url: baseURL.appendingPathComponent("account"))
            request.httpMethod = "DELETE"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
            let (data, response) = try await session.data(for: request)
            try validate(response: response, data: data)
            guard let progress = try? JSONDecoder().decode(DeletionEnvelope.self, from: data).result else {
                throw AccountLifecycleError.invalidResponse
            }
            if progress.completed {
                guard
                    let deletedDocuments = progress.deletedDocuments,
                    let redactedDocuments = progress.redactedDocuments,
                    let archivedOwnedClasses = progress.archivedOwnedClasses,
                    let transferredOwnedClasses = progress.transferredOwnedClasses,
                    let retainedData = progress.retainedData
                else {
                    throw AccountLifecycleError.invalidResponse
                }
                return AccountDeletionReceipt(
                    completed: true,
                    deletedDocuments: deletedDocuments,
                    redactedDocuments: redactedDocuments,
                    archivedOwnedClasses: archivedOwnedClasses,
                    transferredOwnedClasses: transferredOwnedClasses,
                    retainedData: retainedData
                )
            }
            guard !Task.isCancelled else {
                throw CancellationError()
            }
            let retryDelay = pollingDelay(from: response)
            try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
        }
        throw AccountLifecycleError.cleanupFailed
    }

    private func pollingDelay(from response: URLResponse) -> TimeInterval {
        guard
            let httpResponse = response as? HTTPURLResponse,
            let rawValue = httpResponse.value(forHTTPHeaderField: "Retry-After"),
            let serverDelay = TimeInterval(rawValue)
        else {
            return 0.5
        }
        return min(max(serverDelay, 0.25), 2)
    }

    private func currentToken() async throws -> String {
        guard let token = try await idTokenProvider(), !token.isEmpty else {
            throw AccountLifecycleError.unauthenticated
        }
        return token
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AccountLifecycleError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let code = (try? JSONDecoder().decode(ErrorEnvelope.self, from: data).error) ?? ""
            switch code {
            case "AUTH_REQUIRED", "INVALID_TOKEN", "INVALID_TOKEN_CLAIMS":
                throw AccountLifecycleError.unauthenticated
            case "ACCOUNT_RECENT_SIGN_IN_REQUIRED":
                throw AccountLifecycleError.recentSignInRequired
            case "ACCOUNT_DELETION_POLICY_CHANGED":
                throw AccountLifecycleError.policyChanged
            case "ACCOUNT_CLASS_TRANSFER_SELECTION_REQUIRED":
                throw AccountLifecycleError.classTransferSelectionRequired
            case "ACCOUNT_CLASS_TRANSFER_SELECTION_STALE":
                throw AccountLifecycleError.classTransferSelectionStale
            case "ACCOUNT_AUTH_DELETION_FAILED", "FIRESTORE_COMMIT_FAILED", "FIRESTORE_QUERY_FAILED", "ACCOUNT_EVIDENCE_STORAGE_UNAVAILABLE":
                throw AccountLifecycleError.cleanupFailed
            default:
                throw AccountLifecycleError.unavailable
            }
        }
    }
}

private struct PreviewEnvelope: Decodable {
    let preview: AccountDeletionPreview
}

private struct DeletionEnvelope: Decodable {
    let result: AccountDeletionProgress
}

private struct AccountDeletionProgress: Decodable {
    let completed: Bool
    let deletedDocuments: Int?
    let redactedDocuments: Int?
    let archivedOwnedClasses: Int?
    let transferredOwnedClasses: Int?
    let retainedData: String?
}

private struct DeletionRequest: Encodable {
    let confirmation: String
    let policyVersion: String
    let classTransfers: [String: String]
}

private struct ErrorEnvelope: Decodable {
    let error: String
}
