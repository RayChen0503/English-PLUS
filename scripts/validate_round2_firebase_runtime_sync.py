#!/usr/bin/env python3
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
IOS_ROOT = ROOT / "ios" / "EnglishPlus" / "EnglishPlus"
SERVICES = IOS_ROOT / "Services"
APP = IOS_ROOT / "App"


def read(path):
    return path.read_text(encoding="utf-8")


def require(condition, message, errors):
    if not condition:
        errors.append(message)


def main():
    errors = []
    auth_service = SERVICES / "AuthService.swift"
    firebase_auth = SERVICES / "FirebaseAuthService.swift"
    app_state = APP / "AppState.swift"
    root_view = APP / "RootView.swift"
    learning_store = SERVICES / "LearningRepositoryStore.swift"
    firebase_repo = SERVICES / "FirebaseLearningRepository.swift"
    project = ROOT / "ios" / "EnglishPlus" / "EnglishPlus.xcodeproj" / "project.pbxproj"

    for path in [auth_service, firebase_auth, app_state, root_view, learning_store, firebase_repo, project]:
        require(path.exists(), f"missing {path.relative_to(ROOT)}", errors)

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    auth_text = read(auth_service)
    firebase_auth_text = read(firebase_auth)
    app_state_text = read(app_state)
    root_text = read(root_view)
    store_text = read(learning_store)
    repo_text = read(firebase_repo)
    project_text = read(project)

    require(
        "func restorePreviousSession() async throws -> AuthSession?" in auth_text,
        "AuthService must expose restorePreviousSession()",
        errors,
    )
    require(
        "authService.restorePreviousSession()" in app_state_text,
        "AppState must call AuthService.restorePreviousSession()",
        errors,
    )
    require(
        "func restoreSessionIfPossible() async" in app_state_text,
        "AppState must expose restoreSessionIfPossible()",
        errors,
    )
    require(
        ".task" in root_text and "restoreSessionIfPossible" in root_text,
        "RootView must attempt session restore on launch",
        errors,
    )
    require(
        "currentSession() async throws -> AuthSession?" in firebase_auth_text,
        "FirebaseAuthService must restore Firebase currentSession",
        errors,
    )

    for token in [
        "listenSupportThreads",
        "listenStudentMissions",
        "listenStudentAttempts",
        "listenSupportMessages",
        "mission(from:",
        "attempt(from:",
        "supportReply(from:",
        "mergeSupportRequests",
        "replaceMission",
        "replaceAttempts",
    ]:
        require(token in repo_text, f"FirebaseLearningRepository missing realtime sync token: {token}", errors)

    require(
        repo_text.count("addSnapshotListener") >= 4,
        "FirebaseLearningRepository must listen to support threads, messages, missions, and attempts",
        errors,
    )
    require(
        "updateSyncStatus" in store_text and "offlineFallback" in store_text,
        "LearningRepositoryStore must expose backend listener failures",
        errors,
    )
    require(
        "learningRepository.stopRealtimeSync()" in root_text,
        "RootView must stop realtime sync outside signed-in home routes",
        errors,
    )
    require(
        "GoogleService-Info.plist in Resources" in project_text,
        "Xcode project must include GoogleService-Info.plist in resources for real Firebase runtime",
        errors,
    )

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print("Round 2 Firebase runtime sync validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
