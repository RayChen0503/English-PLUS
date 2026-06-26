import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class FirebaseLearningRepository: LearningRepositoryBackend {
    private let fallback: MockLearningRepository
    private var currentSnapshot: LearningRepositorySnapshot
    private var activeClassId = FirebaseBackendConfig.firstClassId

    #if canImport(FirebaseFirestore)
    private let db: Firestore?
    private var registrations: [ListenerRegistration] = []
    #endif

    convenience init() {
        self.init(fallback: MockLearningRepository())
    }

    init(fallback: MockLearningRepository) {
        self.fallback = fallback
        currentSnapshot = fallback.snapshot
        #if canImport(FirebaseFirestore)
        db = FirebaseAppConfigurator.hasBundledConfig ? Firestore.firestore() : nil
        #endif
    }

    var snapshot: LearningRepositorySnapshot {
        currentSnapshot
    }

    var supportedQuestionTypes: [QuestionType] {
        fallback.supportedQuestionTypes
    }

    var defaultPreferredQuestionTypes: [QuestionType] {
        fallback.defaultPreferredQuestionTypes
    }

    func refresh() async throws {
        currentSnapshot = fallback.snapshot
    }

    func startRealtimeListener(
        classId: String,
        user: DemoUser?,
        onChange: @escaping @MainActor (LearningRepositorySnapshot) -> Void
    ) -> LearningRepositoryListenerToken {
        activeClassId = classId
        onChange(currentSnapshot)

        #if canImport(FirebaseFirestore)
        guard let db else {
            return AnyLearningRepositoryListenerToken {}
        }

        registrations.forEach { $0.remove() }
        registrations = []

        let supportQuery: Query
        switch user?.role {
        case .student:
            supportQuery = db.collection("\(FirestorePath.classDocument(classId: classId))/supportThreads")
                .whereField("studentUid", isEqualTo: user?.id ?? "")
        case .volunteer:
            supportQuery = db.collection("\(FirestorePath.classDocument(classId: classId))/supportThreads")
                .whereField("assignedToUid", isEqualTo: user?.id ?? "")
        case .teacher, nil:
            supportQuery = db.collection("\(FirestorePath.classDocument(classId: classId))/supportThreads")
        }

        let registration = supportQuery.addSnapshotListener { [weak self] snapshot, error in
            guard error == nil, let documents = snapshot?.documents else { return }
            Task { @MainActor in
                guard let self else { return }
                let syncedRequests = documents.compactMap { document in
                    self.supportRequest(from: document)
                }
                if !syncedRequests.isEmpty {
                    self.currentSnapshot.supportRequests = syncedRequests.sorted { $0.updatedAt > $1.updatedAt }
                    onChange(self.currentSnapshot)
                }
            }
        }
        registrations.append(registration)

        return AnyLearningRepositoryListenerToken { [weak self] in
            self?.registrations.forEach { $0.remove() }
            self?.registrations = []
        }
        #else
        return AnyLearningRepositoryListenerToken {}
        #endif
    }

    func generateMission(
        for user: DemoUser?,
        profile: AppUserProfile?,
        moodScore: Int,
        availableTimeLevel: Int,
        wantsChallenge: Bool,
        preferredQuestionTypes: [QuestionType]
    ) {
        fallback.generateMission(
            for: user,
            profile: profile,
            moodScore: moodScore,
            availableTimeLevel: availableTimeLevel,
            wantsChallenge: wantsChallenge,
            preferredQuestionTypes: preferredQuestionTypes
        )
        currentSnapshot = fallback.snapshot
        mirrorCheckInAndMissionIfPossible(profile: profile)
    }

    func submitMissionAnswer(_ answer: String) -> MissionAttempt? {
        let attempt = fallback.submitMissionAnswer(answer)
        currentSnapshot = fallback.snapshot
        if let attempt {
            mirrorAttemptIfPossible(attempt)
            mirrorMissionIfPossible()
        }
        return attempt
    }

    func supportRequests(forStudentUid studentUid: String?) -> [StudentSupportRequest] {
        guard let studentUid else { return [] }
        return currentSnapshot.supportRequests
            .filter { $0.studentUid == studentUid }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func sendSupportRequest(
        from user: DemoUser?,
        profile: AppUserProfile?,
        option: SupportOption,
        message: String? = nil
    ) {
        fallback.sendSupportRequest(
            from: user,
            profile: profile,
            option: option,
            message: message
        )
        currentSnapshot = fallback.snapshot
        if let request = currentSnapshot.supportRequests.first {
            mirrorSupportRequestIfPossible(request)
        }
    }

    func addTeacherReply(to requestId: String, body: String) {
        fallback.addTeacherReply(to: requestId, body: body)
        currentSnapshot = fallback.snapshot
        mirrorUpdatedSupportRequestIfPossible(requestId: requestId)
    }

    func addVolunteerReply(to requestId: String, body: String) {
        fallback.addVolunteerReply(to: requestId, body: body)
        currentSnapshot = fallback.snapshot
        mirrorUpdatedSupportRequestIfPossible(requestId: requestId)
    }

    private func mirrorCheckInAndMissionIfPossible(profile: AppUserProfile?) {
        guard let profile else { return }
        activeClassId = profile.classId
        if let checkIn = currentSnapshot.currentCheckIn {
            setDocumentIfPossible(
                path: FirestorePath.checkIn(
                    classId: profile.classId,
                    studentUid: checkIn.studentUid,
                    dateKey: checkIn.dateKey
                ),
                data: firestoreData(from: checkIn)
            )
        }
        mirrorMissionIfPossible()
    }

    private func mirrorMissionIfPossible() {
        guard let mission = currentSnapshot.currentMission else { return }
        setDocumentIfPossible(
            path: FirestorePath.dailyMission(
                classId: activeClassId,
                studentUid: mission.studentUid,
                missionId: mission.id
            ),
            data: firestoreData(from: mission)
        )
    }

    private func mirrorAttemptIfPossible(_ attempt: MissionAttempt) {
        let studentUid = currentSnapshot.currentMission?.studentUid ?? "missing"
        setDocumentIfPossible(
            path: FirestorePath.answerEvent(
                classId: activeClassId,
                studentUid: studentUid,
                eventId: attempt.id
            ),
            data: firestoreData(from: attempt)
        )
    }

    private func mirrorUpdatedSupportRequestIfPossible(requestId: String) {
        guard let request = currentSnapshot.supportRequests.first(where: { $0.id == requestId }) else {
            return
        }
        mirrorSupportRequestIfPossible(request)
        request.replies.forEach { reply in
            setDocumentIfPossible(
                path: FirestorePath.supportMessage(
                    classId: request.classCode,
                    threadId: request.id,
                    messageId: reply.id
                ),
                data: firestoreData(from: reply)
            )
        }
    }

    private func mirrorSupportRequestIfPossible(_ request: StudentSupportRequest) {
        setDocumentIfPossible(
            path: FirestorePath.supportThread(
                classId: request.classCode,
                threadId: request.id
            ),
            data: firestoreData(from: request)
        )
    }

    private func setDocumentIfPossible(path: String, data: [String: Any]) {
        #if canImport(FirebaseFirestore)
        db?.document(path).setData(data, merge: true)
        #endif
    }

    private func firestoreData(from checkIn: MoodCheckIn) -> [String: Any] {
        [
            "dateKey": checkIn.dateKey,
            "studentUid": checkIn.studentUid,
            "moodScore": checkIn.moodScore,
            "availableTimeLevel": checkIn.availableTimeLevel,
            "wantsChallenge": checkIn.wantsChallenge,
            "preferredQuestionTypes": checkIn.preferredQuestionTypes.map(\.rawValue),
            "recommendedMinutes": checkIn.recommendedMinutes,
            "createdAt": checkIn.createdAt,
        ]
    }

    private func firestoreData(from mission: DailyMission) -> [String: Any] {
        let correctCount = currentSnapshot.missionAttempts
            .filter { $0.isCorrect }
            .map(\.questionId)
            .uniqued()
            .count
        return [
            "missionId": mission.id,
            "dateKey": mission.dateKey,
            "studentUid": mission.studentUid,
            "sourceCheckInId": mission.sourceCheckInId,
            "status": mission.status.rawValue,
            "track": mission.track.rawValue,
            "targetCorrectCount": mission.targetCorrectCount,
            "correctCount": correctCount,
            "progressPercent": mission.targetCorrectCount == 0 ? 0 : Int(Double(correctCount) / Double(mission.targetCorrectCount) * 100),
            "recommendedMinutes": mission.recommendedMinutes,
            "questionIds": mission.questions.map(\.id),
            "createdAt": mission.createdAt,
            "completedAt": nullable(mission.completedAt),
        ]
    }

    private func firestoreData(from attempt: MissionAttempt) -> [String: Any] {
        [
            "eventId": attempt.id,
            "questionId": attempt.questionId,
            "missionId": attempt.missionId,
            "studentAnswer": attempt.selectedAnswer,
            "isCorrect": attempt.isCorrect,
            "attemptNumber": attempt.attemptNumber,
            "aiExplanation": attempt.explanation,
            "repairHint": attempt.repairHint,
            "createdAt": attempt.createdAt,
        ]
    }

    private func firestoreData(from request: StudentSupportRequest) -> [String: Any] {
        [
            "threadId": request.id,
            "studentUid": request.studentUid,
            "studentName": request.studentName,
            "classId": request.classCode,
            "status": request.status.rawValue,
            "reason": request.reason.rawValue,
            "route": request.route.rawValue,
            "priority": request.priority.rawValue,
            "assignedToUid": NSNull(),
            "assignedRole": NSNull(),
            "studentVisible": true,
            "studentMessage": request.studentMessage,
            "moodScore": nullable(request.moodScore),
            "latestQuestionId": nullable(request.latestQuestionId),
            "latestMessagePreview": request.replies.last?.body ?? request.studentMessage,
            "createdAt": request.createdAt,
            "updatedAt": request.updatedAt,
        ]
    }

    private func nullable<T>(_ value: T?) -> Any {
        guard let value else { return NSNull() }
        return value
    }

    private func firestoreData(from reply: SupportReply) -> [String: Any] {
        [
            "messageId": reply.id,
            "authorUid": reply.authorUid,
            "authorName": reply.authorName,
            "authorRole": reply.authorRole.rawValue,
            "body": reply.body,
            "visibility": reply.visibleToStudent ? MessageVisibility.studentVisible.rawValue : MessageVisibility.staffOnly.rawValue,
            "messageType": reply.authorRole == .teacher ? SupportMessageType.teacherReply.rawValue : SupportMessageType.volunteerReply.rawValue,
            "createdAt": reply.createdAt,
        ]
    }

    #if canImport(FirebaseFirestore)
    private func supportRequest(from document: QueryDocumentSnapshot) -> StudentSupportRequest? {
        let data = document.data()
        guard
            let studentUid = data["studentUid"] as? String,
            let classId = data["classId"] as? String,
            let statusRaw = data["status"] as? String,
            let status = SupportThreadStatus(rawValue: statusRaw),
            let reasonRaw = data["reason"] as? String,
            let reason = SupportReason(rawValue: reasonRaw),
            let priorityRaw = data["priority"] as? String,
            let priority = RiskLevel(rawValue: priorityRaw)
        else {
            return nil
        }

        let routeRaw = data["route"] as? String
        let route = routeRaw.flatMap(SupportRoute.init(rawValue:)) ?? .humanHandoff
        return StudentSupportRequest(
            id: document.documentID,
            studentUid: studentUid,
            studentName: data["studentName"] as? String ?? "學生",
            classCode: classId,
            reason: reason,
            route: route,
            priority: priority,
            status: status,
            studentMessage: data["studentMessage"] as? String ?? data["latestMessagePreview"] as? String ?? "",
            moodScore: data["moodScore"] as? Int,
            latestQuestionId: data["latestQuestionId"] as? String,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date(),
            replies: []
        )
    }
    #endif
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
