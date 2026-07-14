import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

protocol ClassroomRosterListenerToken {
    func cancel()
}

final class AnyClassroomRosterListenerToken: ClassroomRosterListenerToken {
    private let cancellation: () -> Void

    init(_ cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    func cancel() {
        cancellation()
    }
}

#if canImport(FirebaseFirestore)
@MainActor
private final class ClassroomMembershipRealtimeBridge {
    private let userUid: String
    private let onChange: @MainActor ([String]) -> Void
    private let onError: @MainActor (Error) -> Void
    private var registration: ListenerRegistration?

    init(
        userUid: String,
        onChange: @escaping @MainActor ([String]) -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) {
        self.userUid = userUid
        self.onChange = onChange
        self.onError = onError
    }

    func start() {
        registration = Firestore.firestore()
            .collection("users/\(userUid)/classMemberships")
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let error {
                        self.onError(error)
                        return
                    }
                    let activeClassIds = (snapshot?.documents ?? []).compactMap { document in
                        let data = document.data()
                        let hasActiveStatus = data["status"] as? String == ClassMembershipStatus.active.rawValue
                            || (data["status"] == nil && data["active"] as? Bool == true)
                        let hasLeftAt = data["leftAt"] != nil && !(data["leftAt"] is NSNull)
                        return hasActiveStatus && !hasLeftAt ? document.documentID : nil
                    }
                    .sorted()
                    self.onChange(activeClassIds)
                }
            }
    }

    func cancel() {
        registration?.remove()
        registration = nil
    }
}

@MainActor
private final class VolunteerServiceRealtimeBridge {
    private let collectionPath: String
    private let onChange: @MainActor ([VolunteerServiceSummary]) -> Void
    private let onError: @MainActor (Error) -> Void
    private var registration: ListenerRegistration?

    init(
        collectionPath: String,
        onChange: @escaping @MainActor ([VolunteerServiceSummary]) -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) {
        self.collectionPath = collectionPath
        self.onChange = onChange
        self.onError = onError
    }

    func start() {
        registration = Firestore.firestore()
            .collection(collectionPath)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let error {
                        self.onError(error)
                        return
                    }
                    let services = (snapshot?.documents ?? [])
                        .compactMap(Self.summary)
                        .sorted { left, right in
                            if left.status == right.status {
                                return left.requestedAt > right.requestedAt
                            }
                            return left.status == .pendingApproval
                        }
                    self.onChange(services)
                }
            }
    }

    func cancel() {
        registration?.remove()
        registration = nil
    }

    private static func summary(from document: QueryDocumentSnapshot) -> VolunteerServiceSummary? {
        let data = document.data()
        guard let classId = data["classId"] as? String,
              let className = data["className"] as? String,
              let volunteerUid = data["volunteerUid"] as? String,
              let statusValue = data["status"] as? String,
              let status = VolunteerServiceStatus(rawValue: statusValue)
        else { return nil }
        return VolunteerServiceSummary(
            id: document.documentID,
            classId: classId,
            className: className,
            volunteerUid: volunteerUid,
            volunteerName: data["volunteerName"] as? String ?? "志工",
            status: status,
            requestedAt: dateString(data["requestedAt"]),
            decidedAt: optionalDateString(data["decidedAt"]),
            joinedAt: optionalDateString(data["joinedAt"])
        )
    }

    private static func dateString(_ value: Any?) -> String {
        optionalDateString(value) ?? ""
    }

    private static func optionalDateString(_ value: Any?) -> String? {
        if let timestamp = value as? Timestamp {
            return ISO8601DateFormatter().string(from: timestamp.dateValue())
        }
        return value as? String
    }
}

@MainActor
private final class ClassroomRosterRealtimeBridge {
    private let classId: String
    private let onChange: @MainActor ([ClassroomStudentSummary]) -> Void
    private let onError: @MainActor (Error) -> Void
    private var registrations: [ListenerRegistration] = []
    private var activeMembers: [String: [String: Any]] = [:]
    private var summaries: [String: ClassroomStudentSummary] = [:]
    private var hasReceivedMembers = false

