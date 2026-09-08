import XCTest
@testable import EnglishPlus

@MainActor
final class LearningRepositoryRepairTests: XCTestCase {
    private func withDefaults(_ test: (UserDefaults) throws -> Void) throws {
        let suite = "LearningRepositoryRepairTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try test(defaults)
    }

    func testWriteQueueSurvivesRestartAndRetriesFailedHeadBeforeLaterWrites() throws {
        try withDefaults { defaults in
            let scope = LearningMirrorWriteQueue.scope(uid: "student", classId: "A")
            let queue = LearningMirrorWriteQueue(defaults: defaults)
            let first = try LearningMirrorDocument(path: "missions/one", data: ["count": 1])
            let second = try LearningMirrorDocument(path: "missions/one", data: ["count": 2])
            queue.append([first], scope: scope)
            let head = try XCTUnwrap(queue.batches(scope: scope).first)
            queue.fail(id: head.id, scope: scope)
            queue.append([second], scope: scope)
            let restarted = LearningMirrorWriteQueue(defaults: defaults)
            XCTAssertTrue(restarted.hasFailure(scope: scope))
            XCTAssertEqual(restarted.batches(scope: scope).map(\.documents), [[first], [second]])
            restarted.retry(scope: scope)
            XCTAssertFalse(restarted.hasFailure(scope: scope))
            XCTAssertEqual(restarted.batches(scope: scope).first?.id, head.id)
            XCTAssertEqual(restarted.batches(scope: scope).first?.createdAt, head.createdAt)
            XCTAssertEqual(head.receiptData["operationId"] as? String, head.id.uuidString)
            XCTAssertEqual(head.receiptData["createdAt"] as? Date, head.createdAt)
            restarted.acknowledge(id: head.id, scope: scope)
            XCTAssertEqual(restarted.batches(scope: scope).map(\.documents), [[second]])
        }
    }

    func testDuplicateOrOutOfOrderCompletionCannotDropAnotherWrite() throws {
        try withDefaults { defaults in
            let scope = LearningMirrorWriteQueue.scope(uid: "student", classId: nil)
            let queue = LearningMirrorWriteQueue(defaults: defaults)
            let document = try LearningMirrorDocument(path: "missions/one", data: ["done": true])
            queue.append([document], scope: scope)
            queue.append([document], scope: scope)
            let batches = queue.batches(scope: scope)
            queue.acknowledge(id: batches[1].id, scope: scope)
            XCTAssertEqual(queue.batches(scope: scope).count, 2)
            queue.acknowledge(id: batches[0].id, scope: scope)
            queue.acknowledge(id: batches[0].id, scope: scope)
            XCTAssertEqual(queue.batches(scope: scope).map(\.id), [batches[1].id])
        }
    }

    func testEraseAllUIDScopesAndIgnoreLateCompletionWithoutErasingAnotherUID() throws {
        try withDefaults { defaults in
            let queue = LearningMirrorWriteQueue(defaults: defaults)
            let personal = LearningMirrorWriteQueue.scope(uid: "a", classId: nil)
            let classroom = LearningMirrorWriteQueue.scope(uid: "a", classId: "A")
            let other = LearningMirrorWriteQueue.scope(uid: "a-other", classId: "A")
            let document = try LearningMirrorDocument(path: "test", data: ["value": "private"])
            for scope in [personal, classroom, other] { queue.append([document], scope: scope) }
            let formerHead = try XCTUnwrap(queue.batches(scope: classroom).first)
            queue.clear(uid: "a")
            queue.fail(id: formerHead.id, scope: classroom)
            queue.acknowledge(id: formerHead.id, scope: classroom)
            let restarted = LearningMirrorWriteQueue(defaults: defaults)
            XCTAssertTrue(restarted.batches(scope: personal).isEmpty)
            XCTAssertTrue(restarted.batches(scope: classroom).isEmpty)
            XCTAssertEqual(restarted.batches(scope: other).count, 1)
        }
    }

