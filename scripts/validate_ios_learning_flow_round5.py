from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require_markers(label: str, text: str, markers: list[str]) -> None:
    for marker in markers:
        assert marker in text, f"Missing {label}: {marker}"


def require_absent(label: str, text: str, markers: list[str]) -> None:
    for marker in markers:
        assert marker not in text, f"Forbidden {label}: {marker}"


practice_center = read("ios/EnglishPlus/EnglishPlus/Features/Practice/PracticeCenterView.swift")
student_home = read("ios/EnglishPlus/EnglishPlus/Features/Student/StudentHomeView.swift")
teacher_home = read("ios/EnglishPlus/EnglishPlus/Features/Teacher/TeacherHomeView.swift")


require_markers(
    "AI recommendation can become a selected practice set",
    practice_center,
    [
        "recommendedPracticeSet",
        "setMatchesAIRecommendation",
        "applyAIRecommendedPracticeSet",
        "PracticeAIRecommendationActionCard",
        "onApplyRecommendation",
        "selectedPracticeSetId = set.id",
    ],
)

require_markers(
    "wrong-answer AI leads to actionable repair practice",
    student_home,
    [
        "AIActionButtonRow",
        "openPracticeFromAI",
        "latestWrongAnswerAIResponse",
        "learningRepository.enterFreePracticeMode()",
    ],
)

require_markers(
    "teacher assignment surface routes recommendations into filtered class assignments",
    teacher_home,
    [
        "TeacherClassAssignmentView",
        "TeacherSelectedStudentPanel",
        "TeacherPracticeSetCatalog",
        "recommendationText(for: selectedStudent)",
        "filteredPracticeSets",
        "selectedQuestionType",
        "selectedLevel",
        "learningRepository.assignPracticeSet(set, to: selectedStudent, by: appState.currentUser)",
    ],
)

require_absent(
    "technical AI implementation details in visible feature copy",
    practice_center + student_home + teacher_home,
    [
        "OpenRouter",
        "GROQ_API_KEY",
        "cloudfunctions.net",
    ],
)

print("iOS learning flow round 5 actionable AI and assignment contract passed")
