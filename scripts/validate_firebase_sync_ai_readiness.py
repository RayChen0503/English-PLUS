#!/usr/bin/env python3
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
IOS_ROOT = ROOT / "ios" / "EnglishPlus" / "EnglishPlus"
SERVICES = IOS_ROOT / "Services"
FEATURES = IOS_ROOT / "Features"

FILES = {
    "project": ROOT / "ios" / "EnglishPlus" / "EnglishPlus.xcodeproj" / "project.pbxproj",
    "gitignore": ROOT / ".gitignore",
    "factory": SERVICES / "FirebaseAppConfigurator.swift",
    "firebase_auth": SERVICES / "FirebaseAuthService.swift",
    "firebase_firestore": SERVICES / "FirebaseFirestoreService.swift",
    "learning_store": SERVICES / "LearningRepositoryStore.swift",
    "firebase_learning": SERVICES / "FirebaseLearningRepository.swift",
    "mock_learning": SERVICES / "MockLearningRepository.swift",
    "remote_ai": SERVICES / "RemoteAIService.swift",
    "mock_ai_proxy": SERVICES / "MockAiProxyService.swift",
    "app": IOS_ROOT / "App" / "EnglishPlusApp.swift",
    "root": IOS_ROOT / "App" / "RootView.swift",
    "student": FEATURES / "Student" / "StudentHomeView.swift",
    "practice": FEATURES / "Practice" / "PracticeCenterView.swift",
    "support": FEATURES / "Support" / "SupportView.swift",
    "teacher": FEATURES / "Teacher" / "TeacherHomeView.swift",
    "volunteer": FEATURES / "Volunteer" / "VolunteerHomeView.swift",
    "rules": ROOT / "docs" / "ios-testflight" / "firebase" / "firestore.rules.draft",
    "functions": ROOT / "functions" / "src" / "index.ts",
}


def read(path):
    return path.read_text(encoding="utf-8")


def require(condition, message, errors):
    if not condition:
        errors.append(message)


def validate_files(errors):
    for name, path in FILES.items():
        require(path.exists(), f"missing {name}: {path.relative_to(ROOT)}", errors)


def validate_firebase_ready(errors):
    factory = read(FILES["factory"])
    auth = read(FILES["firebase_auth"])
    firestore = read(FILES["firebase_firestore"])
    app = read(FILES["app"])
    project = read(FILES["project"])
    gitignore = read(FILES["gitignore"])

    for token in [
        "FirebaseAppConfigurator",
        "hasBundledConfig",
        "GoogleService-Info",
        "configureIfPossible",
        "EnglishPlusServiceFactory",
        "RemoteAIService",
        "FirebaseLearningRepository",
        "MockLearningRepository",
    ]:
        require(token in factory, f"service factory missing {token}", errors)

    for token in [
        "#if canImport(FirebaseAuth)",
        "struct FirebaseAuthService",
        "currentIdToken",
        "currentSession",
        "FirebaseAuthServiceError",
        "MockAuthService",
    ]:
        require(token in auth, f"FirebaseAuthService missing {token}", errors)

    for token in [
        "#if canImport(FirebaseFirestore)",
        "final class FirebaseFirestoreService",
        "startConsentListener",
        "FirestorePath.userConsent",
        "FirestorePath.studentConsent",
        "MockFirestoreService",
    ]:
        require(token in firestore, f"FirebaseFirestoreService missing {token}", errors)

    require("EnglishPlusServiceFactory.makeServices()" in app, "EnglishPlusApp must use service factory", errors)
    for token in [
        "FirebaseAppConfigurator.swift",
        "FirebaseAuthService.swift",
        "FirebaseFirestoreService.swift",
        "LearningRepositoryStore.swift",
        "FirebaseLearningRepository.swift",
    ]:
        require(token in project, f"Xcode project missing {token}", errors)
    require("ios/**/GoogleService-Info.plist" in gitignore, "GoogleService-Info.plist must stay ignored", errors)
    require(not list(ROOT.glob("**/GoogleService-Info.plist")), "GoogleService-Info.plist must not be committed", errors)