    init(
        classId: String,
        onChange: @escaping @MainActor ([ClassroomStudentSummary]) -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) {
        self.classId = classId
        self.onChange = onChange
        self.onError = onError
    }

    func start() {
        let classPath = "classes/\(classId)"
        registrations.append(
            Firestore.firestore().collection("\(classPath)/members")
                .addSnapshotListener { [weak self] snapshot, error in
                    Task { @MainActor in self?.receiveMembers(snapshot: snapshot, error: error) }
                }
        )
        registrations.append(
            Firestore.firestore().collection("\(classPath)/students")
                .whereField("membershipStatus", isEqualTo: "active")
                .addSnapshotListener { [weak self] snapshot, error in
                    Task { @MainActor in self?.receiveSummaries(snapshot: snapshot, error: error) }
                }
        )
    }

    func cancel() {
        registrations.forEach { $0.remove() }
        registrations = []
    }

    private func receiveMembers(snapshot: QuerySnapshot?, error: Error?) {
        if let error {
            onError(error)
            return
        }
        activeMembers = Dictionary(
            uniqueKeysWithValues: (snapshot?.documents ?? []).compactMap { document in
                let data = document.data()
                guard data["role"] as? String == UserRole.student.rawValue,
                      data["status"] as? String == ClassMembershipStatus.active.rawValue
                        || data["active"] as? Bool == true,
                      data["leftAt"] == nil || data["leftAt"] is NSNull
                else { return nil }
                return (document.documentID, data)
            }
        )
        hasReceivedMembers = true
        publish()
    }

    private func receiveSummaries(snapshot: QuerySnapshot?, error: Error?) {
        if let error {
            onError(error)
            return
        }
        summaries = Dictionary(
            uniqueKeysWithValues: (snapshot?.documents ?? []).compactMap { document in
                Self.summary(from: document, classId: classId).map { ($0.studentUid, $0) }
            }
        )
        publish()
    }

    private func publish() {
        guard hasReceivedMembers else { return }
        let students = activeMembers.map { uid, member in
            summaries[uid] ?? ClassroomStudentSummary(
                id: uid,
                studentUid: uid,
                studentName: member["displayName"] as? String ?? "學生",
                classId: classId,
                gradeBand: "",
                currentLevel: "待評估",
                recommendedTrack: MissionTrack.steady.rawValue,
                moodScore: nil,
                riskLevel: .low,
                missionStatus: "notStarted",
                lastActivityAt: nil,
                joinedAt: (member["joinedAt"] as? Timestamp).map(Self.iso8601String) ?? ""
            )
        }
        .sorted { $0.studentName.localizedStandardCompare($1.studentName) == .orderedAscending }
        onChange(students)
    }

    private static func summary(
        from document: QueryDocumentSnapshot,
        classId: String
    ) -> ClassroomStudentSummary? {
        let data = document.data()
        let studentUid = data["uid"] as? String ?? document.documentID
        guard !studentUid.isEmpty else { return nil }
        return ClassroomStudentSummary(
            id: studentUid,
            studentUid: studentUid,
            studentName: data["displayName"] as? String ?? "學生",
            classId: classId,
            gradeBand: data["gradeBand"] as? String ?? "",
            currentLevel: data["currentLevel"] as? String ?? "待評估",
            recommendedTrack: data["recommendedTrack"] as? String ?? MissionTrack.steady.rawValue,
            moodScore: data["lastMoodScore"] as? Int,
            riskLevel: (data["riskLevel"] as? String).flatMap(RiskLevel.init(rawValue:)) ?? .low,
            missionStatus: data["lastMissionStatus"] as? String ?? "notStarted",
            lastActivityAt: (data["lastActivityAt"] as? Timestamp).map(Self.iso8601String),
            joinedAt: (data["joinedAt"] as? Timestamp).map(Self.iso8601String) ?? ""
        )
    }

    private static func iso8601String(_ timestamp: Timestamp) -> String {
        ISO8601DateFormatter().string(from: timestamp.dateValue())
    }
}
#endif

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

