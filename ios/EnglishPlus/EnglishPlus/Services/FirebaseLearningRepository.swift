import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class FirebaseLearningRepository: LearningRepositoryBackend {
    private let fallback: MockLearningRepository
    private var currentSnapshot: LearningRepositorySnapshot
    private var activeClassId: String?
    private var activeUserUid: String?

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

    var questionBankItems: [QuestionBankItem] {
        fallback.questionBankItems
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
        activeUserUid = user?.id
        normalizeCurrentSnapshotForToday()
        onChange(currentSnapshot)

        #if canImport(FirebaseFirestore)
        guard db != nil else {
            return AnyLearningRepositoryListenerToken {}
        }

        removeRealtimeRegistrations()
        listenSupportThreads(classId: classId, user: user, onChange: onChange, onError: onError)
        listenPracticeAssignments(classId: classId, user: user, onChange: onChange, onError: onError)
        listenStudentMissions(classId: classId, user: user, onChange: onChange, onError: onError)

        return AnyLearningRepositoryListenerToken { [weak self] in
            self?.removeRealtimeRegistrations()
            self?.activeClassId = nil
            self?.activeUserUid = nil
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
            updatedAt: Date(),
            completedFreePracticeSessionCount: currentSnapshot.learningFlow.completedFreePracticeSessionCount,
            lastFreePracticeCompletedAt: currentSnapshot.learningFlow.lastFreePracticeCompletedAt
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
            updatedAt: Date(),
            completedFreePracticeSessionCount: currentSnapshot.learningFlow.completedFreePracticeSessionCount,
            lastFreePracticeCompletedAt: currentSnapshot.learningFlow.lastFreePracticeCompletedAt
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
                updatedAt: Date(),
                completedFreePracticeSessionCount: currentSnapshot.learningFlow.completedFreePracticeSessionCount,
                lastFreePracticeCompletedAt: currentSnapshot.learningFlow.lastFreePracticeCompletedAt
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
            updatedAt: Date(),
            completedFreePracticeSessionCount: currentSnapshot.learningFlow.completedFreePracticeSessionCount,
            lastFreePracticeCompletedAt: currentSnapshot.learningFlow.lastFreePracticeCompletedAt
        )
    }

    func completeFreePracticeSession(correctCount: Int, totalCount: Int) {
        guard totalCount > 0 else { return }
        fallback.completeFreePracticeSession(correctCount: correctCount, totalCount: totalCount)
        currentSnapshot.learningFlow = currentSnapshot.learningFlow.recordingFreePracticeSessionCompleted(at: Date())
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
            .filter(\.isVisibleToStudent)
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

    func sendQuestionSupportRequest(
        from user: DemoUser?,
        profile: AppUserProfile?,
        option: SupportOption,
        questionItem: QuestionBankItem,
        selectedAnswer: String?,
        message: String
    ) {
        let preservingSupportRequests = currentSnapshot.supportRequests
        let preservingAssignedPracticeTasks = currentSnapshot.assignedPracticeTasks
        fallback.sendQuestionSupportRequest(
            from: user,
            profile: profile,
            option: option,
            questionItem: questionItem,
            selectedAnswer: selectedAnswer,
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
        let date = Date()
        currentSnapshot.supportRequests[index].status = .readByStudent
        currentSnapshot.supportRequests[index].studentLastReadAt = date
        currentSnapshot.supportRequests[index].updatedAt = date
        mirrorSupportRequestIfPossible(currentSnapshot.supportRequests[index])
    }

    func archiveSupportThreadForStudent(_ requestId: String) {
        guard let index = currentSnapshot.supportRequests.firstIndex(where: { $0.id == requestId }) else {
            return
        }
        let date = Date()
        currentSnapshot.supportRequests[index].studentArchivedAt = date
        if currentSnapshot.supportRequests[index].status == .replied {
            currentSnapshot.supportRequests[index].status = .readByStudent
            currentSnapshot.supportRequests[index].studentLastReadAt = date
        }
        currentSnapshot.supportRequests[index].updatedAt = date
        mirrorSupportRequestIfPossible(currentSnapshot.supportRequests[index])
    }

    func withdrawSupportRequest(_ requestId: String) {
        guard let index = currentSnapshot.supportRequests.firstIndex(where: { $0.id == requestId }) else {
            return
        }
        let date = Date()
        currentSnapshot.supportRequests[index].withdrawnAt = date
        currentSnapshot.supportRequests[index].studentArchivedAt = date
        currentSnapshot.supportRequests[index].status = .closed
        currentSnapshot.supportRequests[index].updatedAt = date
        mirrorSupportRequestIfPossible(currentSnapshot.supportRequests[index])
    }

    func markSupportThreadHandledWithoutReply(_ requestId: String, by staffUser: DemoUser?) {
        guard let index = currentSnapshot.supportRequests.firstIndex(where: { $0.id == requestId }) else {
            return
        }
        let date = Date()
        markStaffThreadHandled(at: index, date: date, by: staffUser)
        currentSnapshot.supportRequests[index].updatedAt = date
        mirrorSupportRequestIfPossible(currentSnapshot.supportRequests[index])
    }

    func archiveSupportThreadForStaff(_ requestId: String, by staffUser: DemoUser?) {
        guard let index = currentSnapshot.supportRequests.firstIndex(where: { $0.id == requestId }) else {
            return
        }
        let date = Date()
        archiveStaffThread(at: index, date: date, by: staffUser)
        currentSnapshot.supportRequests[index].updatedAt = date
        mirrorSupportRequestIfPossible(currentSnapshot.supportRequests[index])
    }

    private func markStaffThreadHandled(at index: Int, date: Date, by staffUser: DemoUser?) {
        currentSnapshot.supportRequests[index].status = .staffHandledNoReply
        currentSnapshot.supportRequests[index].handledWithoutReplyAt = date
        currentSnapshot.supportRequests[index].handledByUid = staffUser?.id
        currentSnapshot.supportRequests[index].handledByName = staffUser?.displayName
        currentSnapshot.supportRequests[index].handledByRole = staffUser?.role

        switch staffUser?.role {
        case .teacher?:
            currentSnapshot.supportRequests[index].teacherHandledWithoutReplyAt = date
        case .volunteer?:
            currentSnapshot.supportRequests[index].volunteerHandledWithoutReplyAt = date
        default:
            currentSnapshot.supportRequests[index].teacherHandledWithoutReplyAt = date
            currentSnapshot.supportRequests[index].volunteerHandledWithoutReplyAt = date
        }
    }

    private func archiveStaffThread(at index: Int, date: Date, by staffUser: DemoUser?) {
        currentSnapshot.supportRequests[index].handledByUid = staffUser?.id
        currentSnapshot.supportRequests[index].handledByName = staffUser?.displayName
        currentSnapshot.supportRequests[index].handledByRole = staffUser?.role

        switch staffUser?.role {
        case .teacher?:
            currentSnapshot.supportRequests[index].teacherArchivedAt = date
        case .volunteer?:
            currentSnapshot.supportRequests[index].volunteerArchivedAt = date
        default:
            currentSnapshot.supportRequests[index].teacherArchivedAt = date
            currentSnapshot.supportRequests[index].volunteerArchivedAt = date
        }

        if currentSnapshot.supportRequests[index].teacherArchivedAt != nil
            && currentSnapshot.supportRequests[index].volunteerArchivedAt != nil {
            currentSnapshot.supportRequests[index].status = .archived
            currentSnapshot.supportRequests[index].staffArchivedAt = date
        }
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
            .first {
                $0.studentUid == student.studentUid
                    && $0.setId == set.id
                    && ($0.status == .pending || $0.status == .active)
            }
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

    func withdrawAssignedPracticeTask(_ assignmentId: String) {
        let preservingSupportRequests = currentSnapshot.supportRequests
        let preservingAssignedPracticeTasks = currentSnapshot.assignedPracticeTasks
        fallback.withdrawAssignedPracticeTask(assignmentId)
        currentSnapshot = fallbackSnapshot(
            preservingSupportRequests: preservingSupportRequests,
            preservingAssignedPracticeTasks: preservingAssignedPracticeTasks
        )
        currentSnapshot.assignedPracticeTasks
            .first { $0.id == assignmentId }
            .map(mirrorPracticeAssignmentIfPossible)
    }

    private func mirrorCheckInAndMissionIfPossible(profile: AppUserProfile?) {
        guard let profile else { return }
        activeClassId = profile.activeClassId
        activeUserUid = profile.id
        if let checkIn = currentSnapshot.currentCheckIn {
            let path: String
            if let classId = profile.activeClassId {
                path = FirestorePath.checkIn(
                    classId: classId,
                    studentUid: checkIn.studentUid,
                    dateKey: checkIn.dateKey
                )
            } else {
                path = FirestorePath.personalCheckIn(
                    uid: profile.id,
                    dateKey: checkIn.dateKey
                )
            }
            setDocumentIfPossible(
                path: path,
                data: firestoreData(from: checkIn)
            )
        }
        mirrorMissionIfPossible()
    }

    private func mirrorMissionIfPossible() {
        guard let mission = currentSnapshot.currentMission else { return }
        let path: String
        if let activeClassId {
            path = FirestorePath.dailyMission(
                classId: activeClassId,
                studentUid: mission.studentUid,
                missionId: mission.id
            )
        } else if let activeUserUid {
            path = FirestorePath.personalDailyMission(
                uid: activeUserUid,
                missionId: mission.id
            )
        } else {
            return
        }
        setDocumentIfPossible(
            path: path,
            data: firestoreData(from: mission)
        )
    }

    private func mirrorAttemptIfPossible(_ attempt: MissionAttempt) {
        let studentUid = currentSnapshot.currentMission?.studentUid ?? "missing"
        let path: String
        if let activeClassId {
            path = FirestorePath.answerEvent(
                classId: activeClassId,
                studentUid: studentUid,
                eventId: attempt.id
            )
        } else if let activeUserUid {
            path = FirestorePath.personalAnswerEvent(
                uid: activeUserUid,
                eventId: attempt.id
            )
        } else {
            return
        }
        setDocumentIfPossible(
            path: path,
            data: firestoreData(from: attempt)
        )
    }

    private func mirrorUpdatedSupportRequestIfPossible(requestId: String) {
        guard let request = currentSnapshot.supportRequests.first(where: { $0.id == requestId }) else {
            return
        }
        guard !FirebaseBackendConfig.isPersonalScopeId(request.classCode) else { return }
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
        guard !FirebaseBackendConfig.isPersonalScopeId(request.classCode) else { return }
        setDocumentIfPossible(
            path: FirestorePath.supportThread(
                classId: request.classCode,
                threadId: request.id
            ),
            data: firestoreData(from: request)
        )
    }

    private func mirrorStudentSupportMessageIfPossible(_ request: StudentSupportRequest) {
        guard !FirebaseBackendConfig.isPersonalScopeId(request.classCode) else { return }
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
            path: FirestorePath.practiceAssignment(
                classId: assignment.classId,
                assignmentId: assignment.id
            ),
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
        var requestsById = Dictionary(
            existingSupportRequests.map { ($0.id, $0) },
            uniquingKeysWith: { existing, _ in existing }
        )
        for request in fallbackRequests {
            requestsById[request.id] = request
        }
        return requestsById.values.sorted { $0.updatedAt > $1.updatedAt }
    }

    private func mergedPracticeAssignments(
        _ fallbackAssignments: [TeacherAssignedPracticeTask],
        preservingAssignedPracticeTasks existingAssignments: [TeacherAssignedPracticeTask]
    ) -> [TeacherAssignedPracticeTask] {
        var assignmentsById = Dictionary(
            existingAssignments.map { ($0.id, $0) },
            uniquingKeysWith: { existing, _ in existing }
        )
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

    private func listenPracticeAssignments(
        classId: String,
        user: DemoUser?,
        onChange: @escaping @MainActor (LearningRepositorySnapshot) -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) {
        guard let db else { return }

        let assignmentsCollection = db.collection("\(FirestorePath.classDocument(classId: classId))/practiceAssignments")
        let assignmentsQuery: Query
        if user?.role == .student {
            assignmentsQuery = assignmentsCollection.whereField("studentUid", isEqualTo: user?.id ?? "")
        } else {
            assignmentsQuery = assignmentsCollection
        }

        let registration = assignmentsQuery.addSnapshotListener { [weak self] snapshot, error in
            if let error {
                Task { @MainActor in onError(error) }
                return
            }
            guard let documents = snapshot?.documents else { return }

            Task { @MainActor in
                guard let self else { return }
                let assignments = documents.compactMap { self.practiceAssignment(from: $0) }
                self.mergePracticeAssignments(assignments)
                onChange(self.currentSnapshot)
            }
        }
        registrations.append(registration)
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
            "classId": activeClassId.map { $0 as Any } ?? NSNull(),
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
            "classId": activeClassId.map { $0 as Any } ?? NSNull(),
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
            "studentVisible": request.isVisibleToStudent,
            "studentMessage": request.studentMessage,
            "moodScore": nullable(request.moodScore),
            "latestQuestionId": nullable(request.latestQuestionId),
            "questionSnapshot": request.questionSnapshot.map(firestoreData(from:)) ?? NSNull(),
            "studentArchivedAt": nullable(request.studentArchivedAt),
            "withdrawnAt": nullable(request.withdrawnAt),
            "staffArchivedAt": nullable(request.staffArchivedAt),
            "teacherArchivedAt": nullable(request.teacherArchivedAt),
            "volunteerArchivedAt": nullable(request.volunteerArchivedAt),
            "handledWithoutReplyAt": nullable(request.handledWithoutReplyAt),
            "teacherHandledWithoutReplyAt": nullable(request.teacherHandledWithoutReplyAt),
            "volunteerHandledWithoutReplyAt": nullable(request.volunteerHandledWithoutReplyAt),
            "handledByUid": nullable(request.handledByUid),
            "handledByName": nullable(request.handledByName),
            "handledByRole": request.handledByRole?.rawValue ?? NSNull(),
            "studentLastReadAt": nullable(request.studentLastReadAt),
            "latestMessagePreview": request.replies.last?.body ?? request.studentMessage,
            "createdAt": request.createdAt,
            "updatedAt": request.updatedAt,
        ]
    }

    private func firestoreData(from snapshot: SupportQuestionSnapshot) -> [String: Any] {
        [
            "questionId": snapshot.questionId,
            "prompt": snapshot.prompt,
            "options": snapshot.options,
            "questionTypeTitle": snapshot.questionTypeTitle,
            "levelTitle": snapshot.levelTitle,
            "skill": snapshot.skill,
            "selectedAnswer": nullable(snapshot.selectedAnswer),
            "correctAnswer": snapshot.correctAnswer,
            "explanation": snapshot.explanation,
            "repairHint": snapshot.repairHint,
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
            "questionResults": (assignment.questionResults ?? []).map { result in
                [
                    "id": result.id,
                    "questionId": result.questionId,
                    "prompt": result.prompt,
                    "selectedAnswer": result.selectedAnswer,
                    "acceptedAnswer": result.acceptedAnswer,
                    "isCorrect": result.isCorrect,
                    "explanation": result.explanation,
                    "repairHint": result.repairHint,
                    "answeredAt": result.answeredAt,
                ]
            },
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
        let existingById = Dictionary(
            currentSnapshot.supportRequests.map { ($0.id, $0) },
            uniquingKeysWith: { existing, _ in existing }
        )
        currentSnapshot.supportRequests = syncedRequests.map { request in
            var merged = request
            if let existing = existingById[request.id] {
                merged.replies = existing.replies
            }
            return merged
        }
        .sorted { $0.updatedAt > $1.updatedAt }
    }

    private func mergePracticeAssignments(_ syncedAssignments: [TeacherAssignedPracticeTask]) {
        let existingById = Dictionary(
            currentSnapshot.assignedPracticeTasks.map { ($0.id, $0) },
            uniquingKeysWith: { existing, _ in existing }
        )
        currentSnapshot.assignedPracticeTasks = syncedAssignments.map { assignment in
            var merged = assignment
            if let existing = existingById[assignment.id],
               assignment.questionResults == nil || assignment.questionResults?.isEmpty == true {
                merged.questionResults = existing.questionResults
            }
            return merged
        }
        .sorted { $0.updatedAt > $1.updatedAt }

        if let mission = currentSnapshot.currentMission,
           currentSnapshot.assignedPracticeTasks.contains(where: {
               $0.id == mission.sourceCheckInId && $0.status == .withdrawn
           }) {
            currentSnapshot.currentMission = nil
            currentSnapshot.missionAttempts = []
            currentSnapshot.learningFlow = .initial(dateKey: Self.dateKeyFormatter.string(from: Date()))
        }
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
        let itemsById = Dictionary(
            SeedData.approvedQuestionBankItems.map { ($0.id, $0) },
            uniquingKeysWith: { existing, _ in existing }
        )
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

    private func practiceAssignment(from document: QueryDocumentSnapshot) -> TeacherAssignedPracticeTask? {
        let data = document.data()
        guard
            let classId = data["classId"] as? String,
            let studentUid = data["studentUid"] as? String,
            let setId = data["setId"] as? String,
            let setTitle = data["setTitle"] as? String,
            let questionIds = data["questionIds"] as? [String],
            let assignedByUid = data["assignedByUid"] as? String,
            let assignedByName = data["assignedByName"] as? String
        else {
            return nil
        }

        let statusRaw = data["status"] as? String
        return TeacherAssignedPracticeTask(
            id: data["assignmentId"] as? String ?? document.documentID,
            classId: classId,
            studentUid: studentUid,
            studentName: data["studentName"] as? String ?? "學生",
            setId: setId,
            setTitle: setTitle,
            questionIds: questionIds,
            assignedByUid: assignedByUid,
            assignedByName: assignedByName,
            status: statusRaw.flatMap(PracticeAssignmentStatus.init(rawValue:)) ?? .pending,
            createdAt: firestoreDate(data["createdAt"]) ?? Date(),
            updatedAt: firestoreDate(data["updatedAt"]) ?? Date(),
            questionResults: practiceAssignmentResults(from: data["questionResults"])
        )
    }

    private func practiceAssignmentResults(from value: Any?) -> [PracticeAssignmentQuestionResult]? {
        guard let rawResults = value as? [[String: Any]] else { return nil }
        return rawResults.compactMap { rawResult in
            guard
                let questionId = rawResult["questionId"] as? String,
                let prompt = rawResult["prompt"] as? String,
                let selectedAnswer = rawResult["selectedAnswer"] as? String,
                let acceptedAnswer = rawResult["acceptedAnswer"] as? String,
                let isCorrect = rawResult["isCorrect"] as? Bool,
                let explanation = rawResult["explanation"] as? String,
                let repairHint = rawResult["repairHint"] as? String
            else {
                return nil
            }

            return PracticeAssignmentQuestionResult(
                id: rawResult["id"] as? String ?? questionId,
                questionId: questionId,
                prompt: prompt,
                selectedAnswer: selectedAnswer,
                acceptedAnswer: acceptedAnswer,
                isCorrect: isCorrect,
                explanation: explanation,
                repairHint: repairHint,
                answeredAt: firestoreDate(rawResult["answeredAt"]) ?? Date()
            )
        }
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
        let handledRoleRaw = data["handledByRole"] as? String
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
            questionSnapshot: supportQuestionSnapshot(from: data),
            studentArchivedAt: firestoreDate(data["studentArchivedAt"]),
            withdrawnAt: firestoreDate(data["withdrawnAt"]),
            staffArchivedAt: firestoreDate(data["staffArchivedAt"]),
            teacherArchivedAt: firestoreDate(data["teacherArchivedAt"]),
            volunteerArchivedAt: firestoreDate(data["volunteerArchivedAt"]),
            handledWithoutReplyAt: firestoreDate(data["handledWithoutReplyAt"]),
            teacherHandledWithoutReplyAt: firestoreDate(data["teacherHandledWithoutReplyAt"]),
            volunteerHandledWithoutReplyAt: firestoreDate(data["volunteerHandledWithoutReplyAt"]),
            handledByUid: data["handledByUid"] as? String,
            handledByName: data["handledByName"] as? String,
            handledByRole: handledRoleRaw.flatMap(UserRole.init(rawValue:)),
            studentLastReadAt: firestoreDate(data["studentLastReadAt"]),
            createdAt: firestoreDate(data["createdAt"]) ?? Date(),
            updatedAt: firestoreDate(data["updatedAt"]) ?? Date(),
            replies: []
        )
    }

    private func supportQuestionSnapshot(from data: [String: Any]) -> SupportQuestionSnapshot? {
        guard let rawSnapshot = data["questionSnapshot"] as? [String: Any] else {
            return nil
        }
        guard
            let questionId = rawSnapshot["questionId"] as? String,
            let prompt = rawSnapshot["prompt"] as? String,
            let correctAnswer = rawSnapshot["correctAnswer"] as? String,
            let explanation = rawSnapshot["explanation"] as? String,
            let repairHint = rawSnapshot["repairHint"] as? String
        else {
            return nil
        }

        return SupportQuestionSnapshot(
            questionId: questionId,
            prompt: prompt,
            options: rawSnapshot["options"] as? [String] ?? [],
            questionTypeTitle: rawSnapshot["questionTypeTitle"] as? String ?? "題目",
            levelTitle: rawSnapshot["levelTitle"] as? String ?? "練習",
            skill: rawSnapshot["skill"] as? String ?? "",
            selectedAnswer: rawSnapshot["selectedAnswer"] as? String,
            correctAnswer: correctAnswer,
            explanation: explanation,
            repairHint: repairHint
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
