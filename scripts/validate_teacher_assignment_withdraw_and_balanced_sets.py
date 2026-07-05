from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise SystemExit(f"Missing {label}: {needle}")


def reject(text: str, needle: str, label: str) -> None:
    if needle in text:
        raise SystemExit(f"Unexpected {label}: {needle}")


models = read("ios/EnglishPlus/EnglishPlus/Models/LearningModels.swift")
store = read("ios/EnglishPlus/EnglishPlus/Services/LearningRepositoryStore.swift")
mock = read("ios/EnglishPlus/EnglishPlus/Services/MockLearningRepository.swift")
firebase = read("ios/EnglishPlus/EnglishPlus/Services/FirebaseLearningRepository.swift")
student_shell = read("ios/EnglishPlus/EnglishPlus/Features/Student/StudentShellView.swift")
student_classroom = read("ios/EnglishPlus/EnglishPlus/Features/Student/StudentClassroomView.swift")
teacher = read("ios/EnglishPlus/EnglishPlus/Features/Teacher/TeacherHomeView.swift")

require(models, "case withdrawn", "withdrawn assignment status")

for text, label in [
    (store, "repository store"),
    (mock, "mock repository"),
    (firebase, "firebase repository"),
]:
    require(text, "withdrawAssignedPracticeTask", f"{label} withdraw API")

firebase_markers = [
    ("listenPracticeAssignments(classId: classId, user: user", "practice assignment realtime listener registration"),
    ("whereField(\"studentUid\", isEqualTo:", "student-scoped practice assignment listener"),
    ("practiceAssignment(from:", "Firestore practice assignment parser"),
    ("PracticeAssignmentStatus.init(rawValue:", "Firestore assignment status decoding"),
    ("practiceAssignmentResults(from:", "Firestore assignment result decoding"),
    ("mergePracticeAssignments", "Firestore practice assignment merge"),
    ("$0.id == mission.sourceCheckInId && $0.status == .withdrawn", "withdrawn active assignment cleanup from sync"),
    ("\"status\": assignment.status.rawValue", "Firestore assignment status mirror"),
]
for needle, label in firebase_markers:
    require(firebase, needle, label)

mock_markers = [
    ("status = .withdrawn", "local withdraw status update"),
    ("if currentMission?.sourceCheckInId == assignmentId", "active assigned mission cleanup"),
    ("currentMission = nil", "active mission reset after withdraw"),
    ("learningFlow = .initial", "learning flow reset after withdraw"),
    ("balancedAssignmentQuestions(for: set)", "balanced assignment question selection"),
    ("assignmentQuestions.map(\\.id)", "assignment stores expanded balanced question ids"),
    ("QuestionGroupingEngine.practiceSelection", "practice grouping engine used for assignments"),
]
for needle, label in mock_markers:
    require(mock, needle, label)

student_markers = [
    (".filter { $0.status == .pending || $0.status == .active }", "student active assignment filter"),
    (".filter { $0.status != .withdrawn }", "student hides withdrawn assignments"),
    ("老師收回任務後，任務會從這裡消失", "student-facing withdraw explanation"),
]
for needle, label in student_markers:
    require(student_classroom, needle, label)

require(student_shell, ".pending || $0.status == .active", "student classroom badge excludes completed/withdrawn")

teacher_markers = [
    ("作業紀錄", "teacher assignment dashboard"),
    ("displayableAssignments", "teacher displayable assignment filtering"),
    ("$0.status != .withdrawn", "teacher hides withdrawn assignments"),
    ('Label("收回任務"', "teacher withdraw action"),
    ("withdrawAssignedPracticeTask(assignment.id)", "teacher withdraw invokes repository"),
    ('return "已收回"', "teacher withdrawn status label"),
]
for needle, label in teacher_markers:
    require(teacher, needle, label)

reject(teacher, "status != .completed", "legacy non-completed assignment grouping")

print("teacher assignment withdraw and balanced set validation passed")