def validate_sync_ready(errors):
    store = read(FILES["learning_store"])
    firebase_learning = read(FILES["firebase_learning"])
    root = read(FILES["root"])
    combined_views = "\n".join(read(FILES[key]) for key in ["student", "practice", "support", "teacher", "volunteer"])

    for token in [
        "protocol LearningRepositoryBackend",
        "LearningRepositorySnapshot",
        "LearningRepositorySyncStatus",
        "startRealtimeSync",
        "startRealtimeListener",
        "teacherQueue",
        "volunteerQueue",
        "staffStudentSummaries",
    ]:
        require(token in store, f"LearningRepositoryStore missing {token}", errors)

    for token in [
        "final class FirebaseLearningRepository",
        "FirestorePath.checkIn",
        "FirestorePath.dailyMission",
        "FirestorePath.answerEvent",
        "FirestorePath.supportThread",
        "FirestorePath.supportMessage",
        "addSnapshotListener",
        "setData(data, merge: true)",
        "mirrorSupportRequestIfPossible",
        "mirrorUpdatedSupportRequestIfPossible",
    ]:
        require(token in firebase_learning, f"FirebaseLearningRepository missing {token}", errors)

    require("learningRepository.startRealtimeSync" in root, "RootView must start repository realtime sync", errors)
    require("MockLearningRepository" not in combined_views, "user flow views must depend on LearningRepositoryStore, not MockLearningRepository", errors)
    require(combined_views.count("LearningRepositoryStore") >= 5, "main role views should use LearningRepositoryStore", errors)


def validate_ai_ready(errors):
    remote_ai = read(FILES["remote_ai"])
    mock_ai = read(FILES["mock_ai_proxy"])
    functions = read(FILES["functions"])
    ios_swift = "\n".join(path.read_text(encoding="utf-8") for path in IOS_ROOT.rglob("*.swift"))

    for token in [
        "timeoutInterval",
        "AI_PROXY_TIMEOUT",
        "AI_PROXY_INVALID_RESPONSE",
        "AI_PROXY_TASK_MISMATCH",
        "taskTypeMismatch",
        "fallbackResponse",
    ]:
        require(token in remote_ai, f"RemoteAIService missing {token}", errors)

    require("AI 代理尚未連線" not in mock_ai, "mock AI fallback must not expose technical proxy status", errors)
    require("OPENROUTER_API_KEY" not in ios_swift, "iOS Swift must not reference OPENROUTER_API_KEY", errors)
    require("https://openrouter.ai" not in ios_swift, "iOS Swift must not call OpenRouter directly", errors)
    for token in ["export const englishPlusAiProxy", "OPENROUTER_API_KEY", "taskRoleAccess", "buildFallbackResponse"]:
        require(token in functions, f"Cloud Functions AI proxy missing {token}", errors)


def validate_rules(errors):
    rules = read(FILES["rules"])
    for token in [
        "match /checkIns/{dateKey}",
        "match /dailyMissions/{missionId}",
        "match /answerEvents/{eventId}",
        "match /supportThreads/{threadId}",
        "match /messages/{messageId}",
        "isClassTeacher",
        "isClassVolunteer",
        "canReadThread",
        "canWriteStaffReply",
    ]:
        require(token in rules, f"Firestore rules missing {token}", errors)


def validate_no_user_technical_text(errors):
    view_text = "\n".join(path.read_text(encoding="utf-8") for path in FEATURES.rglob("*.swift"))
    for token in ["OpenRouter", "Firebase", "Mock", "mock", "debug", "AI 代理", "Cloud Functions"]:
        require(token not in view_text, f"user-facing view code should not contain technical token {token}", errors)


def main():
    errors = []
    validate_files(errors)
    if not errors:
        validate_firebase_ready(errors)
        validate_sync_ready(errors)
        validate_ai_ready(errors)
        validate_rules(errors)
        validate_no_user_technical_text(errors)

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print("Firebase sync AI readiness validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
