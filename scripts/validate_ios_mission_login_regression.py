#!/usr/bin/env python3
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[1]
IOS = ROOT / "ios" / "EnglishPlus" / "EnglishPlus"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def main() -> int:
    errors: list[str] = []
    root_view = IOS / "App" / "RootView.swift"
    app_state = IOS / "App" / "AppState.swift"
    student_home = IOS / "Features" / "Student" / "StudentHomeView.swift"
    mock_repo = IOS / "Services" / "MockLearningRepository.swift"
    auth_service = IOS / "Services" / "AuthService.swift"
    firebase_auth = IOS / "Services" / "FirebaseAuthService.swift"
    firestore_service = IOS / "Services" / "FirestoreService.swift"
    firebase_firestore = IOS / "Services" / "FirebaseFirestoreService.swift"
    demo_login = IOS / "Features" / "RoleSelection" / "DemoLoginView.swift"

    required_paths = [
        root_view,
        app_state,
        student_home,
        mock_repo,
        auth_service,
        firebase_auth,
        firestore_service,
        firebase_firestore,
        demo_login,
    ]
    for path in required_paths:
        require(path.exists(), f"missing {path.relative_to(ROOT)}", errors)

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    root_text = read(root_view)
    app_state_text = read(app_state)
    student_text = read(student_home)
    mock_text = read(mock_repo)
    auth_text = read(auth_service)
    firebase_auth_text = read(firebase_auth)
    firestore_text = read(firestore_service)
    firebase_firestore_text = read(firebase_firestore)
    demo_login_text = read(demo_login)

    require(
        "restoreSessionIfPossible()" not in root_text,
        "RootView must not auto-restore a Firebase session and skip role/login on cold launch.",
        errors,
    )
    require(
        "await firestoreService.loadConsentRecord" in app_state_text,
        "AppState sign-in must fetch persisted consent before deciding whether to show consent.",
        errors,
    )
    require(
        "func createAccount(" in auth_text
        and "func createAccount(" in firebase_auth_text
        and "Auth.auth().createUser" in firebase_auth_text,
        "Auth services must expose and implement Firebase account creation.",
        errors,
    )
    require(
        "LoginMode.register" in demo_login_text
        and 'Text("建立帳號")' in demo_login_text
        and "appState.createAccount" in demo_login_text,
        "DemoLoginView must expose account creation for the selected role.",
        errors,
    )
    require(
        "func loadConsentRecord(uid: String) async -> PrivacyConsentRecord?" in firestore_text
        and "func loadConsentRecord(uid: String) async -> PrivacyConsentRecord?" in firebase_firestore_text,
        "Firestore service must support async consent loading from Firestore.",
        errors,
    )
    require(
        "let activeMissionQuestion = learningRepository.nextMissionQuestion" in student_text,
        "Student mission UI must bind display/submission to the repository nextMissionQuestion.",
        errors,
    )
    require(
        "currentMission?.questions.firstIndex { $0.id == item.id }" in student_text
        and "balancedQuestions.firstIndex" not in student_text,
        "Mission question index must use mission source order, not a separate balanced order.",
        errors,
    )
    require(
        "typesRespectingStudentPreference" in mock_text
        and "aiSelectedTypes.filter" in mock_text,
        "Daily mission AI plans must be constrained by the student's selected question types.",
        errors,
    )
    require(
        "let sameTypeCandidates = (exactMatches + typeMatches).uniqued(by: \\.id)" in mock_text
        and "let levelMatches = cachedQuestionBankItems.filter" not in mock_text,
        "Daily mission fallback must preserve selected question types before considering broad fallback.",
        errors,
    )

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print("iOS mission/login regression checks passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
