#!/usr/bin/env python3
"""Validate the four user-reported regressions found during Block E testing."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8-sig")


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def require_all(content: str, markers: tuple[str, ...], label: str, errors: list[str]) -> None:
    for marker in markers:
        require(marker in content, f"{label} missing marker: {marker}", errors)


def main() -> int:
    errors: list[str] = []
    worker = read("workers/englishplus-ai-proxy/src/index.js")
    admin = read("admin-web/src/main.js")
    identity = read("ios/EnglishPlus/EnglishPlus/Models/IdentityModels.swift")
    app_state = read("ios/EnglishPlus/EnglishPlus/App/AppState.swift")
    volunteer_application = read(
        "ios/EnglishPlus/EnglishPlus/Features/Volunteer/VolunteerApplicationView.swift"
    )
    firebase_learning = read(
        "ios/EnglishPlus/EnglishPlus/Services/FirebaseLearningRepository.swift"
    )
    mock_learning = read(
        "ios/EnglishPlus/EnglishPlus/Services/MockLearningRepository.swift"
    )
    contracts = read(
        "ios/EnglishPlus/EnglishPlus/Services/LearningRepositoryContracts.swift"
    )
    classroom = read(
        "ios/EnglishPlus/EnglishPlus/Features/Student/StudentClassroomView.swift"
    )
    home = read("ios/EnglishPlus/EnglishPlus/Features/Student/StudentHomeView.swift")
    rules = read("docs/ios-testflight/firebase/firestore.rules.draft")
    firestore_tests = read("firebase-tests/test/round8-firestore-contract.test.js")

    require_all(
        worker,
        (
            "function adminEvidenceHeaders",
            '"Content-Disposition": `inline;',
            '"Cache-Control": "private, no-store"',
            "...CORS_HEADERS",
        ),
        "administrator evidence preview",
        errors,
    )
    require_all(
        admin,
        (
            "const popup = window.open",
            "const blob = await response.blob()",
            "審核備註（必填）",
            "申請人會在 App 中看到這段文字",
        ),
        "administrator review experience",
        errors,
    )

    require_all(
        identity,
        (
            "struct VolunteerApplicationReviewState",
            "let reviewNote: String?",
            "var isEditable: Bool",
        ),
        "volunteer review model",
        errors,
    )
    require_all(
        volunteer_application,
        (
            "applicationStatusCard",
            "管理員說明",
            "需要補件",
            "修改後重新送審",
        ),
        "volunteer applicant feedback",
        errors,
    )
    require_all(
        app_state,
        (
            "volunteerApplicationReviewState",
            "loadVolunteerApplicationReviewState",
            "session.profile.accountStatus == .pendingApproval",
            "route = .volunteerApplication",
        ),
        "volunteer pending-session routing",
        errors,
    )
    require(
        'rejected: { applicationStatus: "rejected", accountStatus: "pendingApplication"' in worker,
        "rejected volunteers must be able to sign in, read the reason, and resubmit",
        errors,
    )
    require(
        'resource.data.status in ["draft", "needsMoreInformation", "rejected"]' in rules,
        "Firestore rules must permit rejected applicants to resubmit",
        errors,
    )

    require_all(
        contracts,
        (
            "func submitAssignedPracticeAnswer(",
            "async throws -> PracticeAssignmentQuestionResult?",
        ),
        "independent class-assignment contract",
        errors,
    )
    require_all(
        classroom,
        (
            "nextAssignmentQuestion(for: assignment)",
            "submitAssignedPracticeAnswer(",
            "assignment.questionResults",
            "closeAssignmentSession()",
        ),
        "student class-assignment session",
        errors,
    )
    require("onOpenClassroom" not in home, "class assignments must not hijack the daily home flow", errors)
    start_block = mock_learning.split("func startAssignedPracticeTask", 1)[1].split(
        "func submitAssignedPracticeAnswer", 1
    )[0]
    require("currentMission" not in start_block, "starting class work must not replace currentMission", errors)
    require_all(
        firebase_learning,
        (
            "try await persistAssignmentProgress(startedAssignment)",
            "try await persistAssignmentProgress(assignment)",
            "try await persistAssignmentWithdrawal(assignment)",
        ),
        "awaited assignment persistence",
        errors,
    )
    require(
        "persistAssignmentStart" not in firebase_learning
        and "persistAssignmentAnswer" not in firebase_learning,
        "class work must not be persisted through daily mission records",
        errors,
    )

    require_all(
        firebase_learning,
        (
            'whereField("studentUid", isEqualTo: user?.id ?? "")',
            '"visibility",\n                    isEqualTo: MessageVisibility.studentVisible.rawValue',
        ),
        "student cross-device support listeners",
        errors,
    )
    require_all(
        firestore_tests,
        (
            "student support message listener must scope itself to student-visible replies",
            'where("visibility", "==", "studentVisible")',
            "await assertFails(getDocs(messages))",
        ),
        "support-query security regression",
        errors,
    )

    if errors:
        print("Block E reported-regression validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1
    print("Block E reported-regression validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