struct ClassroomStudentSummary: Identifiable, Codable, Equatable {
    let id: String
    let studentUid: String
    let studentName: String
    let classId: String
    let gradeBand: String
    let currentLevel: String
    let recommendedTrack: String
    let moodScore: Int?
    let riskLevel: RiskLevel
    let missionStatus: String
    let lastActivityAt: String?
    let joinedAt: String

    var staffSummary: StaffStudentSummary {
        StaffStudentSummary(
            id: studentUid,
            studentUid: studentUid,
            studentName: studentName,
            classCode: classId,
            moodScore: moodScore,
            riskLevel: riskLevel,
            missionProgress: missionProgressText,
            nextAction: nextActionText
        )
    }

    private var missionProgressText: String {
        switch missionStatus {
        case MissionStatus.completed.rawValue:
            return "今日任務已完成"
        case MissionStatus.active.rawValue:
            return "今日任務進行中"
        default:
            return "尚未開始今日任務"
        }
    }

    private var nextActionText: String {
        switch riskLevel {
        case .high:
            return "先查看求助與近期答題，再安排短題組。"
        case .medium:
            return "確認近期卡點，再安排穩定練習。"
        case .low:
            return missionStatus == MissionStatus.completed.rawValue
                ? "可安排下一組挑戰。"
                : "等待學生開始今日任務。"
        }
    }
}

enum VolunteerServiceStatus: String, Codable, Equatable {
    case pendingApproval
    case active
    case rejected
    case left
    case removed

    var title: String {
        switch self {
        case .pendingApproval: return "等待老師核准"
        case .active: return "服務中"
        case .rejected: return "未通過"
        case .left: return "已離開"
        case .removed: return "已移除"
        }
    }
}

struct VolunteerServiceSummary: Identifiable, Codable, Equatable {
    let id: String
    let classId: String
    let className: String
    let volunteerUid: String
    let volunteerName: String
    let status: VolunteerServiceStatus
    let requestedAt: String
    let decidedAt: String?
    let joinedAt: String?
}

struct VolunteerInviteCodeSummary: Codable, Equatable {
    let classId: String
    let code: String

    var formattedCode: String {
        guard code.count == 8 else { return code }
        let split = code.index(code.startIndex, offsetBy: 4)
        return "\(code[..<split]) \(code[split...])"
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
    case classTooLarge
    case volunteerApprovalRequired
    case volunteerRequestNotFound
    case volunteerAlreadyRequested
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
        case .classTooLarge:
            return "班級成員較多，暫時無法重新命名。請稍後再試。"
        case .volunteerApprovalRequired:
            return "志工帳號需先通過平台資格審核。"
        case .volunteerRequestNotFound:
            return "找不到這筆志工服務申請，請重新載入。"
        case .volunteerAlreadyRequested:
            return "你已申請或正在服務這個班級。"
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
    func listStudents(classId: String) async throws -> [ClassroomStudentSummary]
    func createClassroom(name: String) async throws -> ClassroomSummary
    func updateClassroom(classId: String, name: String) async throws -> ClassroomSummary
    func deleteClassroom(classId: String) async throws
    func joinClassroom(code: String) async throws -> ClassroomSummary
    func leaveClassroom(classId: String) async throws
    func resetJoinCode(classId: String) async throws -> ClassroomSummary
    func listVolunteerServices() async throws -> [VolunteerServiceSummary]
    func requestVolunteerService(code: String) async throws -> VolunteerServiceSummary
    func leaveVolunteerService(classId: String) async throws
    func listClassroomVolunteers(classId: String) async throws -> [VolunteerServiceSummary]
    func volunteerInviteCode(classId: String) async throws -> VolunteerInviteCodeSummary?
    func resetVolunteerInviteCode(classId: String) async throws -> VolunteerInviteCodeSummary
    func reviewVolunteerService(classId: String, volunteerUid: String, approve: Bool) async throws
    func removeVolunteerService(classId: String, volunteerUid: String) async throws
    func startVolunteerServiceListener(
        userUid: String,
        onChange: @escaping @MainActor ([VolunteerServiceSummary]) -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) -> ClassroomRosterListenerToken
    func startClassroomVolunteerListener(
        classId: String,
        onChange: @escaping @MainActor ([VolunteerServiceSummary]) -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) -> ClassroomRosterListenerToken
    func startMembershipListener(
        userUid: String,
        onChange: @escaping @MainActor ([String]) -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) -> ClassroomRosterListenerToken
    func startStudentListener(
        classId: String,
        onChange: @escaping @MainActor ([ClassroomStudentSummary]) -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) -> ClassroomRosterListenerToken
}

struct UnavailableClassroomService: ClassroomService {
    func listClassrooms() async throws -> [ClassroomSummary] {
        throw ClassroomServiceError.unavailable
    }

