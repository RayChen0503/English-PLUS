from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
IOS_ROOT = ROOT / "ios" / "EnglishPlus" / "EnglishPlus"


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def require_contains(label: str, text: str, markers: list[str], errors: list[str]) -> None:
    missing = [marker for marker in markers if marker not in text]
    require(not missing, f"{label} missing {missing}", errors)


def require_absent(label: str, text: str, markers: list[str], errors: list[str]) -> None:
    present = [marker for marker in markers if marker in text]
    require(not present, f"{label} still contains {present}", errors)


def main() -> int:
    errors: list[str] = []

    student_shell = read("ios/EnglishPlus/EnglishPlus/Features/Student/StudentShellView.swift")
    student_home = read("ios/EnglishPlus/EnglishPlus/Features/Student/StudentHomeView.swift")
    practice_center = read("ios/EnglishPlus/EnglishPlus/Features/Practice/PracticeCenterView.swift")
    support_view = read("ios/EnglishPlus/EnglishPlus/Features/Support/SupportView.swift")
    teacher_shell = read("ios/EnglishPlus/EnglishPlus/Features/Teacher/TeacherShellView.swift")
    teacher_home = read("ios/EnglishPlus/EnglishPlus/Features/Teacher/TeacherHomeView.swift")
    volunteer_shell = read("ios/EnglishPlus/EnglishPlus/Features/Volunteer/VolunteerShellView.swift")
    volunteer_home = read("ios/EnglishPlus/EnglishPlus/Features/Volunteer/VolunteerHomeView.swift")
    shared_action_bar = read("ios/EnglishPlus/EnglishPlus/Features/Shared/StaffSupportActionBar.swift")
    learning_models = read("ios/EnglishPlus/EnglishPlus/Models/LearningModels.swift")
    learning_repo = read("ios/EnglishPlus/EnglishPlus/Services/LearningRepositoryStore.swift")
    firebase_repo = read("ios/EnglishPlus/EnglishPlus/Services/FirebaseLearningRepository.swift")

    require_contains(
        "student mission and free-practice support loops",
        student_home + practice_center + support_view,
        [
            "MissionQuestionSupportPanel",
            "PracticeInlineSupportPanel",
            "SupportReplyCenterSummaryCard",
            "archiveSupportThreadForStudent",
            "markSupportThreadReadByStudent",
            "前往支持查看回覆",
        ],
        errors,
    )

    require_contains(
        "student shell routes support back into the learning loop",
        student_shell,
        [
            "selectedTab = .practice",
            "selectedTab = .home",
            "learningRepository.enterFreePracticeMode()",
        ],
        errors,
    )

    require_contains(
        "teacher class and handoff workflow",
        teacher_shell + teacher_home,
        [
            'Label("班級"',
            'Label("接力"',
            ".badge(learningRepository.staffDashboardMetrics.waitingHelpCount)",
            "TeacherClassRosterSummaryCard",
            "TeacherSkillFilterSection",
            "TeacherStudentMissionPanel",
            "assignPracticeSet",
            "StaffSupportActionBar",
        ],
        errors,
    )

    require_contains(
        "volunteer handoff workflow",
        volunteer_shell + volunteer_home,
        [
            'Label("接力"',
            ".badge(learningRepository.volunteerDashboardMetrics.waitingCount)",
            "StaffSupportQueueHeaderCard",
            "VolunteerSupportRequestCard",
            "QuestionSnapshotCard",
            "StaffSupportActionBar",
        ],
        errors,
    )

    require_contains(
        "shared support lifecycle model",
        learning_models + learning_repo + shared_action_bar,
        [
            "staffHandledNoReply",
            "studentArchivedAt",
            "staffArchivedAt",
            "countsTowardStaffBadge",
            "收起",
        ],
        errors,
    )

    require_absent(
        "obsolete early prototype UI paths",
        practice_center + support_view + teacher_home + volunteer_home,
        [
            "currentPracticeCard",
            "TeacherStudentsView",
            "TeacherRequestCard",
            "VolunteerReplyComposerCard",
            "SupportFollowUpActionCard",
        ],
        errors,
    )

    require_absent(
        "old standalone staff tabs",
        teacher_shell + volunteer_shell,
        [
            'Label("學生"',
            'Label("題庫"',
            'Label("同步"',
            'Label("腳本"',
        ],
        errors,
    )

    require_absent(
        "backend/debug wording in user-facing feature files",
        student_home + practice_center + support_view + teacher_home + volunteer_home,
        [
            "OpenRouter",
            "GROQ_API_KEY",
            "cloudfunctions.net",
            "GoogleService-Info",
            "MockAIService",
            "workers.dev",
        ],
        errors,
    )

    require(
        "guard db != nil else {\n            return AnyLearningRepositoryListenerToken {}" in firebase_repo,
        "Firebase listener should not bind an unused Firestore value during listener startup",
        errors,
    )

    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1

    print("Cross-role flow consistency round 6 validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