    func testPersistedWriteValuesPreserveFirestoreTypesAndAtomicGroup() throws {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let document = try LearningMirrorDocument(path: "test", data: [
            "count": 1, "ratio": 0.5, "flag": true, "at": date, "empty": NSNull(),
            "nested": ["answers": ["a", "b"]],
        ], requiresExistingDocument: true)
        let decoded = try JSONDecoder().decode(LearningMirrorDocument.self, from: JSONEncoder().encode(document))
        XCTAssertEqual(document, decoded)
        XCTAssertEqual(decoded.data["count"] as? Int, 1)
        XCTAssertEqual(decoded.data["flag"] as? Bool, true)
        XCTAssertEqual(decoded.data["at"] as? Date, date)
        XCTAssertTrue(decoded.data["empty"] is NSNull)
        XCTAssertTrue(decoded.requiresExistingDocument)
        try withDefaults { defaults in
            let queue = LearningMirrorWriteQueue(defaults: defaults)
            let scope = LearningMirrorWriteQueue.scope(uid: "a", classId: nil)
            let event = try LearningMirrorDocument(path: "events/one", data: ["answer": "a"])
            queue.append([document, event], scope: scope)
            XCTAssertEqual(queue.batches(scope: scope).count, 1)
            XCTAssertEqual(queue.batches(scope: scope).first?.documents.count, 2)
        }
    }

    func testRepeatedAssignmentKeepsActiveIdentityAndReassignmentAfterWithdrawalGetsNewID() throws {
        try withDefaults { defaults in
            let repository = MockLearningRepository(now: { Date(timeIntervalSince1970: 1_800_000_000) }, localPersistence: UserDefaultsLearningPersistence(defaults: defaults))
            let set = try XCTUnwrap(repository.questionPracticeSets.first)
            let student = StaffStudentSummary(id: "s", studentUid: "s", studentName: "Student", classCode: "A", moodScore: nil, riskLevel: .low, missionProgress: "", nextAction: "")
            repository.assignPracticeSet(set, to: student, by: nil)
            let first = try XCTUnwrap(repository.assignedPracticeTasks.first)
            try repository.startAssignedPracticeTask(first)
            repository.assignPracticeSet(set, to: student, by: nil)
            XCTAssertEqual(repository.assignedPracticeTasks.count, 1)
            XCTAssertEqual(repository.assignedPracticeTasks.first?.id, first.id)
            XCTAssertEqual(repository.assignedPracticeTasks.first?.status, .active)
            try repository.withdrawAssignedPracticeTask(first.id)
            repository.assignPracticeSet(set, to: student, by: nil)
            XCTAssertEqual(repository.assignedPracticeTasks.count, 2)
            XCTAssertNotEqual(repository.assignedPracticeTasks.first?.id, first.id)
        }
    }

    func testFirebaseFallbackDoesNotReintroduceDuplicateAssignments() throws {
        try withDefaults { defaults in
            let fallback = MockLearningRepository(localPersistence: UserDefaultsLearningPersistence(defaults: defaults))
            let repository = FirebaseLearningRepository(fallback: fallback)
            let set = try XCTUnwrap(repository.questionPracticeSets.first)
            let student = StaffStudentSummary(id: "s", studentUid: "s", studentName: "Student", classCode: "A", moodScore: nil, riskLevel: .low, missionProgress: "", nextAction: "")
            repository.assignPracticeSet(set, to: student, by: nil)
            repository.assignPracticeSet(set, to: student, by: nil)
            XCTAssertEqual(repository.snapshot.assignedPracticeTasks.count, 1)
        }
    }

    func testAssignmentAcceptsNoncanonicalApprovedAnswer() throws {
        try withDefaults { defaults in
            let source = SeedData.current
            let item = QuestionBankItem(
                id: "repair-noncanonical-answer",
                level: .a1,
                unit: "字彙與語意",
                skill: "英美拼字",
                source: "English+ test fixture",
                reviewState: .approved,
                importBatchId: "learning-repository-repair-tests",
                updatedAt: Date(timeIntervalSince1970: 1_800_000_000),
                question: Question(
                    prompt: "Complete the word for a hue: ___.",
                    type: .fillBlank,
                    options: [],
                    answer: "color",
                    acceptedAnswers: ["color", "colour"],
                    explanation: "American and British spellings are both accepted.",
                    concept: "Equivalent regional spelling",
                    repairHint: "Either standard spelling is valid."
                )
            )
            let seed = SeedDataSnapshot(
                manifest: source.manifest,
                accounts: [],
                questionBankItems: [item],
                supportOptions: [],
                dailyMissionRules: source.dailyMissionRules
            )
            let repository = MockLearningRepository(
                seedSnapshot: seed,
                localPersistence: UserDefaultsLearningPersistence(defaults: defaults)
            )
            let alternative = try XCTUnwrap(item.question.acceptedAnswers.first { $0.lowercased() != item.question.answer.lowercased() })
            let date = Date(timeIntervalSince1970: 1_800_000_000)
            let assignment = TeacherAssignedPracticeTask(
                id: "assignment", classId: "A", studentUid: "s", studentName: "Student",
                setId: "test", setTitle: "Test", questionIds: [item.id],
                assignedByUid: "teacher", assignedByName: "Teacher", status: .active,
                createdAt: date, updatedAt: date
            )
            var snapshot = repository.snapshot
            snapshot.assignedPracticeTasks = [assignment]
            repository.replaceRuntimeSnapshot(snapshot)
            let result = try XCTUnwrap(repository.submitAssignedPracticeAnswer("  \(alternative.uppercased())  ", assignmentId: assignment.id))
            XCTAssertTrue(result.isCorrect)
            XCTAssertEqual(repository.assignedPracticeTasks.first?.status, .completed)
        }
    }

