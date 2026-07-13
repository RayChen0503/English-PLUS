from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WORKER = ROOT / "workers/englishplus-ai-proxy/src/index.js"
RULES = ROOT / "docs/ios-testflight/firebase/firestore.rules.draft"
SERVICE = ROOT / "ios/EnglishPlus/EnglishPlus/Services/ClassroomService.swift"
APP_STATE = ROOT / "ios/EnglishPlus/EnglishPlus/App/AppState.swift"
TEACHER = ROOT / "ios/EnglishPlus/EnglishPlus/Features/Teacher/TeacherHomeView.swift"
VOLUNTEER = ROOT / "ios/EnglishPlus/EnglishPlus/Features/Volunteer/VolunteerHomeView.swift"
SHELL = ROOT / "ios/EnglishPlus/EnglishPlus/Features/Volunteer/VolunteerShellView.swift"
TESTS = ROOT / "ios/EnglishPlus/EnglishPlusTests/AuthenticationFlowAcceptanceTests.swift"
RULE_TESTS = ROOT / "firebase-tests/test/fix-e-volunteer-service-scope.test.js"
PRIVACY_RULE_TESTS = ROOT / "firebase-tests/test/round8-firestore-contract.test.js"
DECISIONS = ROOT / "docs/app-store-hardening/DECISIONS.md"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig")


def require(source: str, token: str, label: str, errors: list[str]) -> None:
    if token not in source:
        errors.append(f"missing {label}: {token}")


def main() -> int:
    sources = {
        "worker": read(WORKER),
        "rules": read(RULES),
        "service": read(SERVICE),
        "app": read(APP_STATE),
        "teacher": read(TEACHER),
        "volunteer": read(VOLUNTEER),
        "shell": read(SHELL),
        "tests": read(TESTS),
        "rule_tests": read(RULE_TESTS),
        "privacy_rule_tests": read(PRIVACY_RULE_TESTS),
        "decisions": read(DECISIONS),
    }
    errors: list[str] = []

    for token, label in [
        ('"/volunteer-services"', "volunteer service routes"),
        ("requestVolunteerService", "pending request command"),
        ("reviewVolunteerService", "teacher review command"),
        ("leaveVolunteerService", "volunteer leave command"),
        ("resetVolunteerInviteCode", "private volunteer code reset"),
        ("volunteerMembershipExitWrites", "immediate revocation writes"),
        ("volunteerJoinCodes", "separate volunteer code collection"),
        ('status: "pendingApproval"', "pending-before-access state"),
    ]:
        require(sources["worker"], token, label, errors)

    for token, label in [
        ("match /volunteerJoinCodes/{code}", "private invite-code rule"),
        ("match /volunteerServices/{classId}", "user mirror rule"),
        ("match /volunteerRequests/{uid}", "teacher request rule"),
        ("isClassVolunteer(classId)", "active volunteer support scope"),
    ]:
        require(sources["rules"], token, label, errors)

    for token, label in [
        ("VolunteerServiceStatus", "service lifecycle model"),
        ("func requestVolunteerService", "iOS request transport"),
        ("func removeVolunteerService", "iOS removal transport"),
        ("func volunteerInviteCode", "persisted invite-code lookup"),
        ("func startVolunteerServiceListener", "volunteer realtime service listener"),
        ("func startClassroomVolunteerListener", "teacher realtime request listener"),
    ]:
        require(sources["service"], token, label, errors)

    for token, label in [
        ("func loadVolunteerServices", "volunteer orchestration"),
        ("func loadClassroomVolunteers", "teacher orchestration"),
        ("func reviewVolunteerService", "approval orchestration"),
        ("func removeVolunteerService", "revocation orchestration"),
        ("startVolunteerServiceSyncIfNeeded", "volunteer realtime orchestration"),
        ("startClassroomVolunteerSyncIfNeeded", "teacher realtime orchestration"),
    ]:
        require(sources["app"], token, label, errors)

    for token, label in [
        ("TeacherVolunteerServiceCard", "teacher volunteer management UI"),
        ("建立志工邀請碼", "teacher invitation action"),
        ("移除後，對方會立即失去", "teacher revocation warning"),
    ]:
        require(sources["teacher"], token, label, errors)

    for token, label in [
        ("VolunteerServiceClassesView", "volunteer class UI"),
        ("先加入服務班級，再開始接力", "least-privilege onboarding copy"),
        ("離開後會立即停止接收", "volunteer leave warning"),
        ("VolunteerNoActiveServiceCard", "no-scope empty state"),
    ]:
        require(sources["volunteer"], token, label, errors)
    require(sources["shell"], 'Label("班級", systemImage: "person.3")', "class tab", errors)

    for token, label in [
        ("VolunteerServiceScopeAcceptanceTests", "Swift acceptance suite"),
        ("testVolunteerRequiresTeacherApprovalBeforeServiceBecomesActive", "approval test"),
        ("testVolunteerCanWithdrawPendingServiceRequestWithoutReceivingClassAccess", "pending withdrawal test"),
        ("testLeavingOrDeletingClassRevokesVolunteerService", "revocation test"),
    ]:
        require(sources["tests"], token, label, errors)

    for token, label in [
        ("approved platform volunteer still needs teacher-approved class scope", "rules approval test"),
        ("teacher removal and volunteer leave revoke support access immediately", "rules revoke test"),
        ("student join code and volunteer invite code cannot be used interchangeably", "code separation test"),
        ("volunteer can withdraw a pending request without ever receiving class access", "pending withdrawal rules test"),
        ("class deletion revokes active and pending volunteer services plus the invite code", "class deletion revocation test"),
    ]:
        require(sources["rule_tests"], token, label, errors)
    require(sources["decisions"], "D-25", "decision record", errors)
    require(
        sources["privacy_rule_tests"],
        "even assigned volunteers cannot read private class learning context",
        "volunteer least-privilege regression test",
        errors,
    )

    if errors:
        print("FIX-E volunteer service scope validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("FIX-E volunteer service scope contract passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
