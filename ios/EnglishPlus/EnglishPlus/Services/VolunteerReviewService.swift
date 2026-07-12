import Foundation

struct VolunteerReviewEvidence: Identifiable, Decodable, Equatable {
    let id: String
    let kind: VolunteerQualificationKind
    let objectKey: String
    let filename: String
    let mimeType: String
    let sizeBytes: Int
}

struct VolunteerReviewApplication: Identifiable, Decodable, Equatable {
    var id: String { uid }

    let uid: String
    let displayName: String
    let status: VolunteerApplicationStatus
    let motivation: String
    let submittedAt: String
    let evidence: [VolunteerReviewEvidence]
}

enum VolunteerReviewAction: String, Encodable, Equatable {
    case approved
    case rejected
    case needsMoreInformation
    case suspended
}

enum VolunteerReviewError: LocalizedError {
    case unavailable
    case unauthenticated
    case forbidden
    case requestFailed
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "志工審核目前無法使用。"
        case .unauthenticated:
            return "登入已逾時，請重新登入。"
        case .forbidden:
            return "這個帳號沒有志工審核權限。"
        case .requestFailed:
            return "審核資料沒有完成更新，請稍後再試。"
        case .invalidResponse:
            return "審核服務回應不完整。"
        }
    }
}

protocol VolunteerReviewService {
    func listApplications() async throws -> [VolunteerReviewApplication]
    func review(uid: String, action: VolunteerReviewAction, note: String) async throws
    func downloadEvidence(_ evidence: VolunteerReviewEvidence) async throws -> URL
}

struct UnavailableVolunteerReviewService: VolunteerReviewService {
    func listApplications() async throws -> [VolunteerReviewApplication] {
        throw VolunteerReviewError.unavailable
    }

    func review(uid: String, action: VolunteerReviewAction, note: String) async throws {
        throw VolunteerReviewError.unavailable
    }

    func downloadEvidence(_ evidence: VolunteerReviewEvidence) async throws -> URL {
        throw VolunteerReviewError.unavailable
    }
}

struct RemoteVolunteerReviewService: VolunteerReviewService {
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

    func listApplications() async throws -> [VolunteerReviewApplication] {
        var request = URLRequest(
            url: baseURL.appendingPathComponent("admin/volunteer-applications")
        )
        try await authorize(&request)
        let (data, response) = try await session.data(for: request)
        try validate(response)
        guard let payload = try? JSONDecoder().decode(ApplicationListResponse.self, from: data) else {
            throw VolunteerReviewError.invalidResponse
        }
        return payload.applications
    }

    func review(uid: String, action: VolunteerReviewAction, note: String) async throws {
        var request = URLRequest(
            url: baseURL
                .appendingPathComponent("admin/volunteer-review")
                .appendingPathComponent(uid)
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            ReviewRequest(action: action, note: note)
        )
        try await authorize(&request)
        let (_, response) = try await session.data(for: request)
        try validate(response)
    }

    func downloadEvidence(_ evidence: VolunteerReviewEvidence) async throws -> URL {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("admin/evidence"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "objectKey", value: evidence.objectKey)]
        guard let url = components?.url else {
            throw VolunteerReviewError.invalidResponse
        }
        var request = URLRequest(url: url)
        try await authorize(&request)
        let (data, response) = try await session.data(for: request)
        try validate(response)

        let extensionName = URL(fileURLWithPath: evidence.filename).pathExtension
        let safeExtension = extensionName.isEmpty ? "bin" : extensionName
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("EnglishPlusVolunteerEvidence", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let fileURL = directory.appendingPathComponent("\(evidence.id).\(safeExtension)")
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    private func authorize(_ request: inout URLRequest) async throws {
        guard let token = try await idTokenProvider(), !token.isEmpty else {
            throw VolunteerReviewError.unauthenticated
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw VolunteerReviewError.invalidResponse
        }
        switch http.statusCode {
        case 200..<300:
            return
        case 401:
            throw VolunteerReviewError.unauthenticated
        case 403:
            throw VolunteerReviewError.forbidden
        default:
            throw VolunteerReviewError.requestFailed
        }
    }
}

private struct ApplicationListResponse: Decodable {
    let applications: [VolunteerReviewApplication]
}

private struct ReviewRequest: Encodable {
    let action: VolunteerReviewAction
    let note: String
}
