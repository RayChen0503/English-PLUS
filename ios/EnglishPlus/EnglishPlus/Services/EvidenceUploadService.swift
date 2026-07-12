import Foundation

enum EvidenceUploadError: LocalizedError {
    case unavailable
    case unauthenticated
    case invalidFile
    case fileTooLarge
    case ticketRejected
    case uploadRejected
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "證明文件上傳目前無法使用。"
        case .unauthenticated:
            return "登入已逾時，請重新登入後再上傳。"
        case .invalidFile:
            return "無法讀取這個檔案，請改選 PDF、JPG 或 PNG。"
        case .fileTooLarge:
            return "單一證明文件不可超過 10 MB。"
        case .ticketRejected:
            return "無法建立安全上傳，請稍後再試。"
        case .uploadRejected:
            return "文件沒有上傳完成，請再試一次。"
        case .invalidResponse:
            return "上傳服務回應不完整，請稍後再試。"
        }
    }
}

protocol EvidenceUploadService {
    func upload(
        data: Data,
        filename: String,
        mimeType: String,
        kind: VolunteerQualificationKind
    ) async throws -> VolunteerEvidenceReference
    func delete(_ reference: VolunteerEvidenceReference) async throws
}

struct UnavailableEvidenceUploadService: EvidenceUploadService {
    func upload(
        data: Data,
        filename: String,
        mimeType: String,
        kind: VolunteerQualificationKind
    ) async throws -> VolunteerEvidenceReference {
        throw EvidenceUploadError.unavailable
    }

    func delete(_ reference: VolunteerEvidenceReference) async throws {
        throw EvidenceUploadError.unavailable
    }
}

struct RemoteEvidenceUploadService: EvidenceUploadService {
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

    func upload(
        data: Data,
        filename: String,
        mimeType: String,
        kind: VolunteerQualificationKind
    ) async throws -> VolunteerEvidenceReference {
        guard !data.isEmpty, !filename.isEmpty else {
            throw EvidenceUploadError.invalidFile
        }
        guard data.count <= 10 * 1024 * 1024 else {
            throw EvidenceUploadError.fileTooLarge
        }
        guard let idToken = try await idTokenProvider(), !idToken.isEmpty else {
            throw EvidenceUploadError.unauthenticated
        }

        let ticket = try await requestTicket(
            filename: filename,
            mimeType: mimeType,
            sizeBytes: data.count,
            kind: kind,
            idToken: idToken
        )
        var uploadRequest = URLRequest(url: ticket.uploadURL)
        uploadRequest.httpMethod = "PUT"
        uploadRequest.setValue(mimeType, forHTTPHeaderField: "Content-Type")
        uploadRequest.setValue(String(data.count), forHTTPHeaderField: "Content-Length")

        let (_, response) = try await session.upload(for: uploadRequest, from: data)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw EvidenceUploadError.uploadRejected
        }

        return VolunteerEvidenceReference(
            id: ticket.evidenceId,
            kind: kind,
            storageObjectKey: ticket.objectKey,
            originalFilename: filename,
            mimeType: mimeType,
            sizeBytes: data.count,
            uploadedAt: Date()
        )
    }

    func delete(_ reference: VolunteerEvidenceReference) async throws {
        guard let idToken = try await idTokenProvider(), !idToken.isEmpty else {
            throw EvidenceUploadError.unauthenticated
        }
        var request = URLRequest(
            url: baseURL.appendingPathComponent("evidence/object")
        )
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            EvidenceDeleteRequest(objectKey: reference.storageObjectKey)
        )
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw EvidenceUploadError.uploadRejected
        }
    }

    private func requestTicket(
        filename: String,
        mimeType: String,
        sizeBytes: Int,
        kind: VolunteerQualificationKind,
        idToken: String
    ) async throws -> UploadTicket {
        var request = URLRequest(
            url: baseURL.appendingPathComponent("evidence/upload-ticket")
        )
        request.httpMethod = "POST"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            TicketRequest(
                filename: filename,
                mimeType: mimeType,
                sizeBytes: sizeBytes,
                qualificationKind: kind.rawValue
            )
        )

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw EvidenceUploadError.ticketRejected
        }
        guard let ticket = try? JSONDecoder().decode(UploadTicket.self, from: data),
              ticket.uploadURL.scheme == "https",
              !ticket.objectKey.isEmpty,
              !ticket.evidenceId.isEmpty else {
            throw EvidenceUploadError.invalidResponse
        }
        return ticket
    }
}

private struct TicketRequest: Encodable {
    let filename: String
    let mimeType: String
    let sizeBytes: Int
    let qualificationKind: String
}

private struct UploadTicket: Decodable {
    let evidenceId: String
    let objectKey: String
    let uploadURL: URL
    let expiresAt: String
}

private struct EvidenceDeleteRequest: Encodable {
    let objectKey: String
}

enum EvidenceUploadConfig {
    static var workerBaseURL: URL? {
        guard let value = Bundle.main.object(
            forInfoDictionaryKey: "ENGLISHPLUS_EVIDENCE_UPLOAD_URL"
        ) as? String else {
            return nil
        }
        return URL(string: value)
    }
}
