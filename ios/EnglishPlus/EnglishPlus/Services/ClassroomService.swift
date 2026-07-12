import Foundation

struct ClassroomSummary: Identifiable, Codable, Equatable {
    let id: String
    let classId: String
    let name: String
    let role: UserRole
    let status: ClassMembershipStatus
    let joinedAt: String
    let visibilityStartsAt: String
    let leftAt: String?
    let joinCode: String?

    var formattedJoinCode: String? {
        guard let joinCode, joinCode.count == 8 else { return joinCode }
        let split = joinCode.index(joinCode.startIndex, offsetBy: 4)
        return "\(joinCode[..<split]) \(joinCode[split...])"
    }

    var membership: ClassMembership {
        let joinedDate = Self.date(from: joinedAt) ?? Date()
        return ClassMembership(
            classId: classId,
            className: name,
            role: role,
            groupId: nil,
            status: status,
            joinedAt: joinedDate,
            visibilityStartsAt: Self.date(from: visibilityStartsAt) ?? joinedDate,
            leftAt: leftAt.flatMap(Self.date(from:))
        )
    }

    private static func date(from value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}

enum ClassroomServiceError: LocalizedError, Equatable {
    case unavailable
    case unauthenticated
    case invalidName
    case invalidCode
    case codeNotFound
    case classUnavailable
    case permissionDenied
    case inactiveMembership
    case conflict
    case tooManyAttempts
    case invalidResponse
    case network

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "班級服務目前無法使用。"
        case .unauthenticated:
            return "登入已逾時，請重新登入後再試。"
        case .invalidName:
            return "班級名稱請輸入 2 到 40 個字。"
        case .invalidCode:
            return "請輸入完整的 8 碼班級代碼。"
        case .codeNotFound:
            return "找不到這個班級代碼，請向老師確認是否已重設。"
        case .classUnavailable:
            return "這個班級目前無法加入。"
        case .permissionDenied:
            return "這個帳號沒有執行此班級操作的權限。"
        case .inactiveMembership:
            return "你已不在這個班級中，資料已重新整理。"
        case .conflict:
            return "班級剛剛有更新，請重新整理後再試。"
        case .tooManyAttempts:
            return "班級代碼嘗試次數過多，請 15 分鐘後再試。"
        case .invalidResponse:
            return "班級服務回應不完整，請稍後再試。"
        case .network:
            return "目前無法連線到班級服務，請檢查網路後再試。"
        }
    }
}

@MainActor
protocol ClassroomService {
    func listClassrooms() async throws -> [ClassroomSummary]
    func createClassroom(name: String) async throws -> ClassroomSummary
    func joinClassroom(code: String) async throws -> ClassroomSummary
    func leaveClassroom(classId: String) async throws
    func resetJoinCode(classId: String) async throws -> ClassroomSummary
}

struct UnavailableClassroomService: ClassroomService {
    func listClassrooms() async throws -> [ClassroomSummary] {
        throw ClassroomServiceError.unavailable
    }

    func createClassroom(name: String) async throws -> ClassroomSummary {
        throw ClassroomServiceError.unavailable
    }

    func joinClassroom(code: String) async throws -> ClassroomSummary {
        throw ClassroomServiceError.unavailable
    }

    func leaveClassroom(classId: String) async throws {
        throw ClassroomServiceError.unavailable
    }

    func resetJoinCode(classId: String) async throws -> ClassroomSummary {
        throw ClassroomServiceError.unavailable
    }
}

@MainActor
final class MockClassroomService: ClassroomService {
    private var classrooms: [ClassroomSummary] = []

    func listClassrooms() async throws -> [ClassroomSummary] {
        classrooms.filter { $0.status == .active }
    }

    func createClassroom(name: String) async throws -> ClassroomSummary {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (2...40).contains(normalized.count) else {
            throw ClassroomServiceError.invalidName
        }
        let now = ISO8601DateFormatter().string(from: Date())
        let classId = "CLS-\(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(20))"
            .uppercased()
        let classroom = ClassroomSummary(
            id: classId,
            classId: classId,
            name: normalized,
            role: .teacher,
            status: .active,
            joinedAt: now,
            visibilityStartsAt: now,
            leftAt: nil,
            joinCode: Self.code()
        )
        classrooms.append(classroom)
        return classroom
    }

    func joinClassroom(code: String) async throws -> ClassroomSummary {
        let normalized = Self.normalizedCode(code)
        guard normalized.count == 8 else { throw ClassroomServiceError.invalidCode }
        guard let teacherClassroom = classrooms.first(where: { $0.joinCode == normalized }) else {
            throw ClassroomServiceError.codeNotFound
        }
        let now = ISO8601DateFormatter().string(from: Date())
        let classroom = ClassroomSummary(
            id: teacherClassroom.classId,
            classId: teacherClassroom.classId,
            name: teacherClassroom.name,
            role: .student,
            status: .active,
            joinedAt: now,
            visibilityStartsAt: now,
            leftAt: nil,
            joinCode: nil
        )
        classrooms.removeAll { $0.classId == classroom.classId && $0.role == .student }
        classrooms.append(classroom)
        return classroom
    }