    func listStudents(classId: String) async throws -> [ClassroomStudentSummary] {
        throw ClassroomServiceError.unavailable
    }

    func createClassroom(name: String) async throws -> ClassroomSummary {
        throw ClassroomServiceError.unavailable
    }

    func updateClassroom(classId: String, name: String) async throws -> ClassroomSummary {
        throw ClassroomServiceError.unavailable
    }

    func deleteClassroom(classId: String) async throws {
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

    func listVolunteerServices() async throws -> [VolunteerServiceSummary] {
        throw ClassroomServiceError.unavailable
    }

    func requestVolunteerService(code: String) async throws -> VolunteerServiceSummary {
        throw ClassroomServiceError.unavailable
    }

    func leaveVolunteerService(classId: String) async throws {
        throw ClassroomServiceError.unavailable
    }

    func listClassroomVolunteers(classId: String) async throws -> [VolunteerServiceSummary] {
        throw ClassroomServiceError.unavailable
    }

    func volunteerInviteCode(classId: String) async throws -> VolunteerInviteCodeSummary? {
        throw ClassroomServiceError.unavailable
    }

    func resetVolunteerInviteCode(classId: String) async throws -> VolunteerInviteCodeSummary {
        throw ClassroomServiceError.unavailable
    }

    func reviewVolunteerService(classId: String, volunteerUid: String, approve: Bool) async throws {
        throw ClassroomServiceError.unavailable
    }

    func removeVolunteerService(classId: String, volunteerUid: String) async throws {
        throw ClassroomServiceError.unavailable
    }

    func startVolunteerServiceListener(
        userUid: String,
        onChange: @escaping @MainActor ([VolunteerServiceSummary]) -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) -> ClassroomRosterListenerToken {
        AnyClassroomRosterListenerToken {}
    }

    func startClassroomVolunteerListener(
        classId: String,
        onChange: @escaping @MainActor ([VolunteerServiceSummary]) -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) -> ClassroomRosterListenerToken {
        AnyClassroomRosterListenerToken {}
    }

    func startMembershipListener(
        userUid: String,
        onChange: @escaping @MainActor ([String]) -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) -> ClassroomRosterListenerToken {
        AnyClassroomRosterListenerToken {}
    }

    func startStudentListener(
        classId: String,
        onChange: @escaping @MainActor ([ClassroomStudentSummary]) -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) -> ClassroomRosterListenerToken {
        AnyClassroomRosterListenerToken {}
    }
}

@MainActor
final class MockClassroomService: ClassroomService {
    private var classrooms: [ClassroomSummary] = []
    private var studentsByClass: [String: [ClassroomStudentSummary]] = [:]
    private(set) var studentListenerStartCount = 0
    private(set) var lastStudentListenerClassId: String?
    private var membershipChangeHandler: (@MainActor ([String]) -> Void)?
    private var volunteerServiceChangeHandler: (@MainActor ([VolunteerServiceSummary]) -> Void)?
    private var classroomVolunteerChangeHandlers: [String: @MainActor ([VolunteerServiceSummary]) -> Void] = [:]
    private var volunteerInviteCodes: [String: String] = [:]
    private var volunteerServices: [VolunteerServiceSummary] = []

    func listClassrooms() async throws -> [ClassroomSummary] {
        classrooms.filter { $0.status == .active }
    }

