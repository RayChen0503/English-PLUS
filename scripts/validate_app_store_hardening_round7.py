#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8-sig")


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def markers(content: str, expected: tuple[str, ...], label: str, errors: list[str]) -> None:
    for marker in expected:
        require(marker in content, f"{label} missing marker: {marker}", errors)


def main() -> int:
    errors: list[str] = []
    worker = read("workers/englishplus-ai-proxy/src/index.js")
    service = read("ios/EnglishPlus/EnglishPlus/Services/ClassroomService.swift")
    state = read("ios/EnglishPlus/EnglishPlus/App/AppState.swift")
    repository = read("ios/EnglishPlus/EnglishPlus/Services/FirebaseLearningRepository.swift")
    teacher = read("ios/EnglishPlus/EnglishPlus/Features/Teacher/TeacherHomeView.swift")
    emulator = read("firebase-tests/test/round6-classroom-lifecycle.test.js")
    report = read("docs/app-store-hardening/round-07-teacher-class-management.md")

    markers(worker, (
        'classroomStudents && request.method === "GET"',
        'classroomSettings && request.method === "PATCH"',
        "async function listClassroomStudents",
        "async function updateClassroom",
        "async function requireOwnedTeacherClassroom",
        'firestoreString(membership.fields?.role) === "student"',
        'membershipStatus: firestoreString(fields.membershipStatus)',
        'throw httpError(403, "CLASSROOM_OWNER_REQUIRED")',
    ), "trusted teacher class backend", errors)
    markers(service, (
        "struct ClassroomStudentSummary",
        "func listStudents(classId: String)",
        "func updateClassroom(classId: String, name: String)",
        "func startStudentListener(",
        '.whereField("membershipStatus", isEqualTo: "active")',
        'path: "classrooms/\\(classId)/students"',
        'method: "PATCH"',
    ), "classroom service and realtime roster", errors)
    markers(state, (
        "var classroomStudents: [ClassroomStudentSummary]",
        "var classroomRosterErrorMessage: String?",
        "func loadClassroomStudents(classId: String)",
        "func startClassroomRosterSync(classId: String)",
        "classroomRosterListener?.cancel()",
        "currentProfile?.activeClassId == classId",
        "func updateClassroom(classId: String, name: String)",
    ), "classroom app state", errors)
    markers(repository, (
        "func mirrorStudentSummaryIfPossible()",
        '"lastMoodScore": nullable(moodScore)',
        '"lastMissionStatus": mission?.status.rawValue',
        '"membershipStatus": "active"',
        'path: FirestorePath.student(classId: activeClassId, studentUid: activeUserUid)',
    ), "student roster summary sync", errors)
    markers(teacher, (
        "enum TeacherAssignmentAudience",
        "case entireClass",
        "students: activeClassStudents",
        "classStudentCount: activeClassStudents.count",
        "assignmentAudience == .entireClass",
        "recipients.forEach",
        "編輯班級名稱",
        "重新載入學生",
        "學生加入後就會出現在這裡",
    ), "teacher class workspace", errors)
    markers(emulator, (
        "teacher roster query is realtime-compatible",
        "listClassroomStudents",
        "updateClassroom",
        'error?.code === "TEACHER_ACCOUNT_REQUIRED"',
        'where("membershipStatus", "==", "active")',
    ), "Firestore Emulator teacher coverage", errors)
    markers(report, (
        "Round 7",
        "Status: Complete",
        "6A",
        "Acceptance flow",
        "29226640748",
        "4ee60303-29d4-42fe-ade7-d7ad576d2e7b",
        "26/26",
        "Xcode Cloud",
    ), "Round 7 report", errors)

    if errors:
        print("App Store hardening round 7 validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("App Store hardening round 7 teacher class management validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
