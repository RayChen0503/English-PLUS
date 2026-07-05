from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


teacher = read("ios/EnglishPlus/EnglishPlus/Features/Teacher/TeacherHomeView.swift")
teacher_shell = read("ios/EnglishPlus/EnglishPlus/Features/Teacher/TeacherShellView.swift")
student_shell = read("ios/EnglishPlus/EnglishPlus/Features/Student/StudentShellView.swift")
student_classroom = read("ios/EnglishPlus/EnglishPlus/Features/Student/StudentClassroomView.swift")
student_home = read("ios/EnglishPlus/EnglishPlus/Features/Student/StudentHomeView.swift")
store = read("ios/EnglishPlus/EnglishPlus/Services/LearningRepositoryStore.swift")

teacher_markers = [
    "struct TeacherClassAssignmentView",
    "TeacherClassAssignmentHeader",
    "TeacherClassRosterSummaryCard",
    "TeacherStudentPickerCard",
    "TeacherSelectedStudentPanel",
    "TeacherStudentAssignmentDashboard",
    "TeacherPracticeSetCatalog",
    "TeacherSkillFilterSection",
    "TeacherPracticeSetSkillSection",
    "selectedQuestionType",
    "selectedLevel",
    "selectedSkill",
    "filteredPracticeSets",
    "groupedPracticeSetsBySkill",
    "recommendationText(for: selectedStudent)",
    "learningRepository.assignments(forStudentUid:",
    "learningRepository.assignPracticeSet(set, to: selectedStudent, by: appState.currentUser)",
    "withdrawAssignedPracticeTask(assignment.id)",
    'Label("收回任務"',
    "TeacherAssignmentReviewCard",
    "TeacherAssignmentQuestionResultRow",
]
for marker in teacher_markers:
    require(marker in teacher, f"Teacher class assignment view missing marker: {marker}")

require(
    'Label("班級", systemImage: "person.3.sequence")' in teacher_shell,
    "Teacher tab bar should expose the class assignment workspace.",
)
require("TeacherClassAssignmentView()" in teacher_shell, "Teacher shell should route class tab to TeacherClassAssignmentView.")
require("TeacherStudentsView()" not in teacher_shell, "Teacher shell should not use the old student-only class tab.")

store_markers = [
    "func assignments(forStudentUid studentUid: String?) -> [TeacherAssignedPracticeTask]",
    "$0.studentUid == studentUid",
    ".sorted { $0.createdAt > $1.createdAt }",
    "func withdrawAssignedPracticeTask(_ assignmentId: String)",
]
for marker in store_markers:
    require(marker in store, f"LearningRepositoryStore missing marker: {marker}")

student_shell_markers = [
    "StudentClassroomView",
    'Label("班級", systemImage: "person.3")',
    ".badge(pendingAssignmentCount)",
]
for marker in student_shell_markers:
    require(marker in student_shell, f"Student shell missing marker: {marker}")

student_classroom_markers = [
    "老師指派任務",
    "startAssignedPracticeTask",
    "$0.status == .pending || $0.status == .active",
    "$0.status != .withdrawn",
    "老師收回任務後，任務會從這裡消失",
]
for marker in student_classroom_markers:
    require(marker in student_classroom, f"Student classroom missing marker: {marker}")

require(
    "assignedPracticeTaskCard" not in student_home,
    "Student home should no longer own the teacher-assigned task card.",
)

print("teacher class assignment round 4 contract passed")
