#!/usr/bin/env python3
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative_path: str) -> str:
    return (ROOT / relative_path).read_text(encoding="utf-8")


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def require_markers(
    label: str,
    text: str,
    markers: list[str],
    errors: list[str],
) -> None:
    for marker in markers:
        require(marker in text, f"{label} missing marker: {marker}", errors)


def main() -> int:
    errors: list[str] = []

    profile = read("ios/EnglishPlus/EnglishPlus/Models/AppUserProfile.swift")
    auth = read("ios/EnglishPlus/EnglishPlus/Services/FirebaseAuthService.swift")
    auth_contract = read("ios/EnglishPlus/EnglishPlus/Services/AuthService.swift")
    root_view = read("ios/EnglishPlus/EnglishPlus/App/RootView.swift")
    learning = read("ios/EnglishPlus/EnglishPlus/Services/FirebaseLearningRepository.swift")
    firestore_service = read(
        "ios/EnglishPlus/EnglishPlus/Services/FirebaseFirestoreService.swift"
    )
    paths = read("ios/EnglishPlus/EnglishPlus/Data/FirestorePath.swift")
    seed_mapper = read("ios/EnglishPlus/EnglishPlus/Data/FirestoreSeedMapper.swift")
    rules = read("docs/ios-testflight/firebase/firestore.rules.draft")
    report = read(
        "docs/app-store-hardening/round-02-personal-and-class-domain.md"
    )

    require_markers(
        "profile domain",
        profile,
        [
            "struct ClassMembership",
            "visibilityStartsAt",
            "let memberships: [ClassMembership]",
            "let activeClassId: String?",
            "case personal(ownerUid: String)",
            "func selectingClass(_ classId: String?)",
        ],
        errors,
    )
    require_markers(
        "auth contract",
        auth_contract + auth,
        [
            "selectActiveClass(_ classId: String?, in session: AuthSession)",
            '"activeClassId": NSNull()',
            "FirestorePath.userMemberships(uid: uid)",
            "legacyMembershipIfPresent",
            "selfServiceStudent",
        ],
        errors,
    )

    initial_profile = auth.split("private func createInitialProfileDocument", 1)[-1]
    initial_profile = initial_profile.split("private func accountSession", 1)[0]
    require(
        "FirestorePath.member" not in initial_profile,
        "new account creation still writes a class membership",
        errors,
    )
    require(
        "FirestorePath.student" not in initial_profile,
        "new account creation still writes a class student document",
        errors,
    )

    require_markers(
        "root learning-scope sync boundary",
        root_view,
        [
            "classId: currentProfile.classId",
            "profile: currentProfile",
            "learningRepository.stopRealtimeSync()",
        ],
        errors,
    )
    require(
        "restoreSessionIfPossible" not in root_view,
        "cold launch must not bypass role selection and explicit sign-in",
        errors,
    )
    require_markers(
        "personal learning persistence",
        learning + paths,
        [
            "personalCheckIn",
            "personalDailyMission",
            "personalAnswerEvent",
            "guard !FirebaseBackendConfig.isPersonalScopeId(request.classCode)",
        ],
        errors,
    )
    require(
        "if !FirebaseBackendConfig.isPersonalScopeId(record.classId)"
        in firestore_service,
        "personal consent can still be mirrored into a fake class",
        errors,
    )
    require_markers(
        "seed migration",
        seed_mapper,
        [
            "userMemberships: [String: FirestoreUserMembershipDocument]",
            "for membership in account.memberships",
            "visibilityStartsAt: membership.visibilityStartsAt",
            "activeClassId: account.activeClassId",
        ],
        errors,
    )
    require_markers(
        "firestore authorization",
        rules,
        [
            "match /classMemberships/{classId}",
            "match /personalCheckIns/{dateKey}",
            "match /practiceAssignments/{assignmentId}",
            "staffCanReadStudentTimeline",
            "createdAt >= studentVisibilityStartsAt(classId, studentUid)",
            'profile.primaryRole == "student"',
            "validActiveClassSelection(uid)",
        ],
        errors,
    )
    require_markers(
        "round report",
        report,
        [
            "Decision 1B",
            "Decision 2A",
            "Multiple active memberships",
            "Post-join visibility",
            "No Xcode Cloud trigger",
        ],
        errors,
    )

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print("App Store hardening round 2 validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