    func listStudents(classId: String) async throws -> [ClassroomStudentSummary] {
        studentsByClass[classId, default: []]
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

    func updateClassroom(classId: String, name: String) async throws -> ClassroomSummary {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (2...40).contains(normalized.count) else {
            throw ClassroomServiceError.invalidName
        }
        guard let index = classrooms.firstIndex(where: {
            $0.classId == classId && $0.role == .teacher && $0.status == .active
        }) else {
            throw ClassroomServiceError.permissionDenied
        }
        let existing = classrooms[index]
        let updated = ClassroomSummary(
            id: existing.id,
            classId: existing.classId,
            name: normalized,
            role: existing.role,
            status: existing.status,
            joinedAt: existing.joinedAt,
            visibilityStartsAt: existing.visibilityStartsAt,
            leftAt: existing.leftAt,
            joinCode: existing.joinCode
        )
        classrooms[index] = updated
        return updated
    }

    func deleteClassroom(classId: String) async throws {
        guard classrooms.contains(where: {
            $0.classId == classId && $0.role == .teacher && $0.status == .active
        }) else {
            throw ClassroomServiceError.permissionDenied
        }
        let deletedAt = ISO8601DateFormatter().string(from: Date())
        classrooms = classrooms.map { classroom in
            guard classroom.classId == classId else { return classroom }
            return ClassroomSummary(
                id: classroom.id,
                classId: classroom.classId,
                name: classroom.name,
                role: classroom.role,
                status: .left,
                joinedAt: classroom.joinedAt,
                visibilityStartsAt: classroom.visibilityStartsAt,
                leftAt: deletedAt,
                joinCode: nil
            )
        }
        studentsByClass[classId] = []
        volunteerInviteCodes[classId] = nil
        let now = ISO8601DateFormatter().string(from: Date())
        volunteerServices = volunteerServices.map { service in
            guard service.classId == classId,
                  service.status == .active || service.status == .pendingApproval
            else { return service }
            return VolunteerServiceSummary(
                id: service.id,
                classId: service.classId,
                className: service.className,
                volunteerUid: service.volunteerUid,
                volunteerName: service.volunteerName,
                status: .removed,
                requestedAt: service.requestedAt,
                decidedAt: now,
                joinedAt: service.joinedAt
            )
        }
        publishVolunteerServiceChanges(classId: classId)
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
        studentsByClass[classroom.classId] = [
            ClassroomStudentSummary(
                id: "mock-student",
                studentUid: "mock-student",
                studentName: "展示學生",
                classId: classroom.classId,
                gradeBand: "",
                currentLevel: "待評估",
                recommendedTrack: MissionTrack.steady.rawValue,
                moodScore: nil,
                riskLevel: .low,
                missionStatus: "notStarted",
                lastActivityAt: nil,
                joinedAt: now
            )
        ]
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

    func listVolunteerServices() async throws -> [VolunteerServiceSummary] {
        volunteerServices
    }

    func requestVolunteerService(code: String) async throws -> VolunteerServiceSummary {
        let normalized = Self.normalizedCode(code)
        guard let classId = volunteerInviteCodes.first(where: { $0.value == normalized })?.key,
              let classroom = classrooms.first(where: { $0.classId == classId })
        else { throw ClassroomServiceError.codeNotFound }
        guard !volunteerServices.contains(where: {
            $0.classId == classId && ($0.status == .pendingApproval || $0.status == .active)
        }) else { throw ClassroomServiceError.volunteerAlreadyRequested }

        let now = ISO8601DateFormatter().string(from: Date())
        let summary = VolunteerServiceSummary(
            id: "\(classId)-mock-volunteer",
            classId: classId,
            className: classroom.name,
            volunteerUid: "mock-volunteer",
            volunteerName: "志工",
            status: .pendingApproval,
            requestedAt: now,
            decidedAt: nil,
            joinedAt: nil
        )
        volunteerServices.removeAll { $0.classId == classId && $0.volunteerUid == summary.volunteerUid }
        volunteerServices.append(summary)
        publishVolunteerServiceChanges(classId: classId)
        return summary
    }

    func leaveVolunteerService(classId: String) async throws {
        try updateVolunteerService(classId: classId, volunteerUid: "mock-volunteer", status: .left)
    }

    func listClassroomVolunteers(classId: String) async throws -> [VolunteerServiceSummary] {
        volunteerServices.filter { $0.classId == classId }
    }

    func volunteerInviteCode(classId: String) async throws -> VolunteerInviteCodeSummary? {
        volunteerInviteCodes[classId].map { VolunteerInviteCodeSummary(classId: classId, code: $0) }
    }

    func resetVolunteerInviteCode(classId: String) async throws -> VolunteerInviteCodeSummary {
        guard classrooms.contains(where: {
            $0.classId == classId && $0.role == .teacher && $0.status == .active
        }) else { throw ClassroomServiceError.permissionDenied }
        let code = Self.code()
        volunteerInviteCodes[classId] = code
        return VolunteerInviteCodeSummary(classId: classId, code: code)
    }

    func reviewVolunteerService(classId: String, volunteerUid: String, approve: Bool) async throws {
        try updateVolunteerService(
            classId: classId,
            volunteerUid: volunteerUid,
            status: approve ? .active : .rejected
        )
    }

    func removeVolunteerService(classId: String, volunteerUid: String) async throws {
        try updateVolunteerService(classId: classId, volunteerUid: volunteerUid, status: .removed)
    }

    private func updateVolunteerService(
        classId: String,
        volunteerUid: String,
        status: VolunteerServiceStatus
    ) throws {
        guard let index = volunteerServices.firstIndex(where: {
            $0.classId == classId && $0.volunteerUid == volunteerUid
        }) else { throw ClassroomServiceError.volunteerRequestNotFound }
        let existing = volunteerServices[index]
        let now = ISO8601DateFormatter().string(from: Date())
        volunteerServices[index] = VolunteerServiceSummary(
            id: existing.id,
            classId: existing.classId,
            className: existing.className,
            volunteerUid: existing.volunteerUid,
            volunteerName: existing.volunteerName,
            status: status,
            requestedAt: existing.requestedAt,
            decidedAt: now,
            joinedAt: status == .active ? now : existing.joinedAt
        )
        publishVolunteerServiceChanges(classId: classId)
        if status == .active,
           let teacherClassroom = classrooms.first(where: {
               $0.classId == classId && $0.role == .teacher
           }) {
            classrooms.removeAll { $0.classId == classId && $0.role == .volunteer }
            classrooms.append(ClassroomSummary(
                id: classId,
                classId: classId,
                name: teacherClassroom.name,
                role: .volunteer,
                status: .active,
                joinedAt: now,
                visibilityStartsAt: now,
                leftAt: nil,
                joinCode: nil
            ))
        } else if status == .left || status == .removed {
            classrooms.removeAll { $0.classId == classId && $0.role == .volunteer }
        }
    }

    func startVolunteerServiceListener(
        userUid: String,
        onChange: @escaping @MainActor ([VolunteerServiceSummary]) -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) -> ClassroomRosterListenerToken {
        volunteerServiceChangeHandler = onChange
        onChange(volunteerServices)
        return AnyClassroomRosterListenerToken { [weak self] in
            Task { @MainActor [weak self] in
                self?.volunteerServiceChangeHandler = nil
            }
        }
    }

    func startClassroomVolunteerListener(
        classId: String,
        onChange: @escaping @MainActor ([VolunteerServiceSummary]) -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) -> ClassroomRosterListenerToken {
        classroomVolunteerChangeHandlers[classId] = onChange
        onChange(volunteerServices.filter { $0.classId == classId })
        return AnyClassroomRosterListenerToken { [weak self] in
            Task { @MainActor [weak self] in
                self?.classroomVolunteerChangeHandlers[classId] = nil
            }
        }
    }

    private func publishVolunteerServiceChanges(classId: String) {
        volunteerServiceChangeHandler?(volunteerServices)
        classroomVolunteerChangeHandlers[classId]?(
            volunteerServices.filter { $0.classId == classId }
        )
    }

    func startMembershipListener(
        userUid: String,
        onChange: @escaping @MainActor ([String]) -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) -> ClassroomRosterListenerToken {
        membershipChangeHandler = onChange
        return AnyClassroomRosterListenerToken {}
    }

    func simulateMembershipChange(activeClassIds: [String]) {
        membershipChangeHandler?(activeClassIds.sorted())
    }

    func startStudentListener(
        classId: String,
        onChange: @escaping @MainActor ([ClassroomStudentSummary]) -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) -> ClassroomRosterListenerToken {
        studentListenerStartCount += 1
        lastStudentListenerClassId = classId
        onChange(studentsByClass[classId, default: []])
        return AnyClassroomRosterListenerToken {}
    }

    func seedStudents(_ students: [ClassroomStudentSummary], classId: String) {
        studentsByClass[classId] = students
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

    func listStudents(classId: String) async throws -> [ClassroomStudentSummary] {
        let response: ClassroomStudentListResponse = try await send(
            path: "classrooms/\(classId)/students",
            method: "GET",
            body: Optional<EmptyRequest>.none
        )
        return response.students
    }

    func createClassroom(name: String) async throws -> ClassroomSummary {
        let response: ClassroomMutationResponse = try await send(
            path: "classrooms",
            method: "POST",
            body: ClassroomNameRequest(name: name)
        )
        return response.classroom
    }

    func updateClassroom(classId: String, name: String) async throws -> ClassroomSummary {
        let response: ClassroomMutationResponse = try await send(
            path: "classrooms/\(classId)",
            method: "PATCH",
            body: ClassroomNameRequest(name: name)
        )
        return response.classroom
    }

    func deleteClassroom(classId: String) async throws {
        let _: ClassroomDeleteResponse = try await send(
            path: "classrooms/\(classId)",
            method: "DELETE",
            body: Optional<EmptyRequest>.none
        )
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

    func listVolunteerServices() async throws -> [VolunteerServiceSummary] {
        let response: VolunteerServiceListResponse = try await send(
            path: "volunteer-services",
            method: "GET",
            body: Optional<EmptyRequest>.none
        )
        return response.services
    }

    func requestVolunteerService(code: String) async throws -> VolunteerServiceSummary {
        let response: VolunteerServiceMutationResponse = try await send(
            path: "volunteer-services/request",
            method: "POST",
            body: ClassroomCodeRequest(code: code)
        )
        return response.service
    }

    func leaveVolunteerService(classId: String) async throws {
        let _: VolunteerServiceActionResponse = try await send(
            path: "volunteer-services/\(classId)/leave",
            method: "POST",
            body: EmptyRequest()
        )
    }

    func listClassroomVolunteers(classId: String) async throws -> [VolunteerServiceSummary] {
        let response: VolunteerServiceListResponse = try await send(
            path: "classrooms/\(classId)/volunteers",
            method: "GET",
            body: Optional<EmptyRequest>.none
        )
        return response.services
    }

    func volunteerInviteCode(classId: String) async throws -> VolunteerInviteCodeSummary? {
        let response: VolunteerInviteCodeResponse = try await send(
            path: "classrooms/\(classId)/volunteer-code",
            method: "GET",
            body: Optional<EmptyRequest>.none
        )
        return response.invitation
    }

    func resetVolunteerInviteCode(classId: String) async throws -> VolunteerInviteCodeSummary {
        let response: VolunteerInviteCodeResponse = try await send(
            path: "classrooms/\(classId)/volunteer-code/reset",
            method: "POST",
            body: EmptyRequest()
        )
        guard let invitation = response.invitation else {
            throw ClassroomServiceError.invalidResponse
        }
        return invitation
    }

    func reviewVolunteerService(classId: String, volunteerUid: String, approve: Bool) async throws {
        let action = approve ? "approve" : "reject"
        let _: VolunteerServiceActionResponse = try await send(
            path: "classrooms/\(classId)/volunteers/\(volunteerUid)/\(action)",
            method: "POST",
            body: EmptyRequest()
        )
    }

    func removeVolunteerService(classId: String, volunteerUid: String) async throws {
        let _: VolunteerServiceActionResponse = try await send(
            path: "classrooms/\(classId)/volunteers/\(volunteerUid)/remove",
            method: "POST",
            body: EmptyRequest()
        )
    }

    func startVolunteerServiceListener(
        userUid: String,
        onChange: @escaping @MainActor ([VolunteerServiceSummary]) -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) -> ClassroomRosterListenerToken {
        #if canImport(FirebaseFirestore)
        if FirebaseAppConfigurator.hasBundledConfig {
            let bridge = VolunteerServiceRealtimeBridge(
                collectionPath: "users/\(userUid)/volunteerServices",
                onChange: onChange,
                onError: onError
            )
            bridge.start()
            return AnyClassroomRosterListenerToken { bridge.cancel() }
        }
        #endif
        return AnyClassroomRosterListenerToken {}
    }

    func startClassroomVolunteerListener(
        classId: String,
        onChange: @escaping @MainActor ([VolunteerServiceSummary]) -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) -> ClassroomRosterListenerToken {
        #if canImport(FirebaseFirestore)
        if FirebaseAppConfigurator.hasBundledConfig {
            let bridge = VolunteerServiceRealtimeBridge(
                collectionPath: "classes/\(classId)/volunteerRequests",
                onChange: onChange,
                onError: onError
            )
            bridge.start()
            return AnyClassroomRosterListenerToken { bridge.cancel() }
        }
        #endif
        return AnyClassroomRosterListenerToken {}
    }

    func startMembershipListener(
        userUid: String,
        onChange: @escaping @MainActor ([String]) -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) -> ClassroomRosterListenerToken {
        #if canImport(FirebaseFirestore)
        if FirebaseAppConfigurator.hasBundledConfig {
            let bridge = ClassroomMembershipRealtimeBridge(
                userUid: userUid,
                onChange: onChange,
                onError: onError
            )
            bridge.start()
            return AnyClassroomRosterListenerToken { bridge.cancel() }
        }
        #endif

        return AnyClassroomRosterListenerToken {}
    }

    func startStudentListener(
        classId: String,
        onChange: @escaping @MainActor ([ClassroomStudentSummary]) -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) -> ClassroomRosterListenerToken {
        #if canImport(FirebaseFirestore)
        if FirebaseAppConfigurator.hasBundledConfig {
            let bridge = ClassroomRosterRealtimeBridge(
                classId: classId,
                onChange: onChange,
                onError: onError
            )
            bridge.start()
            return AnyClassroomRosterListenerToken { bridge.cancel() }
        }
        #endif

        let task = Task { @MainActor in
            do {
                onChange(try await listStudents(classId: classId))
            } catch {
                onError(error)
            }
        }
        return AnyClassroomRosterListenerToken { task.cancel() }
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
        case "CLASSROOM_TOO_LARGE_TO_RENAME": return .classTooLarge
        case "VOLUNTEER_APPROVAL_REQUIRED": return .volunteerApprovalRequired
        case "VOLUNTEER_SERVICE_NOT_FOUND": return .volunteerRequestNotFound
        case "VOLUNTEER_SERVICE_ALREADY_REQUESTED": return .volunteerAlreadyRequested
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
private struct ClassroomStudentListResponse: Decodable { let students: [ClassroomStudentSummary] }
private struct ClassroomBootstrapResponse: Decodable { let migrated: Bool }
private struct ClassroomMutationResponse: Decodable { let classroom: ClassroomSummary }
private struct ClassroomLeaveResponse: Decodable { let classId: String; let left: Bool }
private struct ClassroomDeleteResponse: Decodable { let classId: String; let deleted: Bool }
private struct VolunteerServiceListResponse: Decodable { let services: [VolunteerServiceSummary] }
private struct VolunteerServiceMutationResponse: Decodable { let service: VolunteerServiceSummary }
private struct VolunteerServiceActionResponse: Decodable {
    let classId: String
    let volunteerUid: String
    let status: VolunteerServiceStatus
}
private struct VolunteerInviteCodeResponse: Decodable { let invitation: VolunteerInviteCodeSummary? }
private struct ClassroomErrorResponse: Decodable { let error: String }
