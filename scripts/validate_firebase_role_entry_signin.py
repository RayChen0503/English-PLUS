#!/usr/bin/env python3
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
IOS_ROOT = ROOT / "ios" / "EnglishPlus" / "EnglishPlus"
PROJECT = ROOT / "ios" / "EnglishPlus" / "EnglishPlus.xcodeproj" / "project.pbxproj"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig")


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def git_ls_files() -> str:
    result = subprocess.run(
        ["git", "ls-files"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout


def main() -> int:
    errors: list[str] = []
    auth_service = read(IOS_ROOT / "Services" / "AuthService.swift")
    firebase_auth = read(IOS_ROOT / "Services" / "FirebaseAuthService.swift")
    app_state = read(IOS_ROOT / "App" / "AppState.swift")
    role_selection = read(IOS_ROOT / "Features" / "RoleSelection" / "RoleSelectionView.swift")
    project = read(PROJECT)
    gitignore = read(ROOT / ".gitignore")
    tracked = git_ls_files()

    for token in [
        "student.demo@englishplus.test",
        "teacher.demo@englishplus.test",
        "volunteer.demo@englishplus.test",
        "EnglishPlusStudent2026!",
        "EnglishPlusTeacher2026!",
        "EnglishPlusVolunteer2026!",
    ]:
        require(token in auth_service, f"AuthService missing demo credential token: {token}", errors)

    demo_login = read(IOS_ROOT / "Features" / "RoleSelection" / "DemoLoginView.swift")

    require("func signInDemoAccount(for role: UserRole) async throws -> AuthSession" in auth_service,
            "AuthService must keep async demo credential helper for seeded accounts", errors)
    require("appState.chooseRole(role)" in role_selection,
            "RoleSelection buttons must route to the credential login screen", errors)
    require("await appState.signIn(role: role)" not in role_selection,
            "RoleSelection must not skip the credential login screen", errors)
    require("route = .demoLogin(role)" in app_state,
            "AppState.chooseRole must open DemoLoginView instead of signing in directly", errors)
    require("authService.signIn(" in app_state and "email:" in app_state and "password:" in app_state,
            "AppState.signIn(email:password:role:) must call AuthService credential sign-in", errors)
    require("TextField(\"email\"" in demo_login and "SecureField(\"password\"" in demo_login,
            "DemoLoginView must render visible email and password fields", errors)
    require("await appState.signIn(email: email, password: password, role: role)" in demo_login,
            "DemoLoginView must submit typed credentials through AppState", errors)
    require("Firebase 帳號登入" in demo_login and "退回本機展示帳號" not in demo_login,
            "DemoLoginView copy must describe real Firebase login, not local fallback", errors)
    require("Auth.auth().signIn(withEmail: email, password: password)" in firebase_auth,
            "FirebaseAuthService must call Firebase Auth signIn(withEmail:password:)", errors)
    require("FirestorePath.member(classId: classId, uid: uid)" in firebase_auth,
            "FirebaseAuthService must read Firestore membership by UID", errors)
    require("roleMismatch(expected: UserRole, actual: UserRole)" in firebase_auth,
            "FirebaseAuthService must reject mismatched membership roles", errors)
    require("activeMembership" in firebase_auth or "inactiveMembership" in firebase_auth,
            "FirebaseAuthService must reject inactive memberships", errors)
    require("GoogleService-Info.plist in Resources" in project,
            "Xcode project must include GoogleService-Info.plist in resources", errors)
    require("GoogleService-Info.plist.plist" not in project,
            "Xcode project must not reference GoogleService-Info.plist.plist", errors)
    require("ios/**/GoogleService-Info*.plist" in gitignore,
            ".gitignore must protect GoogleService-Info plist files", errors)
    require("GoogleService-Info.plist" not in tracked,
            "GoogleService-Info.plist must not be tracked by git", errors)

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print("Firebase role entry sign-in validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
