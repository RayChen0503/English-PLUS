#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def require_markers(content: str, markers: tuple[str, ...], label: str, errors: list[str]) -> None:
    for marker in markers:
        require(marker in content, f"{label} missing marker: {marker}", errors)


def main() -> int:
    errors: list[str] = []
    root = read("ios/EnglishPlus/EnglishPlus/App/RootView.swift")
    store = read("ios/EnglishPlus/EnglishPlus/Services/LearningRepositoryStore.swift")
    firebase = read("ios/EnglishPlus/EnglishPlus/Services/FirebaseLearningRepository.swift")
    local = read("ios/EnglishPlus/EnglishPlus/Services/MockLearningRepository.swift")
    home = read("ios/EnglishPlus/EnglishPlus/Features/Student/StudentHomeView.swift")
    practice = read("ios/EnglishPlus/EnglishPlus/Features/Practice/PracticeCenterView.swift")
    support = read("ios/EnglishPlus/EnglishPlus/Features/Support/SupportView.swift")
    classroom = read("ios/EnglishPlus/EnglishPlus/Features/Student/StudentClassroomView.swift")
    rules = read("docs/ios-testflight/firebase/firestore.rules.draft")
    decisions = read("docs/app-store-hardening/DECISIONS.md")
    report = read("docs/app-store-hardening/round-05-personal-learning-mode.md")

    require(
        "let activeClassId = currentProfile.activeClassId" not in root,
        "RootView still blocks realtime sync when a student has no class",
        errors,
    )
    require_markers(
        root + store,
        (
            "classId: currentProfile.classId",
            "profile: currentProfile",
            "func startRealtimeSync(classId: String, user: DemoUser?, profile: AppUserProfile?)",
        ),
        "personal sync entry",
        errors,
    )
    require_markers(
        firebase,
        (
            "listenPersonalCheckIn",
            "listenPersonalMission",
            "listenPersonalAttempts",
            "listenPersonalLearningFlow",
            "FirestorePath.personalCheckIn",
            "FirestorePath.personalDailyMission",
            "FirestorePath.personalAnswerEvent",
            "FirestorePath.userLearningSettings",
            "mirrorLearningFlowIfPossible",
            "currentSnapshot.supportRequests = []",
            "currentSnapshot.assignedPracticeTasks = []",
        ),
        "personal Firestore repository",
        errors,
    )
    require_markers(
        local,
        (
            "func activatePersistenceScope(uid: String)",
            "func replaceRuntimeSnapshot(_ snapshot: LearningRepositorySnapshot)",
            "func scoped(for uid: String) -> any LocalLearningPersistence",
            'key: "\\(baseKey).\\(safeUid)"',
            "supportRequests = []",
            "assignedPracticeTasks = []",
        ),
        "account-scoped local persistence",
        errors,
    )
    require_markers(
        firebase,
        (
            "synchronizeFallbackWithCurrentSnapshot",
            "fallback.replaceRuntimeSnapshot(currentSnapshot)",
        ),
        "remote-to-runtime hydration",
        errors,
    )
    require_markers(
        home + practice,
        (
            "canRequestHumanSupport: appState.currentProfile?.activeClassId != nil",
            "guard appState.currentProfile?.activeClassId != nil else { return }",
            "加入班級後",
        ),
        "personal-mode help UX",
        errors,
    )
    require_markers(
        support + classroom,
        ("目前是個人學習模式", "個人學習模式", "目前沒有班級任務"),
        "personal-mode empty states",
        errors,
    )
    require_markers(
        rules,
        (
            "match /personalCheckIns/{dateKey}",
            "match /personalDailyMissions/{missionId}",
            "match /personalAnswerEvents/{eventId}",
            "match /settings/{settingId}",
        ),
        "personal Firestore rules",
        errors,
    )
    require_markers(decisions, ("D-15", "D-16", "D-17"), "Block B decisions", errors)
    require("Round 5" in report and "Complete" in report, "Round 5 report is incomplete", errors)

    if errors:
        print("App Store hardening round 5 validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("App Store hardening round 5 personal learning validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
