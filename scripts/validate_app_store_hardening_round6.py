#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8-sig")


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def require_markers(content: str, markers: tuple[str, ...], label: str, errors: list[str]) -> None:
    for marker in markers:
        require(marker in content, f"{label} missing marker: {marker}", errors)


def main() -> int:
    errors: list[str] = []
    worker = read("workers/englishplus-ai-proxy/src/index.js")
    worker_tests = read("workers/englishplus-ai-proxy/test/security.test.js")
    service = read("ios/EnglishPlus/EnglishPlus/Services/ClassroomService.swift")
    state = read("ios/EnglishPlus/EnglishPlus/App/AppState.swift")
    factory = read("ios/EnglishPlus/EnglishPlus/Services/FirebaseAppConfigurator.swift")
    profile = read("ios/EnglishPlus/EnglishPlus/Models/AppUserProfile.swift")
    local = read("ios/EnglishPlus/EnglishPlus/Services/MockLearningRepository.swift")
    firebase = read("ios/EnglishPlus/EnglishPlus/Services/FirebaseLearningRepository.swift")
    student = read("ios/EnglishPlus/EnglishPlus/Features/Student/StudentClassroomView.swift")
    teacher = read("ios/EnglishPlus/EnglishPlus/Features/Teacher/TeacherHomeView.swift")
    rules = read("docs/ios-testflight/firebase/firestore.rules.draft")
    decisions = read("docs/app-store-hardening/DECISIONS.md")
    report = read("docs/app-store-hardening/round-06-classroom-lifecycle.md")
    project = read("ios/EnglishPlus/EnglishPlus.xcodeproj/project.pbxproj")

    require_markers(
        worker,
        (
            'url.pathname === "/classrooms" && request.method === "GET"',
            'url.pathname === "/classrooms" && request.method === "POST"',
            'url.pathname === "/classrooms/bootstrap"',
            'url.pathname === "/classrooms/join"',
            "(leave|reset-code)",
            'requireActiveRole(context.profile, "teacher"',
            'requireActiveRole(context.profile, "student"',
            "crypto.randomUUID()",
            "crypto.getRandomValues",
            "classJoinCodes",
            "classAdmins",
            "currentDocument: { exists: false }",
            "CLASSROOM_JOIN_RATE_LIMIT",
            "CLASS_JOIN_MAX_ATTEMPTS",
            "assertClassJoinRateLimit",
            "ensureLegacyClassroomAccount",
            "migrationContext",
            'users/${user.sub}/classMemberships/${legacyClassId}',
            'status: { stringValue: "left" }',
            "existingMembership.fields?.visibilityStartsAt?.timestampValue || firstJoinedAt",
        ),
        "trusted classroom backend",
        errors,
    )
    require(
        "delete: `${root}/classes/${classId}/members/${uid}`" not in worker,
        "leaving a class deletes the membership instead of retaining historical reports",
        errors,
    )
    require_markers(
        worker_tests,
        (
            "classroom names and join codes are normalized",
            "classroom codes use the unambiguous alphabet",
            "legacy and current membership shapes migrate only while active",
        ),
        "classroom worker tests",
        errors,
    )
    require_markers(
        service,
        (
            "protocol ClassroomService",
            "func listClassrooms()",
            "func createClassroom(name:",
            "func joinClassroom(code:",
            "func leaveClassroom(classId:",
            "func resetJoinCode(classId:",
            "RemoteClassroomService",
            'path: "classrooms/bootstrap"',
            'case "CLASSROOM_JOIN_RATE_LIMIT"',
        ),
        "iOS classroom service",
        errors,
    )
    require_markers(
        state + factory,
        (
            "private let classroomService: ClassroomService",
            "func loadClassrooms() async",
            "currentUser?.id == restored.user.id",
            "func createClassroom(name: String) async -> Bool",
            "func joinClassroom(code: String) async -> Bool",
            "func leaveClassroom(classId: String) async -> Bool",
            "func resetClassroomCode(classId: String) async -> Bool",
            "RemoteClassroomService(",
            "MockClassroomService()",
        ),
        "classroom app-state wiring",
        errors,
    )
    require_markers(
        profile,
        (
            "func upsertingMembership(",
            "func markingMembershipLeft(classId:",
            "activeClassId: nextActiveClassId",
        ),
        "class membership profile transitions",
        errors,
    )
    require_markers(
        local + firebase,
        (
            "func activatePersistenceScope(uid: String, scopeId: String)",
            'scopeId: isPersonalMode ? "personal" : classId',
            'key: "\\(baseKey).scope.\\(encodedScope)"',
            'uid.hasSuffix("--personal")',
        ),
        "UID and class scoped persistence",
        errors,
    )
    require_markers(
        student + state,
        (
            "目前：個人模式",
            "切換班級",
            "加入班級",
            "離開班級",
            "個人學習紀錄與其他功能不受影響",
        ),
        "student classroom UX",
        errors,
    )
    require_markers(
        teacher,
        (
            "班級控制台",
            "建立班級",
            "學生加入代碼",
            "複製代碼",
            "重設班級代碼？",
            "舊代碼會立即失效",
        ),
        "teacher classroom UX",
        errors,
    )
    require_markers(
        rules,
        (
            "isInsideStudentMembershipWindow",
            "staffCanWriteStudentTimeline",
            "classStaffCanWriteSupportTimeline",
            "match /classAdmins/{classId}",
            "match /classJoinCodes/{joinCode}",
            "match /classJoinAttempts/{uid}",
            "allow read, write: if false;",
        ),
        "classroom Firestore boundary",
        errors,
    )
    require_markers(
        decisions,
        ("D-15", "stable join code", "D-16", "historical class reports", "D-17"),
        "Round 6 decisions",
        errors,
    )
    require_markers(
        report,
        (
            "Round 6",
            "Status: Complete",
            "4B",
            "5A",
            "6A",
            "Remote deployment gate",
            "23/23 production smoke checks",
        ),
        "Round 6 report",
        errors,
    )
    require(
        "ClassroomService.swift" in project,
        "ClassroomService.swift is not included in the Xcode project",
        errors,
    )

    if errors:
        print("App Store hardening round 6 validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("App Store hardening round 6 classroom lifecycle validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
