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
    private var supportMessageRegistrations: [String: ListenerRegistration] = [:]
    private var studentAttemptRegistration: ListenerRegistration?
    #endif

    convenience init() {
        self.init(fallback: MockLearningRepository())
    }

    init(fallback: MockLearningRepository) {
        self.fallback = fallback
        currentSnapshot = Self.normalizedSnapshotForToday(fallback.snapshot)
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

    var questionPracticeSets: [QuestionPracticeSet] {
        fallback.questionPracticeSets
    }

    func refresh() async throws {
        currentSnapshot = fallback.snapshot
        normalizeCurrentSnapshotForToday()
    }

    func startRealtimeListener(
        classId: String,
        user: DemoUser?,
        onChange: @escaping @MainActor (LearningRepositorySnapshot) -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) -> LearningRepositoryListenerToken {
        activeClassId = classId
        normalizeCurrentSnapshotForToday()
        onChange(currentSnapshot)

        #if canImport(FirebaseFirestore)
        guard let db else {
            return AnyLearningRepositoryListenerToken {}
        }

        removeRealtimeRegistrations()
        listenSupportThreads(classId: classId, user: user, onChange: onChange, onError: onError)
        listenStudentMissions(classId: classId, user: user, onChange: onChange, onError: onError)

        return AnyLearningRepositoryListenerToken { [weak self] in
            self?.removeRealtimeRegistrations()
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
        preferredQuestionTypes: [QuestionType],
        aiMission: AiMissionOutput?
    ) {
        let preservingSupportRequests = currentSnapshot.supportRequests
        let preservingAssignedPracticeTasks = currentSnapshot.assignedPracticeTasks
        fallback.generateMission(
            for: user,
            profile: profile,
            moodScore: moodScore,
            availableTimeLevel: availableTimeLevel,
            wantsChallenge: wantsChallenge,
            preferredQuestionTypes: preferredQuestionTypes,
            aiMission: aiMission
        )
        currentSnapshot = fallbackSnapshot(
            preservingSupportRequests: preservingSupportRequests,
            preservingAssignedPracticeTasks: preservingAssignedPracticeTasks
        )
        mirrorCheckInAndMissionIfPossible(profile: profile)
    }

    func startNewLearningRound(for user: DemoUser?, profile: AppUserProfile?) {
        let preservingSupportRequests = currentSnapshot.supportRequests
        let preservingAssignedPracticeTasks = currentSnapshot.assignedPracticeTasks
        fallback.startNewLearningRound(for: user, profile: profile)
        currentSnapshot = fallbackSnapshot(
            preservingSupportRequests: preservingSupportRequests,
            preservingAssignedPracticeTasks: preservingAssignedPracticeTasks
        )
    }

    func continueLearningFlow() {
        normalizeCurrentSnapshotForToday()
        guard let mission = currentSnapshot.currentMission else {
            returnToMissionFlow()
            return
        }
        currentSnapshot.learningFlow = LearningFlowState(
            dateKey: mission.dateKey,
            roundNumber: LearningFlowState.roundNumber(
                fromMissionId: mission.id,
                fallback: currentSnapshot.learningFlow.roundNumber
            ),
            stage: mission.status == .completed ? .missionCompleted : .missionActive,
            activeMissionId: mission.id,
            continuation: nil,
            updatedAt: Date()
        )
    }

    func enterFreePracticeMode() {
        normalizeCurrentSnapshotForToday()
        currentSnapshot.learningFlow = LearningFlowState(
            dateKey: currentSnapshot.learningFlow.dateKey,
            roundNumber: currentSnapshot.learningFlow.roundNumber,
            stage: .freePractice,
            activeMissionId: currentSnapshot.currentMission?.id,
            continuation: LearningFlowState.continuation(
                from: currentSnapshot.currentMission,
                missionAttempts: currentSnapshot.missionAttempts,
                fallbackRoundNumber: currentSnapshot.learningFlow.roundNumber
            ) ?? currentSnapshot.learningFlow.continuation,
            updatedAt: Date()
        )
    }

    func returnToMissionFlow() {
        normalizeCurrentSnapshotForToday()
        guard let mission = currentSnapshot.currentMission else {
            currentSnapshot.learningFlow = LearningFlowState(
                dateKey: Self.dateKeyFormatter.string(from: Date()),
                roundNumber: max(currentSnapshot.learningFlow.roundNumber, 1),
                stage: .needsCheckIn,
                activeMissionId: nil,
                continuation: currentSnapshot.learningFlow.continuation,
                updatedAt: Date()
            )
            return
        }

        currentSnapshot.learningFlow = LearningFlowState(
            dateKey: mission.dateKey,
            roundNumber: LearningFlowState.roundNumber(
                fromMissionId: mission.id,
                fallback: currentSnapshot.learningFlow.roundNumber
            ),
            stage: mission.status == .completed ? .missionCompleted : .missionActive,
            activeMissionId: mission.id,
            continuation: LearningFlowState.continuation(
                from: mission,
                missionAttempts: currentSnapshot.missionAttempts,
                fallbackRoundNumber: currentSnapshot.learningFlow.roundNumber
            ),
            updatedAt: Date()
        )
    }

    func submitMissionAnswer(_ answer: String) -> MissionAttempt? {
        let preservingSupportRequests = currentSnapshot.supportRequests
        let preservingAssignedPracticeTasks = currentSnapshot.assignedPracticeTasks
        let attempt = fallback.submitMissionAnswer(answer)
        currentSnapshot = fallbackSnapshot(
            preservingSupportRequests: preservingSupportRequests,
            preservingAssignedPracticeTasks: preservingAssignedPracticeTasks
        )
        if let attempt {
            mirrorAttemptIfPossible(attempt)
            mirrorMissionIfPossible()
            currentSnapshot.assignedPracticeTasks
                .first { $0.id == currentSnapshot.currentMission?.sourceCheckInId }
                .map(mirrorPracticeAssignmentIfPossible)
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
        let preservingSupportRequests = currentSnapshot.supportRequests
        let preservingAssignedPracticeTasks = currentSnapshot.assignedPracticeTasks
        fallback.sendSupportRequest(
            from: user,
            profile: profile,
            option: option,
            message: message
        )
        currentSnapshot = fallbackSnapshot(
            preservingSupportRequests: preservingSupportRequests,
            preservingAssignedPracticeTasks: preservingAssignedPracticeTasks
        )
        if let request = currentSnapshot.supportRequests.first {
            mirrorSupportRequestIfPossible(request)
            mirrorStudentSupportMessageIfPossible(request)
        }
    }

    func addTeacherReply(to requestId: String, body: String) {
        appendSupportReply(
            to: requestId,
            authorUid: "demo-teacher-1",
            authorName: "老師",
            authorRole: .teacher,
            body: body
        )
    }

    func addVolunteerReply(to requestId: String, body: String) {
        appendSupportReply(
            to: requestId,
            authorUid: "demo-volunteer-1",
            authorName: "志工",
            authorRole: .volunteer,
            body: body
        )
    }

    func markSupportThreadReadByStudent(_ requestId: String) {
        guard let index = currentSnapshot.supportRequests.firstIndex(where: { $0.id == requestId }) else {
            return
        }
        guard currentSnapshot.supportRequests[index].status == .replied else { return }
        currentSnapshot.supportRequests[index].status = .readByStudent
        currentSnapshot.supportRequests[index].updatedAt = Date()
        mirrorSupportRequestIfPossible(currentSnapshot.supportRequests[index])
    }

    func assignPracticeSet(_ set: QuestionPracticeSet, to student: StaffStudentSummary, by teacher: DemoUser?) {
        let preservingSupportRequests = currentSnapshot.supportRequests
        let preservingAssignedPracticeTasks = currentSnapshot.assignedPracticeTasks
        fallback.assignPracticeSet(set, to: student, by: teacher)
        currentSnapshot = fallbackSnapshot(
            preservingSupportRequests: preservingSupportRequests,
            preservingAssignedPracticeTasks: preservingAssignedPracticeTasks
        )
        currentSnapshot.assignedPracticeTasks
            .first { $0.studentUid == student.studentUid && $0.setId == set.id && $0.status != .completed }
            .map(mirrorPracticeAssignmentIfPossible)
    }

    func startAssignedPracticeTask(_ assignment: TeacherAssignedPracticeTask) {
        let preservingSupportRequests = currentSnapshot.supportRequests
        let preservingAssignedPracticeTasks = currentSnapshot.assignedPracticeTasks
        fallback.startAssignedPracticeTask(assignment)
        currentSnapshot = fallbackSnapshot(
            preservingSupportRequests: preservingSupportRequests,
            preservingAssignedPracticeTasks: preservingAssignedPracticeTasks
        )
        currentSnapshot.assignedPracticeTasks
            .first { $0.id == assignment.id }
            .map(mirrorPracticeAssignmentIfPossible)
        mirrorMissionIfPossible()
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

    private func mirrorStudentSupportMessageIfPossible(_ request: StudentSupportRequest) {
        setDocumentIfPossible(
            path: FirestorePath.supportMessage(
                classId: request.classCode,
                threadId: request.id,
                messageId: "\(request.id)-student-request"
            ),
            data: firestoreData(fromStudentRequest: request)
        )
    }

    private func mirrorPracticeAssignmentIfPossible(_ assignment: TeacherAssignedPracticeTask) {
        setDocumentIfPossible(
            path: "\(FirestorePath.classDocument(classId: assignment.classId))/practiceAssignments/\(assignment.id)",
            data: firestoreData(from: assignment)
        )
    }

    private func appendSupportReply(
        to requestId: String,
        authorUid: String,
        authorName: String,
        authorRole: UserRole,
        body: String
    ) {
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBody.isEmpty else { return }
        guard let index = currentSnapshot.supportRequests.firstIndex(where: { $0.id == requestId }) else {
            return
        }
        let date = Date()
        let reply = SupportReply(
            id: "reply-\(date.timeIntervalSince1970)-\(requestId)",
            authorUid: authorUid,
            authorName: authorName,
            authorRole: authorRole,
            body: trimmedBody,
            visibleToStudent: true,
            createdAt: date
        )
        currentSnapshot.supportRequests[index].replies.append(reply)
        currentSnapshot.supportRequests[index].status = .replied
        currentSnapshot.supportRequests[index].updatedAt = date
        mirrorUpdatedSupportRequestIfPossible(requestId: requestId)
    }

    private static func normalizedSnapshotForToday(
        _ snapshot: LearningRepositorySnapshot,
        now: Date = Date()
    ) -> LearningRepositorySnapshot {
        var normalized = snapshot
        normalized.learningFlow = LearningFlowState.normalizedForToday(
            todayKey: Self.dateKeyFormatter.string(from: now),
            currentMission: normalized.currentMission,
            missionAttempts: normalized.missionAttempts,
            storedFlow: normalized.learningFlow,
            updatedAt: now
        )
        return normalized
    }

    private func fallbackSnapshot(
        preservingSupportRequests existingSupportRequests: [StudentSupportRequest],
        preservingAssignedPracticeTasks existingAssignedPracticeTasks: [TeacherAssignedPracticeTask]? = nil
    ) -> LearningRepositorySnapshot {
        var snapshot = fallback.snapshot
        snapshot.supportRequests = mergedSupportRequests(
            snapshot.supportRequests,
            preservingSupportRequests: existingSupportRequests
        )
        snapshot.assignedPracticeTasks = mergedPracticeAssignments(
            snapshot.assignedPracticeTasks,
            preservingAssignedPracticeTasks: existingAssignedPracticeTasks ?? currentSnapshot.assignedPracticeTasks
        )
        return Self.normalizedSnapshotForToday(snapshot)
    }

    private func mergedSupportRequests(
        _ fallbackRequests: [StudentSupportRequest],
        preservingSupportRequests existingSupportRequests: [StudentSupportRequest]
    ) -> [StudentSupportRequest] {
        var requestsById = Dictionary(uniqueKeysWithValues: existingSupportRequests.map { ($0.id, $0) })
        for request in fallbackRequests {
            requestsById[request.id] = request
        }
        return requestsById.values.sorted { $0.updatedAt > $1.updatedAt }
    }

    private func mergedPracticeAssignments(
        _ fallbackAssignments: [TeacherAssignedPracticeTask],
        preservingAssignedPracticeTasks existingAssignments: [TeacherAssignedPracticeTask]
    ) -> [TeacherAssignedPracticeTask] {
        var assignmentsById = Dictionary(uniqueKeysWithValues: existingAssignments.map { ($0.id, $0) })
        for assignment in fallbackAssignments {
            assignmentsById[assignment.id] = assignment
        }
        return assignmentsById.values.sorted { $0.updatedAt > $1.updatedAt }
    }

    private func normalizeCurrentSnapshotForToday() {
        currentSnapshot = Self.normalizedSnapshotForToday(currentSnapshot)
        if currentSnapshot.learningFlow.stage == .needsCheckIn {
            return
        }
    }

    private func setDocumentIfPossible(path: String, data: [String: Any]) {
        #if canImport(FirebaseFirestore)
        db?.document(path).setData(data, merge: true)
        #endif
    }

    #if canImport(FirebaseFirestore)
    private func removeRealtimeRegistrations() {
        registrations.forEach { $0.remove() }
        registrations = []
        supportMessageRegistrations.values.forEach { $0.remove() }
        supportMessageRegistrations = [:]
        studentAttemptRegistration?.remove()
        studentAttemptRegistration = nil
    }

    private func listenSupportThreads(
        classId: String,
        user: DemoUser?,
        onChange: @escaping @MainActor (LearningRepositorySnapshot) -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) {
        guard let db else { return }

        let supportQuery: Query
        switch user?.role {
        case .student:
            supportQuery = db.collection("\(FirestorePath.classDocument(classId: classId))/supportThreads")
                .whereField("studentUid", isEqualTo: user?.id ?? "")
        case .volunteer:
            supportQuery = db.collection("\(FirestorePath.classDocument(classId: classId))/supportThreads")
        case .teacher, nil:
            supportQuery = db.collection("\(FirestorePath.classDocument(classId: classId))/supportThreads")
        }

        let registration = supportQuery.addSnapshotListener { [weak self] snapshot, error in
            if let error {
                Task { @MainActor in onError(error) }
                return
            }
            guard let documents = snapshot?.documents else { return }

            Task { @MainActor in
                guard let self else { return }
                let syncedRequests = documents.compactMap { self.supportRequest(from: $0) }
                self.mergeSupportRequests(syncedRequests)
                self.listenSupportMessages(
                    classId: classId,
                    requests: syncedRequests,
                    onChange: onChange,
                    onError: onError
                )
                onChange(self.currentSnapshot)
            }
        }
        registrations.append(registration)
    }

    private func listenSupportMessages(
        classId: String,
        requests: [StudentSupportRequest],
        onChange: @escaping @MainActor (LearningRepositorySnapshot) -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) {
        guard let db else { return }

        let requestIds = Set(requests.map(\.id))
        supportMessageRegistrations
            .filter { !requestIds.contains($0.key) }
            .forEach { entry in
                entry.value.remove()
                supportMessageRegistrations[entry.key] = nil
            }

        for request in requests where supportMessageRegistrations[request.id] == nil {
            let path = "\(FirestorePath.supportThread(classId: classId, threadId: request.id))/messages"
            let registration = db.collection(path).addSnapshotListener { [weak self] snapshot, error in
                if let error {
                    Task { @MainActor in onError(error) }
                    return
                }
                guard let documents = snapshot?.documents else { return }

                Task { @MainActor in
                    guard let self,
                          let index = self.currentSnapshot.supportRequests.firstIndex(where: { $0.id == request.id })
                    else { return }
                    let replies = documents
                        .compactMap { self.supportReply(from: $0) }
                        .filter(\.visibleToStudent)
                        .sorted { $0.createdAt < $1.createdAt }
                    self.currentSnapshot.supportRequests[index].replies = replies
                    if let latestReplyDate = replies.last?.createdAt {
                        self.currentSnapshot.supportRequests[index].updatedAt = latestReplyDate
                    }
                    onChange(self.currentSnapshot)
                }
            }
            supportMessageRegistrations[request.id] = registration
        }
    }

    private func listenStudentMissions(
        classId: String,
        user: DemoUser?,
        onChange: @escaping @MainActor (LearningRepositorySnapshot) -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) {
        guard let db, let user, user.role == .student else { return }

        let path = "\(FirestorePath.student(classId: classId, studentUid: user.id))/dailyMissions"
        let registration = db.collection(path).addSnapshotListener { [weak self] snapshot, error in
            if let error {
                Task { @MainActor in onError(error) }
                return
            }
            guard let documents = snapshot?.documents else { return }

            Task { @MainActor in
                guard let self else { return }
                let missions = documents.compactMap { self.mission(from: $0, studentUid: user.id) }
                    .sorted { $0.createdAt > $1.createdAt }
                self.replaceMission(missions.first)
                self.listenStudentAttempts(
                    classId: classId,
                    studentUid: user.id,
                    missionId: missions.first?.id,
                    onChange: onChange,
                    onError: onError
                )
                onChange(self.currentSnapshot)
            }
        }
        registrations.append(registration)
    }

    private func listenStudentAttempts(
        classId: String,
        studentUid: String,
        missionId: String?,
        onChange: @escaping @MainActor (LearningRepositorySnapshot) -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) {
        guard let db, let missionId else {
            replaceAttempts([])
            return
        }

        studentAttemptRegistration?.remove()
        let path = "\(FirestorePath.student(classId: classId, studentUid: studentUid))/answerEvents"
        studentAttemptRegistration = db.collection(path)
            .whereField("missionId", isEqualTo: missionId)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error {
                    Task { @MainActor in onError(error) }
                    return
                }
                guard let documents = snapshot?.documents else { return }

                Task { @MainActor in
                    guard let self else { return }
                    let attempts = documents
                        .compactMap { self.attempt(from: $0, missionId: missionId) }
                        .sorted { $0.createdAt < $1.createdAt }
                    self.replaceAttempts(attempts)
                    onChange(self.currentSnapshot)
                }
            }
    }
    #endif

    private func firestoreData(from checkIn: MoodCheckIn) -> [String: Any] {
        [
            "dateKey": checkIn.dateKey,
            "classId": activeClassId,
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
            "classId": activeClassId,
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
            "prompt": attempt.prompt,
            "studentAnswer": attempt.selectedAnswer,
            "acceptedAnswer": attempt.acceptedAnswer,
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

    private func firestoreData(from assignment: TeacherAssignedPracticeTask) -> [String: Any] {
        [
            "assignmentId": assignment.id,
            "classId": assignment.classId,
            "studentUid": assignment.studentUid,
            "studentName": assignment.studentName,
            "setId": assignment.setId,
            "setTitle": assignment.setTitle,
            "questionIds": assignment.questionIds,
            "assignedByUid": assignment.assignedByUid,
            "assignedByName": assignment.assignedByName,
            "status": assignment.status.rawValue,
            "createdAt": assignment.createdAt,
            "updatedAt": assignment.updatedAt,
        ]
    }

    private func firestoreData(fromStudentRequest request: StudentSupportRequest) -> [String: Any] {
        [
            "messageId": "\(request.id)-student-request",
            "authorUid": request.studentUid,
            "authorName": request.studentName,
            "authorRole": UserRole.student.rawValue,
            "body": request.studentMessage,
            "visibility": MessageVisibility.studentVisible.rawValue,
            "messageType": SupportMessageType.studentRequest.rawValue,
            "createdAt": request.createdAt,
        ]
    }

    #if canImport(FirebaseFirestore)
    private func mission(from document: QueryDocumentSnapshot, studentUid: String) -> DailyMission? {
        let data = document.data()
        let questionIds = data["questionIds"] as? [String] ?? []
        let questions = questionBankItems(for: questionIds)
        let trackRaw = data["track"] as? String
        let statusRaw = data["status"] as? String
        let completedAt = firestoreDate(data["completedAt"])
        let status = statusRaw.flatMap(MissionStatus.init(rawValue:)) ?? .active

        return DailyMission(
            id: data["missionId"] as? String ?? document.documentID,
            studentUid: data["studentUid"] as? String ?? studentUid,
            dateKey: data["dateKey"] as? String ?? Self.dateKeyFormatter.string(from: Date()),
            sourceCheckInId: data["sourceCheckInId"] as? String ?? "",
            track: trackRaw.flatMap(MissionTrack.init(rawValue:)) ?? .steady,
            targetCorrectCount: data["targetCorrectCount"] as? Int ?? max(questions.count, 1),
            recommendedMinutes: data["recommendedMinutes"] as? Int ?? 5,
            questions: questions,
            createdAt: firestoreDate(data["createdAt"]) ?? Date(),
            completedAt: status == .completed ? completedAt ?? Date() : completedAt
        )
    }

    private func attempt(from document: QueryDocumentSnapshot, missionId: String) -> MissionAttempt? {
        let data = document.data()
        guard
            let questionId = data["questionId"] as? String,
            let selectedAnswer = data["studentAnswer"] as? String,
            let isCorrect = data["isCorrect"] as? Bool
        else {
            return nil
        }

        let question = SeedData.approvedQuestionBankItems
            .first { $0.id == questionId }?
            .question

        return MissionAttempt(
            id: data["eventId"] as? String ?? document.documentID,
            missionId: data["missionId"] as? String ?? missionId,
            questionId: questionId,
            prompt: data["prompt"] as? String ?? question?.prompt ?? "",
            selectedAnswer: selectedAnswer,
            acceptedAnswer: data["acceptedAnswer"] as? String ?? question?.answer ?? "",
            isCorrect: isCorrect,
            attemptNumber: data["attemptNumber"] as? Int ?? 1,
            explanation: data["aiExplanation"] as? String ?? question?.explanation ?? "",
            repairHint: data["repairHint"] as? String ?? question?.repairHint ?? "",
            createdAt: firestoreDate(data["createdAt"]) ?? Date()
        )
    }

    private func supportReply(from document: QueryDocumentSnapshot) -> SupportReply? {
        let data = document.data()
        guard
            let authorUid = data["authorUid"] as? String,
            let roleRaw = data["authorRole"] as? String,
            let authorRole = UserRole(rawValue: roleRaw),
            let body = data["body"] as? String
        else {
            return nil
        }

        let visibilityRaw = data["visibility"] as? String
        let visibility = visibilityRaw.flatMap(MessageVisibility.init(rawValue:)) ?? .studentVisible
        return SupportReply(
            id: data["messageId"] as? String ?? document.documentID,
            authorUid: authorUid,
            authorName: data["authorName"] as? String ?? authorRole.title,
            authorRole: authorRole,
            body: body,
            visibleToStudent: visibility == .studentVisible,
            createdAt: firestoreDate(data["createdAt"]) ?? Date()
        )
    }

    private func mergeSupportRequests(_ syncedRequests: [StudentSupportRequest]) {
        let existingById = Dictionary(uniqueKeysWithValues: currentSnapshot.supportRequests.map { ($0.id, $0) })
        currentSnapshot.supportRequests = syncedRequests.map { request in
            var merged = request
            if let existing = existingById[request.id] {
                merged.replies = existing.replies
            }
            return merged
        }
        .sorted { $0.updatedAt > $1.updatedAt }
    }

    private func replaceMission(_ mission: DailyMission?) {
        currentSnapshot.currentMission = mission
        normalizeCurrentSnapshotForToday()
    }

    private func replaceAttempts(_ attempts: [MissionAttempt]) {
        currentSnapshot.missionAttempts = attempts
        normalizeCurrentSnapshotForToday()
    }

    private func questionBankItems(for ids: [String]) -> [QuestionBankItem] {
        let itemsById = Dictionary(uniqueKeysWithValues: SeedData.approvedQuestionBankItems.map { ($0.id, $0) })
        return ids.compactMap { itemsById[$0] }
    }

    private func firestoreDate(_ value: Any?) -> Date? {
        if let date = value as? Date {
            return date
        }
        if let timestamp = value as? Timestamp {
            return timestamp.dateValue()
        }
        return nil
    }

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
            createdAt: firestoreDate(data["createdAt"]) ?? Date(),
            updatedAt: firestoreDate(data["updatedAt"]) ?? Date(),
            replies: []
        )
    }
    #endif

    private static let dateKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