    func testClearingLocalLearningAlsoClearsMastery() throws {
        try withDefaults { defaults in
            let repository = MockLearningRepository(localPersistence: UserDefaultsLearningPersistence(defaults: defaults))
            let question = try XCTUnwrap(repository.questionBankItems.first)
            repository.recordPracticeAnswer(studentUid: "s", questionItem: question, isCorrect: false, source: .freePractice)
            XCTAssertFalse(repository.masteryRecords.isEmpty)
            repository.eraseLocalData(for: "s")
            XCTAssertTrue(repository.masteryRecords.isEmpty)
        }
    }

    func testIndependentMissionGenerationKeepsRoundAndRotationWithoutIDCollision() throws {
        try withDefaults { defaults in
            let date = Date(timeIntervalSince1970: 1_800_000_000)
            let repository = MockLearningRepository(now: { date }, localPersistence: UserDefaultsLearningPersistence(defaults: defaults))
            let initial = repository.snapshot
            repository.generateMission(for: nil, profile: nil, moodScore: 3, availableTimeLevel: 1, wantsChallenge: false, preferredQuestionTypes: [.fillBlank])
            let first = try XCTUnwrap(repository.currentMission)
            repository.replaceRuntimeSnapshot(initial)
            repository.generateMission(for: nil, profile: nil, moodScore: 3, availableTimeLevel: 1, wantsChallenge: false, preferredQuestionTypes: [.fillBlank])
            let second = try XCTUnwrap(repository.currentMission)
            XCTAssertEqual(first.studentUid, second.studentUid)
            XCTAssertEqual(first.dateKey, second.dateKey)
            XCTAssertEqual(first.questions.map(\.id), second.questions.map(\.id))
            XCTAssertEqual(LearningFlowState.roundNumber(fromMissionId: first.id, fallback: -1), 1)
            XCTAssertEqual(LearningFlowState.roundNumber(fromMissionId: second.id, fallback: -1), 1)
            XCTAssertNotEqual(first.id, second.id)
            let saved = repository.snapshot
            repository.replaceRuntimeSnapshot(saved)
            XCTAssertEqual(repository.currentMission?.id, second.id)
        }
    }

    func testIndependentDevicesCanSubmitSameMissionQuestionAttemptWithoutEventIDCollision() throws {
        try withDefaults { defaults in
            let date = Date(timeIntervalSince1970: 1_800_000_000)
            let firstDevice = MockLearningRepository(now: { date }, localPersistence: UserDefaultsLearningPersistence(defaults: defaults))
            firstDevice.generateMission(for: nil, profile: nil, moodScore: 3, availableTimeLevel: 1, wantsChallenge: false, preferredQuestionTypes: [.fillBlank])
            let restored = firstDevice.snapshot
            let answer = try XCTUnwrap(firstDevice.nextMissionQuestion).question.answer
            let first = try XCTUnwrap(firstDevice.submitMissionAnswer(answer))
            let secondDevice = MockLearningRepository(now: { date }, localPersistence: UserDefaultsLearningPersistence(defaults: defaults))
            secondDevice.replaceRuntimeSnapshot(restored)
            let second = try XCTUnwrap(secondDevice.submitMissionAnswer(answer))
            XCTAssertEqual(first.missionId, second.missionId)
            XCTAssertEqual(first.questionId, second.questionId)
            XCTAssertEqual(first.attemptNumber, second.attemptNumber)
            XCTAssertEqual(first.createdAt, second.createdAt)
            XCTAssertNotEqual(first.id, second.id)
        }
    }

