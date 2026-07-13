from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WORKER = ROOT / "workers/englishplus-ai-proxy/src/index.js"
RULES = ROOT / "docs/ios-testflight/firebase/firestore.rules.draft"
FUNCTIONS = ROOT / "functions/src/index.ts"
SERVICE = ROOT / "ios/EnglishPlus/EnglishPlus/Services/ClassroomService.swift"
APP_STATE = ROOT / "ios/EnglishPlus/EnglishPlus/App/AppState.swift"
TEACHER = ROOT / "ios/EnglishPlus/EnglishPlus/Features/Teacher/TeacherHomeView.swift"
TESTS = ROOT / "ios/EnglishPlus/EnglishPlusTests/AuthenticationFlowAcceptanceTests.swift"
RULE_TESTS = ROOT / "firebase-tests/test/round6-classroom-lifecycle.test.js"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig")


def require(source: str, token: str, label: str, errors: list[str]) -> None:
    if token not in source:
        errors.append(f"missing {label}: {token}")


def main() -> int:
    sources = {
        "worker": read(WORKER),
        "rules": read(RULES),
        "functions": read(FUNCTIONS),
        "service": read(SERVICE),
        "app": read(APP_STATE),
        "teacher": read(TEACHER),
        "tests": read(TESTS),
        "rule_tests": read(RULE_TESTS),
    }
    errors: list[str] = []

    for token, label in [
        ('request.method === "DELETE"', "DELETE route"),
        ("async function deleteClassroom", "soft-delete command"),
        ('lifecycleStatus: { stringValue: "deleting" }', "control-plane deletion state"),
        ('lifecycleStatus: { stringValue: "deleted" }', "terminal deletion state"),
        ('exitReason: { stringValue: "classDeleted" }', "member exit reason"),
        ('role: { stringValue: item.role || "unknown" }', "legacy membership mirror repair"),
        ("classDeletionAudits", "deletion audit"),
        ("deletionAffectedMemberCount", "retry-stable affected member count"),
        ("commitFirestoreWriteChunks", "large-class chunked cleanup"),
        ("classroomIsOperationalDocument", "operational guard"),
        ("requireOwnedTeacherClassroomForDeletion", "idempotent owner authorization"),
    ]:
        require(sources["worker"], token, label, errors)

    for token, label in [
        ("function classIsOperational", "rules operational guard"),
        ("classIsOperational(classId)", "membership guard uses class state"),
        ("validActiveClassSelection", "active-class validation"),
    ]:
        require(sources["rules"], token, label, errors)

    for token, label in [
        ("classroom.active !== true", "AI class active requirement"),
        ("classroom.deletionPending === true", "AI deletion-pending rejection"),
        ('classroom.lifecycleStatus !== "active"', "AI lifecycle rejection"),
    ]:
        require(sources["functions"], token, label, errors)

    for token, label in [
        ("func deleteClassroom(classId: String) async throws", "classroom delete service"),
        ("ClassroomMembershipRealtimeBridge", "cross-device membership listener"),
        ('method: "DELETE"', "remote DELETE transport"),
    ]:
        require(sources["service"], token, label, errors)

    for token, label in [
        ("func deleteClassroom(classId: String) async -> Bool", "app deletion orchestration"),
        ("reconcileClassroomMemberships", "automatic membership reconciliation"),
        ("let baseSession = restored?.user.id == currentUser.id ? restored : nil", "stale restore defense"),
        ("你已自動回到個人模式", "student and volunteer exit notice"),
    ]:
        require(sources["app"], token, label, errors)

    for token, label in [
        ("刪除這個班級", "teacher delete action"),
        ("這個動作無法在 App 內復原", "destructive confirmation copy"),
        ("classroomPendingDeletion", "confirmation state"),
    ]:
        require(sources["teacher"], token, label, errors)

    for token, label in [
        ("ClassroomLifecycleAcceptanceTests", "Swift lifecycle suite"),
        ("testDeletingClassroomRemovesItFromEveryActiveMockMembership", "delete acceptance test"),
        ("testDeletedActiveMembershipFallsBackToPersonalModeWithoutErasingOtherClasses", "fallback acceptance test"),
        ("testMembershipListenerOverridesAStaleRestoredProfileAfterClassDeletion", "listener race acceptance test"),
    ]:
        require(sources["tests"], token, label, errors)

    for token, label in [
        ("a deleting or deleted class immediately revokes every class-scoped client permission", "rules revocation test"),
        ("Worker classroom lifecycle completes", "Worker integration test"),
        ("softDeletedRetainedForAudit", "history retention assertion"),
        ("legacyVolunteerMembership", "legacy member cleanup assertion"),
        ("alreadyDeleted", "idempotent retry assertion"),
    ]:
        require(sources["rule_tests"], token, label, errors)

    if errors:
        print("FIX-C classroom lifecycle validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("FIX-C classroom lifecycle contract passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