    func leaveClassroom(classId: String) async throws {
        guard let index = classrooms.firstIndex(where: {
            $0.classId == classId && $0.role == .student && $0.status == .active
        }) else {
            throw ClassroomServiceError.inactiveMembership
        }
        let existing = classrooms[index]
        classrooms[index] = ClassroomSummary(
            id: existing.id,
            classId: existing.classId,
            name: existing.name,
            role: existing.role,
            status: .left,
            joinedAt: existing.joinedAt,
            visibilityStartsAt: existing.visibilityStartsAt,
            leftAt: ISO8601DateFormatter().string(from: Date()),
            joinCode: nil
        )
    }

    func resetJoinCode(classId: String) async throws -> ClassroomSummary {
        guard let index = classrooms.firstIndex(where: {
            $0.classId == classId && $0.role == .teacher && $0.status == .active
        }) else {
            throw ClassroomServiceError.permissionDenied
        }
        let existing = classrooms[index]
        let updated = ClassroomSummary(
            id: existing.id,
            classId: existing.classId,
            name: existing.name,
            role: existing.role,
            status: existing.status,
            joinedAt: existing.joinedAt,
            visibilityStartsAt: existing.visibilityStartsAt,
            leftAt: existing.leftAt,
            joinCode: Self.code()
        )
        classrooms[index] = updated
        return updated
    }

    private static func normalizedCode(_ value: String) -> String {
        value.uppercased().filter { $0.isLetter || $0.isNumber }
    }

    private static func code() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<8).compactMap { _ in alphabet.randomElement() })
    }
}

struct RemoteClassroomService: ClassroomService {
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

    func listClassrooms() async throws -> [ClassroomSummary] {
        let _: ClassroomBootstrapResponse = try await send(
            path: "classrooms/bootstrap",
            method: "POST",
            body: EmptyRequest()
        )
        let response: ClassroomListResponse = try await send(
            path: "classrooms",
            method: "GET",
            body: Optional<EmptyRequest>.none
        )
        return response.classrooms
    }

    func createClassroom(name: String) async throws -> ClassroomSummary {
        let response: ClassroomMutationResponse = try await send(
            path: "classrooms",
            method: "POST",
            body: ClassroomNameRequest(name: name)
        )
        return response.classroom
    }

    func joinClassroom(code: String) async throws -> ClassroomSummary {
        let response: ClassroomMutationResponse = try await send(
            path: "classrooms/join",
            method: "POST",
            body: ClassroomCodeRequest(code: code)
        )
        return response.classroom
    }

    func leaveClassroom(classId: String) async throws {
        let _: ClassroomLeaveResponse = try await send(
            path: "classrooms/\(classId)/leave",
            method: "POST",
            body: EmptyRequest()
        )
    }

    func resetJoinCode(classId: String) async throws -> ClassroomSummary {
        let response: ClassroomMutationResponse = try await send(
            path: "classrooms/\(classId)/reset-code",
            method: "POST",
            body: EmptyRequest()
        )
        return response.classroom
    }

    private func send<RequestBody: Encodable, ResponseBody: Decodable>(
        path: String,
        method: String,
        body: RequestBody?
    ) async throws -> ResponseBody {
        guard let token = try await idTokenProvider(), !token.isEmpty else {
            throw ClassroomServiceError.unauthenticated
        }
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ClassroomServiceError.network
        }
        guard let http = response as? HTTPURLResponse else {
            throw ClassroomServiceError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let code = (try? JSONDecoder().decode(ClassroomErrorResponse.self, from: data))?.error
            throw Self.error(for: code, status: http.statusCode)
        }
        guard let decoded = try? JSONDecoder().decode(ResponseBody.self, from: data) else {
            throw ClassroomServiceError.invalidResponse
        }
        return decoded
    }

    private static func error(for code: String?, status: Int) -> ClassroomServiceError {
        switch code {
        case "INVALID_CLASSROOM_NAME": return .invalidName
        case "INVALID_CLASSROOM_CODE": return .invalidCode
        case "CLASSROOM_CODE_NOT_FOUND": return .codeNotFound
        case "CLASSROOM_UNAVAILABLE", "CLASSROOM_NOT_FOUND": return .classUnavailable
        case "CLASSROOM_MEMBERSHIP_INACTIVE": return .inactiveMembership
        case "FIRESTORE_CONFLICT": return .conflict
        case "CLASSROOM_JOIN_RATE_LIMIT": return .tooManyAttempts
        case "AUTH_REQUIRED", "INVALID_TOKEN", "INVALID_TOKEN_CLAIMS": return .unauthenticated
        case "TEACHER_ACCOUNT_REQUIRED", "STUDENT_ACCOUNT_REQUIRED", "CLASSROOM_OWNER_REQUIRED":
            return .permissionDenied
        default:
            if status == 401 { return .unauthenticated }
            if status == 403 { return .permissionDenied }
            if status == 409 { return .conflict }
            return .unavailable
        }
    }
}

private struct EmptyRequest: Codable {}
private struct ClassroomNameRequest: Encodable { let name: String }
private struct ClassroomCodeRequest: Encodable { let code: String }
private struct ClassroomListResponse: Decodable { let classrooms: [ClassroomSummary] }
private struct ClassroomBootstrapResponse: Decodable { let migrated: Bool }
private struct ClassroomMutationResponse: Decodable { let classroom: ClassroomSummary }
private struct ClassroomLeaveResponse: Decodable { let classId: String; let left: Bool }
private struct ClassroomErrorResponse: Decodable { let error: String }