    func testMasteryRebaseAddsOnlyThisAnswerToNewerServerProjection() throws {
        let item = try XCTUnwrap(SeedData.approvedQuestionBankItems.first)
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        var server: SkillMasteryRecord?
        for index in 0..<10 {
            server = SpacedRepetitionEngine.recording(
                existing: server, studentUid: "s", item: item, isCorrect: true,
                firstTryCorrect: true, source: .dailyMission, at: date.addingTimeInterval(Double(index))
            )
        }
        let current = try XCTUnwrap(server)
        let mutation = LearningMasteryMutation(studentUid: "s", item: item, isCorrect: true, firstTryCorrect: false, source: .teacherAssignment, answeredAt: date)
        let merged = try XCTUnwrap(mutation.rebased(over: current))
        XCTAssertEqual(merged.attemptCount, 11)
        XCTAssertEqual(merged.correctCount, 11)
        XCTAssertEqual(merged.firstTryCorrectCount, 10)
        XCTAssertEqual(merged.lastAttemptSource, .teacherAssignment)
        XCTAssertGreaterThan(merged.updatedAt, current.updatedAt)
        XCTAssertEqual(merged.updatedAt, merged.lastAnsweredAt)
        XCTAssertGreaterThanOrEqual(merged.nextReviewAt, merged.lastAnsweredAt)
        XCTAssertEqual(mutation.answeredAt, date)
        let firstTry = LearningMasteryMutation(studentUid: "s", item: item, isCorrect: true, firstTryCorrect: true, source: .freePractice, answeredAt: date)
        XCTAssertEqual(firstTry.rebased(over: current)?.firstTryCorrectCount, 11)
        let wrong = LearningMasteryMutation(studentUid: "s", item: item, isCorrect: false, firstTryCorrect: false, source: .repairPractice, answeredAt: date)
        XCTAssertEqual(wrong.rebased(over: current)?.correctCount, 10)
        XCTAssertEqual(wrong.rebased(over: current)?.consecutiveCorrectCount, 0)
        let otherOwner = LearningMasteryMutation(studentUid: "other", item: item, isCorrect: true, firstTryCorrect: true, source: .freePractice, answeredAt: date)
        XCTAssertNil(otherOwner.rebased(over: current))
    }

    func testRebasedHeadKeepsReceiptAndLaterOperationsAcrossRestart() throws {
        try withDefaults { defaults in
            let queue = LearningMirrorWriteQueue(defaults: defaults)
            let scope = LearningMirrorWriteQueue.scope(uid: "s", classId: nil)
            let item = try XCTUnwrap(SeedData.approvedQuestionBankItems.first)
            let mutation = LearningMasteryMutation(studentUid: "s", item: item, isCorrect: false, firstTryCorrect: false, source: .freePractice, answeredAt: Date())
            let old = try LearningMirrorDocument(path: "mastery/one", data: ["attemptCount": 1], masteryMutation: mutation)
            queue.append([old], scope: scope)
            queue.append([old], scope: scope)
            let original = try XCTUnwrap(queue.batches(scope: scope).first)
            let later = try XCTUnwrap(queue.batches(scope: scope).last)
            var replacement = original
            replacement.documents = [try LearningMirrorDocument(path: old.path, data: ["attemptCount": 11], masteryMutation: mutation)]
            XCTAssertTrue(queue.replaceHead(replacement, scope: scope))
            let restarted = LearningMirrorWriteQueue(defaults: defaults)
            XCTAssertEqual(restarted.batches(scope: scope).first, replacement)
            XCTAssertEqual(replacement.id, original.id)
            XCTAssertEqual(replacement.createdAt, original.createdAt)
            XCTAssertEqual(replacement.documents.first?.masteryMutation, mutation)
            XCTAssertEqual(restarted.batches(scope: scope).last, later)
            restarted.acknowledge(id: original.id, scope: scope)
            XCTAssertFalse(restarted.replaceHead(replacement, scope: scope))
            XCTAssertEqual(restarted.batches(scope: scope), [later])
        }
    }

    func testCompletedSupportMutationPreservesNewerReplyAndWithdrawal() throws {
        try withDefaults { defaults in
            let repository = MockLearningRepository(localPersistence: UserDefaultsLearningPersistence(defaults: defaults))
            var incoming = try XCTUnwrap(repository.supportRequests.first)
            let date = Date(timeIntervalSince1970: 1_800_000_000)
            incoming.updatedAt = date
            incoming.studentLastReadAt = date
            var current = incoming
            current.updatedAt = date.addingTimeInterval(10)
            current.withdrawnAt = current.updatedAt
            let reply = SupportReply(id: "new", authorUid: "teacher", authorName: "Teacher", authorRole: .teacher, body: "New reply", visibleToStudent: true, createdAt: current.updatedAt)
            current.replies.append(reply)
            let merged = FirebaseLearningRepository.mergingCompletedSupportMutation(incoming, with: current)
            XCTAssertEqual(merged.withdrawnAt, current.withdrawnAt)
            XCTAssertTrue(merged.replies.contains { $0.id == reply.id })
            XCTAssertEqual(merged.studentLastReadAt, date)
        }
    }
}
