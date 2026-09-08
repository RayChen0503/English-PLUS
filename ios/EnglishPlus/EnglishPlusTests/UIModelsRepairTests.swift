import XCTest
@testable import EnglishPlus

final class UIModelsRepairTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_800_000_000)

    private func item(_ id: String, prompt: String = "Tom has lived here ___ 2020.", skill: String = "時間介系詞") -> QuestionBankItem {
        QuestionBankItem(
            id: id, level: .a2, unit: "文法", skill: skill,
            source: "test", reviewState: .approved, importBatchId: "test", updatedAt: date,
            question: Question(
                prompt: prompt, type: .fillBlank, options: ["since", "for", "until", "during"],
                answer: "since", acceptedAnswers: ["since"], explanation: "時間起點用 since",
                concept: "time", repairHint: "找時間起點"
            )
        )
    }

    private func draft(_ items: [QuestionBankItem], index: Int = 0) -> PracticeSessionDraft {
        PracticeSessionDraft(
            questionIds: items.map(\.id), index: index, answer: "for",
            result: PracticeResult(isCorrect: false, acceptedAnswer: "since", explanation: "時間起點", repairHint: "再看年份"),
            sourceTitle: "test", selectionNote: nil,
            optionOrderByQuestionId: Dictionary(items.map { ($0.id, $0.question.options) }, uniquingKeysWith: { first, _ in first }),
            answeredCount: index + 1, correctCount: index, didCountCurrentAnswer: true,
            questionVersions: items
        )
    }

    func testUnchangedDraftPreservesCurrentQuestionAndResult() throws {
        let items = [item("q1"), item("q2")]
        let saved = draft(items, index: 1)
        let restored = try XCTUnwrap(PracticeSessionRestoration(draft: saved, questionBank: Array(items.reversed())))
        XCTAssertFalse(restored.wasRestarted)
        XCTAssertEqual(restored.items[restored.draft.index].id, "q2")
        XCTAssertEqual(restored.draft, saved)
    }

    func testRemovedEarlierQuestionCannotAttachItsIndexResultToNextQuestion() throws {
        let items = [item("q1"), item("q2"), item("q3")]
        let restored = try XCTUnwrap(PracticeSessionRestoration(draft: draft(items, index: 1), questionBank: Array(items.dropFirst())))
        XCTAssertTrue(restored.wasRestarted)
        XCTAssertEqual(restored.items[restored.draft.index].id, "q2")
        XCTAssertNil(restored.draft.result)
        XCTAssertEqual(restored.draft.answer, "")
        XCTAssertEqual(restored.draft.answeredCount, 0)
        XCTAssertFalse(restored.draft.didCountCurrentAnswer)
    }

    func testSameIdWithChangedContentRestartsInsteadOfReusingAnswer() throws {
        let original = item("q1")
        let updated = item("q1", prompt: "She has studied here ___ 2024.")
        let restored = try XCTUnwrap(PracticeSessionRestoration(draft: draft([original]), questionBank: [updated]))
        XCTAssertTrue(restored.wasRestarted)
        XCTAssertNil(restored.draft.result)
        XCTAssertEqual(restored.draft.questionVersions, [updated])
    }

    func testLegacyDraftWithoutVersionsRestartsSafely() throws {
        let question = item("q1")
        var legacy = draft([question])
        legacy.questionVersions = nil
        let encoded = try JSONEncoder().encode(legacy)
        let decoded = try JSONDecoder().decode(PracticeSessionDraft.self, from: encoded)
        let restored = try XCTUnwrap(PracticeSessionRestoration(draft: decoded, questionBank: [question]))
        XCTAssertTrue(restored.wasRestarted)
        XCTAssertNil(restored.draft.result)
    }

    func testMissingAllQuestionsDiscardsDraft() {
        XCTAssertNil(PracticeSessionRestoration(draft: draft([item("gone")]), questionBank: [item("new")]))
    }

    func testDeletingLocalUIDStoresKeepsOtherAccounts() throws {
        let suite = "UIModelsRepairTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let practice = PracticeSessionDraftStore(defaults: defaults)
        let notices = VolunteerReviewNoticeStore(defaults: defaults)
        for uid in ["a", "b"] {
            practice.save(draft([item("q1")]), ownerId: uid)
            notices.dismiss(noticeID: "private review for \(uid)", for: uid)
        }
        practice.clear(ownerId: "a")
        notices.clear(for: "a")
        XCTAssertNil(practice.load(ownerId: "a"))
        XCTAssertNil(notices.dismissedNoticeID(for: "a"))
        XCTAssertNotNil(practice.load(ownerId: "b"))
        XCTAssertNotNil(notices.dismissedNoticeID(for: "b"))
    }

    func testDueSingleSemanticSkillCanReviewRecordedQuestion() {
        let questions = [item("q1"), item("q2")]
        let record = SpacedRepetitionEngine.recording(existing: nil, studentUid: "student", item: questions[0], isCorrect: false, firstTryCorrect: false, source: .freePractice, at: date)
        let review = SpacedRepetitionEngine.reviewQuestions(records: [record], questionBank: questions, limit: 8, at: date, rotationSeed: "test")
        XCTAssertEqual(review.map(\.id), ["q1"])
    }

    func testReviewPrefersUnseenVariationBeforeRepeatingRecordedQuestion() {
        let original = item("q1")
        let variation = item("q2", prompt: "She has studied here ___ 2024.")
        let record = SpacedRepetitionEngine.recording(existing: nil, studentUid: "student", item: original, isCorrect: false, firstTryCorrect: false, source: .freePractice, at: date)
        let review = SpacedRepetitionEngine.reviewQuestions(records: [record], questionBank: [original, variation], limit: 8, at: date, rotationSeed: "test")
        XCTAssertEqual(review.map(\.id), ["q2"])
    }

    func testEveryBundledCurriculumCanProduceDueReview() {
        let bank = SeedData.approvedQuestionBankItems
        XCTAssertFalse(bank.isEmpty)
        let groups = Dictionary(grouping: bank, by: \.curriculumKey)
        for (key, questions) in groups {
            guard let question = questions.first else { continue }
            let record = SpacedRepetitionEngine.recording(existing: nil, studentUid: "student", item: question, isCorrect: false, firstTryCorrect: false, source: .freePractice, at: date)
            let review = SpacedRepetitionEngine.reviewQuestions(records: [record], questionBank: bank, limit: 8, at: date, rotationSeed: key)
            XCTAssertTrue(review.contains { $0.curriculumKey == key }, "No review for \(key)")
        }
    }

    func testExhaustedHighPrioritySkillIsNotDisplacedByLowerPriorityVariations() {
        let urgent = item("urgent")
        let other = item("other", prompt: "The cake was made ___ my aunt.", skill: "被動語態")
        let otherVariation = item("other-2", prompt: "The meal was made ___ my uncle.", skill: "被動語態")
        var urgentRecord = SpacedRepetitionEngine.recording(existing: nil, studentUid: "student", item: urgent, isCorrect: false, firstTryCorrect: false, source: .freePractice, at: date)
        urgentRecord.masteryScore = 0
        let otherRecord = SpacedRepetitionEngine.recording(existing: nil, studentUid: "student", item: other, isCorrect: false, firstTryCorrect: false, source: .freePractice, at: date)
        let review = SpacedRepetitionEngine.reviewQuestions(records: [otherRecord, urgentRecord], questionBank: [urgent, other, otherVariation], limit: 1, at: date, rotationSeed: "priority")
        XCTAssertEqual(review.map(\.id), [urgent.id])
    }
}
