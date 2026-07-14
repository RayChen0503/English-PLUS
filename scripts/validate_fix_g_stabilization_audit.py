"""Static acceptance checks for the FIX-G integrated stabilization audit."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


app_state = read("ios/EnglishPlus/EnglishPlus/App/AppState.swift")
student_shell = read("ios/EnglishPlus/EnglishPlus/Features/Student/StudentShellView.swift")
student_home = read("ios/EnglishPlus/EnglishPlus/Features/Student/StudentHomeView.swift")
teacher = read("ios/EnglishPlus/EnglishPlus/Features/Teacher/TeacherHomeView.swift")
repository = read("ios/EnglishPlus/EnglishPlus/Services/LearningRepositoryStore.swift")
repository += read("ios/EnglishPlus/EnglishPlus/Services/LearningRepositoryStore+Reporting.swift")
tests = read("ios/EnglishPlus/EnglishPlusTests/AuthenticationFlowAcceptanceTests.swift")
report = read("docs/app-store-hardening/fix-g-stabilization-audit.md")

require(
    app_state.count("synchronizeRoleScopedClassroomData(for: session.profile)") >= 3,
    "Role-scoped classroom data must reconcile on login, class selection and restored sessions",
)
require(
    "if hasAcceptedConsent {\n            synchronizeRoleScopedClassroomData(for: session.profile)" in app_state,
    "Teacher roster data must wait until required consent is accepted",
)
require(
    "classroomRosterListenerClassId != classId || classroomRosterListener == nil" in app_state,
    "Roster listeners must not restart for the same active class",
)
require(
    "startClassroomRosterSync(classId: classId)" in app_state,
    "Active teacher sessions must start roster synchronization",
)
require(
    "appState.classroomStudents.map" in teacher,
    "Teacher Home must be based on the authoritative membership roster",
)
for state_copy in (
    "目前是個人模式",
    "正在同步班級名冊",
    "名冊暫時無法同步",
    "班級目前還沒有學生",
):
    require(state_copy in teacher, f"Teacher roster state is missing: {state_copy}")

require(
    "studentCount: staffStudentSummaries.count" in repository,
    "Empty support data must not invent a student",
)
require(
    "repliedByVolunteerCount: supportRequests.filter" in repository,
    "Volunteer completion must count support threads",
)
require(
    "makeClassroomReportExport" in repository and "rosterStudentCount" in teacher,
    "Teacher reports must accept the active roster count",
)
require("TeacherReportNoActiveClassCard" in teacher, "Teacher reports need a no-class state")
require(
    'classCode: activeClassId ?? priorityRows.first?.classCode ?? "未選擇班級"' in repository,
    "Teacher reports must not fall back to a demonstration class",
)
require(
    "enterFreePracticeMode()" not in student_shell,
    "Opening the Practice tab must not mutate the learning-flow stage",
)
require(
    "private func openFreePractice()" in student_home
    and "learningRepository.enterFreePracticeMode()" in student_home,
    "Explicit free-practice entry must remain available",
)
for test_name in (
    "testTeacherSessionStartsTheActiveClassRosterWithoutOpeningTheClassTab",
    "testAnEmptySupportDatasetReportsZeroStudents",
    "testVolunteerCompletedCountTracksThreadsInsteadOfReplyMessages",
):
    require(test_name in tests, f"Swift acceptance coverage is missing: {test_name}")

require("Product-flow matrix" in report, "FIX-G audit matrix is missing")
require("Release boundary" in report, "FIX-G release boundary is missing")

print("FIX-G integrated stabilization audit contract passed")
