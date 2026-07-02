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


question_model = read("ios/EnglishPlus/EnglishPlus/Models/Question.swift")
learning_model = read("ios/EnglishPlus/EnglishPlus/Models/LearningModels.swift")
store = read("ios/EnglishPlus/EnglishPlus/Services/LearningRepositoryStore.swift")
mock_repo = read("ios/EnglishPlus/EnglishPlus/Services/MockLearningRepository.swift")
firebase_repo = read("ios/EnglishPlus/EnglishPlus/Services/FirebaseLearningRepository.swift")
student_home = read("ios/EnglishPlus/EnglishPlus/Features/Student/StudentHomeView.swift")
practice_center = read("ios/EnglishPlus/EnglishPlus/Features/Practice/PracticeCenterView.swift")
teacher_home = read("ios/EnglishPlus/EnglishPlus/Features/Teacher/TeacherHomeView.swift")


require_markers(
    "practice-set catalog model",
    question_model,
    [
        "struct QuestionPracticeSet",
        "static func catalog(",
        "maxQuestionsPerSet: Int = 12",
        "questionIds",
        "estimatedMinutes",
    ],
)

require_markers(
    "teacher assignment model",
    learning_model,
    [
        "enum PracticeAssignmentStatus",
        "struct TeacherAssignedPracticeTask",
        "case pending",
        "case completed",
    ],
)

require_markers(
    "repository assignment contract",
    store,
    [
        "var questionPracticeSets: [QuestionPracticeSet]",
        "@Published private(set) var assignedPracticeTasks",
        "func pendingAssignments(forStudentUid",
        "func assignPracticeSet(",
        "func startAssignedPracticeTask(",
    ],
)

require_markers(
    "mock assignment implementation",
    mock_repo,
    [
        "@Published private(set) var assignedPracticeTasks",
        "func assignPracticeSet(",
        "func startAssignedPracticeTask(",
        "sourceCheckInId: assignment.id",
        "markAssignmentCompletedIfNeeded",
    ],
)

require_markers(
    "firebase assignment preservation",
    firebase_repo,
    [
        "assignedPracticeTasks",
        "func assignPracticeSet(",
        "func startAssignedPracticeTask(",
        "preservingAssignedPracticeTasks",
        "mirrorPracticeAssignmentIfPossible",
    ],
)

require_markers(
    "student assignment entry",
    student_home,
    [
        "assignedPracticeTaskCard",
        "pendingAssignments(forStudentUid:",
        "startAssignedPracticeTask(",
    ],
)

require_markers(
    "practice center grouped set entry",
    practice_center,
    [
        "PracticeSetSelectionCard",
        "selectedPracticeSetId",
        "questionPracticeSets",
    ],
)

require_markers(
    "teacher assignment UI",
    teacher_home,
    [
        "TeacherQuestionSetAssignmentCard",
        "assignPracticeSet(",
        "selectedStudentUid",
    ],
)

require_absent(
    "unbounded free-practice-only question bank",
    practice_center,
    [
        "private let questionBankItems = SeedData.approvedQuestionBankItems",
    ],
)

print("iOS learning flow round 4 assignment and question-set contract passed")
