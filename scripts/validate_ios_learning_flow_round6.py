from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(label: str, text: str, markers: list[str]) -> None:
    missing = [marker for marker in markers if marker not in text]
    assert not missing, f"Missing {label}: {missing}"


def require_absent(label: str, text: str, markers: list[str]) -> None:
    present = [marker for marker in markers if marker in text]
    assert not present, f"Forbidden {label}: {present}"


student_shell = read("ios/EnglishPlus/EnglishPlus/Features/Student/StudentShellView.swift")
support_view = read("ios/EnglishPlus/EnglishPlus/Features/Support/SupportView.swift")
teacher_home = read("ios/EnglishPlus/EnglishPlus/Features/Teacher/TeacherHomeView.swift")
volunteer_home = read("ios/EnglishPlus/EnglishPlus/Features/Volunteer/VolunteerHomeView.swift")
practice_center = read("ios/EnglishPlus/EnglishPlus/Features/Practice/PracticeCenterView.swift")


require(
    "support AI response must provide real next-step actions",
    support_view,
    [
        "SupportAIActionCard",
        "onOpenPractice",
        "onOpenHome",
        "learningRepository.enterFreePracticeMode()",
        "learningRepository.returnToMissionFlow()",
    ],
)

require(
    "student support tab can route directly to practice or home",
    student_shell,
    [
        "SupportView(",
        "selectedTab = .practice",
        "selectedTab = .home",
    ],
)

require(
    "teacher question bank groups small practice sets by type",
    teacher_home,
    [
        "groupedSetsByType",
        "TeacherPracticeSetGroupSection",
        "ForEach(groupedSetsByType",
    ],
)

require(
    "staff empty states are explicit and useful",
    teacher_home + volunteer_home,
    [
        "TeacherEmptyQueueCard",
        "VolunteerEmptyQueueCard",
        "目前沒有等待接力的學生",
        "目前沒有需要接住的學生",
    ],
)

require(
    "practice center keeps group-based set selection available",
    practice_center,
    [
        "PracticeSetSelectionCard",
        "selectedPracticeSetId",
        "set.questionCount",
    ],
)

require_absent(
    "technical backend/debug terms in normal user-facing flow files",
    support_view + teacher_home + volunteer_home + practice_center,
    [
        "OpenRouter",
        "GROQ_API_KEY",
        "cloudfunctions.net",
        "Firebase config",
        "mock fallback",
    ],
)

print("iOS learning flow round 6 final UX closure contract passed")
