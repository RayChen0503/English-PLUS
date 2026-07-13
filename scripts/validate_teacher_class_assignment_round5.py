#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
IOS_ROOT = ROOT / "ios" / "EnglishPlus" / "EnglishPlus"

TEACHER_SHELL = IOS_ROOT / "Features" / "Teacher" / "TeacherShellView.swift"
TEACHER_HOME = IOS_ROOT / "Features" / "Teacher" / "TeacherHomeView.swift"
QUESTION_MODEL = IOS_ROOT / "Models" / "Question.swift"
STORE = IOS_ROOT / "Services" / "LearningRepositoryStore.swift"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def require_tokens(label: str, text: str, tokens: list[str], errors: list[str]) -> None:
    for token in tokens:
        require(token in text, f"{label} missing token: {token}", errors)


def reject_tokens(label: str, text: str, tokens: list[str], errors: list[str]) -> None:
    for token in tokens:
        require(token not in text, f"{label} still exposes old token: {token}", errors)


def main() -> int:
    errors: list[str] = []
    for path in [TEACHER_SHELL, TEACHER_HOME, QUESTION_MODEL, STORE]:
        require(path.exists(), f"missing file: {path.relative_to(ROOT)}", errors)

    if errors:
        for error in errors:
            print(error)
        return 1

    shell = read(TEACHER_SHELL)
    home = read(TEACHER_HOME)
    question_model = read(QUESTION_MODEL)
    store = read(STORE)

    require_tokens(
        "TeacherShellView",
        shell,
        [
            'Label("首頁"',
            'Label("班級"',
            'Label("接力"',
            'Label("報告"',
            "TeacherClassAssignmentView()",
            ".badge(learningRepository.staffDashboardMetrics.waitingHelpCount)",
        ],
        errors,
    )
    reject_tokens(
        "TeacherShellView",
        shell,
        [
            'Label("學生"',
            "TeacherStudentsView()",
            'Label("題庫"',
            "TeacherQuestionBankView()",
        ],
        errors,
    )

    require_tokens(
        "TeacherClassAssignmentView",
        home,
        [
            "班級學生與派題",
            "TeacherClassRosterSummaryCard",
            "TeacherStudentPickerCard",
            "TeacherSelectedStudentPanel",
            "TeacherStudentMissionPanel",
            "TeacherPracticeSetCatalog",
            "TeacherSkillFilterSection",
            "TeacherPracticeSetSkillSection",
            "TeacherPracticeSetCatalogRow",
            "TeacherAssignmentAudience",
            "assignmentAudience == .entireClass",
            "selectedSkill",
            "availableSkills",
            "groupedPracticeSetsBySkill",
            "1. 選班級學生",
            "2. 看學生狀態",
            "3. 依技能指派小題組",
            "每組 12 題內",
            "learningRepository.assignPracticeSet(set, to: $0, by: appState.currentUser)",
            "learningRepository.assignments(forStudentUid: selectedStudent.studentUid)",
        ],
        errors,
    )

    require_tokens(
        "Teacher assignment catalog",
        home,
        [
            "selectedQuestionType = nil",
            "selectedLevel = nil",
            "selectedSkill = nil",
            "TeacherFilterChip(title: \"全部技能\"",
            "TeacherFilterChip(title: skill",
            "set.questionCount",
            "set.estimatedMinutes",
            "set.skill",
            "set.previewText",
        ],
        errors,
    )

    require_tokens(
        "QuestionPracticeSet model",
        question_model,
        [
            "maxQuestionsPerSet: Int = 12",
            ".chunked(size: max(1, maxQuestionsPerSet))",
            "let skill: String",
            "var estimatedMinutes: Int",
        ],
        errors,
    )

    require_tokens(
        "LearningRepositoryStore assignment API",
        store,
        [
            "questionPracticeSets",
            "assignments(forStudentUid",
            "assignPracticeSet",
            "pendingAssignments(forStudentUid",
        ],
        errors,
    )

    if errors:
        for error in errors:
            print(error)
        return 1

    print("teacher class assignment round 5 contract passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
