#!/usr/bin/env python3
"""Validate Round 16 mastery, spaced review, and assignment tracking contracts."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8-sig")


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def require_markers(content: str, markers: tuple[str, ...], label: str, errors: list[str]) -> None:
    for marker in markers:
        require(marker in content, f"{label} missing marker: {marker}", errors)


def main() -> int:
    errors: list[str] = []
    models = read("ios/EnglishPlus/EnglishPlus/Models/LearningModels.swift")
    contracts = read("ios/EnglishPlus/EnglishPlus/Services/LearningRepositoryContracts.swift")
    mock = read("ios/EnglishPlus/EnglishPlus/Services/MockLearningRepository.swift")
    firebase = read("ios/EnglishPlus/EnglishPlus/Services/FirebaseLearningRepository.swift")
    paths = read("ios/EnglishPlus/EnglishPlus/Data/FirestorePath.swift")
    practice = read("ios/EnglishPlus/EnglishPlus/Features/Practice/PracticeCenterView.swift")
    map_view = read("ios/EnglishPlus/EnglishPlus/Features/Student/StudentLearningMapView.swift")
    teacher = read("ios/EnglishPlus/EnglishPlus/Features/Teacher/TeacherHomeView.swift")
    rules = read("docs/ios-testflight/firebase/firestore.rules.draft")
    swift_tests = read("ios/EnglishPlus/EnglishPlusTests/AuthenticationFlowAcceptanceTests.swift")
    emulator_tests = read("firebase-tests/test/round16-mastery-spaced-review.test.js")
    worker = read("workers/englishplus-ai-proxy/src/index.js")
    workflow = read(".github/workflows/ios-hardening-build.yml")
    mock_ai = read("ios/EnglishPlus/EnglishPlus/Services/MockAiProxyService.swift")
    service_factory = read("ios/EnglishPlus/EnglishPlus/Services/FirebaseAppConfigurator.swift")
    firebase_auth = read("ios/EnglishPlus/EnglishPlus/Services/FirebaseAuthService.swift")
    mock_auth = read("ios/EnglishPlus/EnglishPlus/Services/MockAuthService.swift")

    require_markers(
        models,
        (
            "enum LearningAttemptSource",
            "enum MasteryBand",
            "struct SkillMasteryRecord",
            "struct MasterySummary",
            "enum SpacedRepetitionEngine",
            "static func reviewQuestions(",
            "let intervals = [1, 3, 7, 14, 30]",
            "attemptCount: Int",
            "firstAttemptCorrect: Bool",
        ),
        "mastery domain",
        errors,
    )
    require_markers(
        contracts + mock,
        (
            "var masteryRecords: [SkillMasteryRecord]",
            "func recordPracticeAnswer(",
            "recordMasteryAttempt(",
            "updateAssignmentProgressIfNeeded(",
            "firstTryCorrect: attemptNumber == 1 && isCorrect",
            ".teacherAssignment",
            "integratingMasteryReview(",
        ),
        "repository projection",
        errors,
    )
    require_markers(
        firebase + paths,
        (
            "personalSkillMastery(uid: String, masteryId: String)",
            "skillMastery(classId: String, studentUid: String, masteryId: String)",
            "mirrorMasteryForQuestionIfPossible(",
            "listenSkillMastery(",
            "mergedMasteryRecords(",
            '"attemptCount": result.attemptCount',
            '"firstAttemptCorrect": result.firstAttemptCorrect',
        ),
        "Firestore synchronization",
        errors,
    )
    require_markers(
        practice + map_view,
        (
            "SpacedReviewCard",
            "startSpacedReviewSession",
            "dueReviewQuestions(limit:",
            "masterySummary",
            "recordPracticeAnswer(",
        ),
        "student review experience",
        errors,
    )
    require_markers(
        teacher,
        (
            "TeacherAssignmentProgressOverview",
            "firstTryAccuracy",
            "attemptCount",
            "firstAttemptCorrect",
            "ProgressView(value:",
        ),
        "teacher assignment tracking",
        errors,
    )
    require_markers(
        rules,
        (
            "function validMasteryProjection",
            "function validMasteryUpdate",
            "match /skillMastery/{masteryId}",
            "request.resource.data.attemptCount > resource.data.attemptCount",
            "staffCanReadStudentTimeline(classId, studentUid, resource.data.lastAnsweredAt)",
        ),
        "Firestore mastery rules",
        errors,
    )
    require(rules.count("match /skillMastery/{masteryId}") == 2, "personal and class mastery paths must both be protected", errors)
    require(worker.count('"skillMastery"') >= 2, "account deletion must remove personal and class mastery documents", errors)
    require_markers(
        mock_ai,
        (
            'summary: "先用一組短練習確認 \\(focusText)',
            'title: "\\(focusText) 複習"',
        ),
        "offline AI recommendation copy",
        errors,
    )
    require_markers(
        service_factory + firebase_auth + mock_auth,
        (
            "let idTokenProvider: @Sendable () async throws -> String?",
            "struct FirebaseAuthService: AuthService, Sendable",
            "struct MockAuthService: AuthService, Sendable",
        ),
        "warning-free authentication transport",
        errors,
    )
    require(
        service_factory.count("idTokenProvider: idTokenProvider") == 5,
        "all five authenticated remote services must share the sendable token provider",
        errors,
    )
    require(
        "idTokenProvider: authService.currentIdToken" not in service_factory,
        "non-sendable authentication method references must not be passed to remote services",
        errors,
    )

    for test_name in (
        "testWrongAnswerBecomesDueImmediatelyAndAffectsMasterySummary",
        "testCorrectStreakRaisesMasteryAndExtendsReviewInterval",
        "testReviewSelectionAvoidsTheLastQuestionAndItsSemanticDuplicates",
        "testFreeAndRepairPracticeUpdateOneSharedMasteryRecord",
        "testTeacherAssignmentPublishesPartialProgressAndRetryHistory",
        "testLegacyLocalSnapshotDefaultsMasteryToEmpty",
    ):
        require(test_name in swift_tests, f"Swift acceptance test is missing: {test_name}", errors)
    require_markers(
        emulator_tests,
        (
            "student mastery sync is private while the current teacher can read it",
            "personal-mode mastery works without exposing it to staff or another student",
            "mastery updates advance attempts but cannot rewrite identity or inflate counters",
            "a forged mastery identity is rejected at creation",
            "assertFails(getDoc(doc(volunteer, ...path)))",
        ),
        "Firestore emulator coverage",
        errors,
    )
    require_markers(
        workflow,
        (
            ".github/ci-triggers/round16-mastery-review",
            "validate_app_store_hardening_round16.py",
            "validate_app_store_hardening_block_d.py --preflight",
        ),
        "macOS gate",
        errors,
    )

    if errors:
        print("App Store hardening Round 16 validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1
    print("App Store hardening Round 16 mastery and spaced-review validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
