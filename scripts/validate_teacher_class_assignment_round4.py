#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TEACHER_HOME = ROOT / "ios" / "EnglishPlus" / "EnglishPlus" / "Features" / "Teacher" / "TeacherHomeView.swift"
TEACHER_SHELL = ROOT / "ios" / "EnglishPlus" / "EnglishPlus" / "Features" / "Teacher" / "TeacherShellView.swift"
STUDENT_HOME = ROOT / "ios" / "EnglishPlus" / "EnglishPlus" / "Features" / "Student" / "StudentHomeView.swift"
STORE = ROOT / "ios" / "EnglishPlus" / "EnglishPlus" / "Services" / "LearningRepositoryStore.swift"


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def main() -> int:
    errors: list[str] = []

    for path in [TEACHER_HOME, TEACHER_SHELL, STUDENT_HOME, STORE]:
        require(path.exists(), f"missing file: {path.relative_to(ROOT)}", errors)

    if errors:
        for error in errors:
            print(error)
        return 1

    teacher_home = read(TEACHER_HOME)
    teacher_shell = read(TEACHER_SHELL)
    student_home = read(STUDENT_HOME)
    store = read(STORE)

    required_teacher_tokens = [
        "struct TeacherClassAssignmentView",
        "班級派題",
        "先選學生，再指派 12 題內的小題組",
        "TeacherStudentPickerCard",
        "TeacherSelectedStudentPanel",
        "TeacherStudentAssignmentHistory",
        "TeacherPracticeSetCatalog",
        "TeacherPracticeSetCatalogSection",
        "selectedQuestionType",
        "selectedLevel",
        "filteredPracticeSets",
        "recommendationText(for: selectedStudent)",
        "learningRepository.assignments(forStudentUid:",
        "learningRepository.assignPracticeSet(set, to: selectedStudent, by: appState.currentUser)",
        "已指派給",
        "每組最多 12 題",
    ]
    for token in required_teacher_tokens:
        require(token in teacher_home, f"Teacher class assignment flow missing token: {token}", errors)

    require('Label("班級", systemImage: "person.3.sequence")' in teacher_shell,
            "Teacher tab must become the class assignment workspace", errors)
    require("TeacherClassAssignmentView()" in teacher_shell,
            "Teacher shell must route the class tab to TeacherClassAssignmentView", errors)
    require('Label("題庫"' not in teacher_shell,
            "Teacher shell should not expose a standalone question-bank tab", errors)

    required_store_tokens = [
        "func assignments(forStudentUid studentUid: String?) -> [TeacherAssignedPracticeTask]",
        "$0.studentUid == studentUid",
        ".sorted { $0.createdAt > $1.createdAt }",
    ]
    for token in required_store_tokens:
        require(token in store, f"LearningRepositoryStore missing assignment lookup token: {token}", errors)

    required_student_tokens = [
        "assignedPracticeTaskCard",
        "老師指派練習",
        "開始老師指派題組",
        "learningRepository.startAssignedPracticeTask(assignment)",
    ]
    for token in required_student_tokens:
        require(token in student_home, f"Student assigned-task entry missing token: {token}", errors)

    forbidden_teacher_tokens = [
        "老師可以快速確認題型、難度與任務來源",
        "TeacherQuestionSetAssignmentCard(",
    ]
    for token in forbidden_teacher_tokens:
        require(token not in teacher_home, f"Teacher page still contains old question-bank assignment UI: {token}", errors)

    if errors:
        for error in errors:
            print(error)
        return 1

    print("teacher class assignment round 4 contract passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
