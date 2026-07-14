from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise SystemExit(f"Missing {label}: {needle}")


def require_once(text: str, needle: str, label: str) -> None:
    count = text.count(needle)
    if count != 1:
        raise SystemExit(f"Expected exactly one {label}, found {count}: {needle}")


teacher = read("ios/EnglishPlus/EnglishPlus/Features/Teacher/TeacherHomeView.swift")
models = read("ios/EnglishPlus/EnglishPlus/Models/LearningModels.swift")
mock_repo = read("ios/EnglishPlus/EnglishPlus/Services/MockLearningRepository.swift")
firebase_repo = read("ios/EnglishPlus/EnglishPlus/Services/FirebaseLearningRepository.swift")

require_once(teacher, "private struct TeacherSelectedStudentPanel", "teacher selected student panel")
require_once(teacher, "private struct TeacherStudentAssignmentDashboard", "assignment dashboard")
require_once(teacher, "private struct TeacherStudentPickerCard", "student picker")
require_once(teacher, "private struct TeacherPracticeSetCatalog: View", "practice set catalog")

for needle, label in [
    ("ScrollView(.horizontal", "horizontal student selector"),
    ("1. 選班級學生", "student selection step"),
    ("2. 看學生狀態與作業", "student status and assignment step"),
    ("3. 依技能指派小題組", "assignment creation step"),
    ("未完成任務", "active assignment section"),
    ("完成紀錄", "completed assignment section"),
    ("查看每題對錯", "per-question review disclosure"),
    ("收起這筆", "assignment collapse action"),
    ("顯示已收起", "restore collapsed assignments action"),
    ("missionAttempts: learningRepository.missionAttempts", "assignment result attempt source"),
    ("questionBankItems: learningRepository.questionBankItems", "question metadata source"),
]:
    require(teacher, needle, label)

require(models, "struct PracticeAssignmentQuestionResult", "assignment question result snapshot model")
require(models, "var questionResults: [PracticeAssignmentQuestionResult]? = nil", "assignment result optional storage")

for needle, label in [
    ("assignedPracticeTasks[index].questionResults", "local assignment result snapshot write"),
    ("attemptCount: (previousResult?.attemptCount ?? 0) + 1", "per-question retry accumulation"),
    ("firstAttemptCorrect: previousResult?.firstAttemptCorrect ?? isCorrect", "first-attempt outcome preservation"),
    ("PracticeAssignmentQuestionResult(", "assignment snapshot construction"),
]:
    require(mock_repo, needle, label)

for needle, label in [
    ('"questionResults"', "Firestore assignment result field"),
    ('"selectedAnswer"', "Firestore selected answer field"),
    ('"acceptedAnswer"', "Firestore accepted answer field"),
    ('"isCorrect"', "Firestore correctness field"),
]:
    require(firebase_repo, needle, label)

print("teacher assignment history dashboard validation passed")
