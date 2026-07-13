from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise SystemExit(f"Missing {label}: {needle}")


def reject(text: str, needle: str, label: str) -> None:
    if needle in text:
        raise SystemExit(f"Unexpected {label}: {needle}")


def main() -> None:
    model = read("ios/EnglishPlus/EnglishPlus/Models/LearningModels.swift")
    store = read("ios/EnglishPlus/EnglishPlus/Services/LearningRepositoryStore.swift")
    firebase = read("ios/EnglishPlus/EnglishPlus/Services/FirebaseLearningRepository.swift")
    root_view = read("ios/EnglishPlus/EnglishPlus/App/RootView.swift")
    support_view = read("ios/EnglishPlus/EnglishPlus/Features/Support/SupportView.swift")
    teacher = read("ios/EnglishPlus/EnglishPlus/Features/Teacher/TeacherHomeView.swift")
    volunteer = read("ios/EnglishPlus/EnglishPlus/Features/Volunteer/VolunteerHomeView.swift")
    rules = read("docs/ios-testflight/firebase/firestore.rules.draft")
    emulator_test = read("firebase-tests/test/fix-a-support-sync.test.js")
    swift_tests = read(
        "ios/EnglishPlus/EnglishPlusTests/AuthenticationFlowAcceptanceTests.swift"
    )

    for needle in [
        "hasActionableSupportContent",
        "let latestReplyAt = visibleStaffRepliesToStudent.map(\\.createdAt).max()",
        "latestReplyAt > studentLastReadAt",
        "var reconciledStatus: SupportThreadStatus",
        "func reconcilingLifecycle() -> StudentSupportRequest",
    ]:
        require(model, needle, "timestamp-based support lifecycle")

    for needle in [
        ") async throws",
        "pendingSupportActionKeys",
        "supportActionErrorMessage",
        "performSupportAction(",
        ".filter(\\.hasActionableSupportContent)",
        ".map { $0.reconcilingLifecycle() }",
    ]:
        require(store, needle, "confirmed support store")

    for needle in [
        "persistNewSupportRequest",
        "persistSupportReply",
        "try await batch.commit()",
        "try await db.runTransaction",
        '"studentVisible": true',
        ".filter(\\.isStaffReply)",
        "sanitizedSupportRequests",
        "SupportMutationError.requestAlreadyHandled",
    ]:
        require(firebase, needle, "atomic Firestore support synchronization")

    reject(
        firebase,
        '"studentVisible": request.isVisibleToStudent',
        "mutable support query visibility",
    )
    reject(firebase, "mirrorUpdatedSupportRequestIfPossible", "silent full-thread reply mirror")
    reject(firebase, "mirrorSupportRequestIfPossible", "silent full-thread support mirror")

    require(root_view, '"同步未完成"', "user-visible synchronization failure")
    require(support_view, "request.hasStudentUnreadReply", "student unread reconciliation")
    require(support_view, "await learningRepository.withdrawSupportRequest", "confirmed withdraw UI")
    require(teacher, "await learningRepository.addTeacherReply", "confirmed teacher reply UI")
    require(volunteer, "await learningRepository.addVolunteerReply", "confirmed volunteer reply UI")

    for needle in [
        'thread.status != "closed"',
        'thread.status != "archived"',
        'thread.withdrawnAt == null',
    ]:
        require(rules, needle, "closed-thread write protection")

    for needle in [
        "student create, teacher reply, and student read form one cross-device timeline",
        "withdraw keeps immutable query visibility and removes the thread from staff writes",
        "teacher and volunteer archive independently without changing student visibility",
    ]:
        require(emulator_test, needle, "FIX-A Firestore emulator coverage")

    for needle in [
        "SupportLifecycleAcceptanceTests",
        "testStaffReplyIsUnreadUntilStudentReadTimestampPassesReply",
        "testStudentRequestMessageNeverCountsAsAStaffReply",
        "testWithdrawAlwaysClosesAndHidesStudentThread",
    ]:
        require(swift_tests, needle, "FIX-A Swift lifecycle coverage")

    print("FIX-A support synchronization contract passed")


if __name__ == "__main__":
    main()
