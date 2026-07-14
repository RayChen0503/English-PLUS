#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def markers(content: str, expected: tuple[str, ...], label: str, errors: list[str]) -> None:
    for marker in expected:
        require(marker in content, f"{label} missing marker: {marker}", errors)


def section(content: str, start: str, end: str) -> str:
    start_index = content.index(start)
    end_index = content.index(end, start_index + len(start))
    return content[start_index:end_index]


def main() -> int:
    errors: list[str] = []
    app_state = read("ios/EnglishPlus/EnglishPlus/App/AppState.swift")
    login = read(
        "ios/EnglishPlus/EnglishPlus/Features/RoleSelection/DemoLoginView.swift"
    )
    firebase_auth = read(
        "ios/EnglishPlus/EnglishPlus/Services/FirebaseAuthService.swift"
    )
    institution = read(
        "ios/EnglishPlus/EnglishPlus/Features/RoleSelection/InstitutionPickerView.swift"
    )
    volunteer = read(
        "ios/EnglishPlus/EnglishPlus/Features/Volunteer/VolunteerApplicationView.swift"
    )
    acceptance_tests = read(
        "ios/EnglishPlus/EnglishPlusTests/AuthenticationFlowAcceptanceTests.swift"
    )
    project = read("ios/EnglishPlus/EnglishPlus.xcodeproj/project.pbxproj")
    scheme = read(
        "ios/EnglishPlus/EnglishPlus.xcodeproj/xcshareddata/xcschemes/EnglishPlus.xcscheme"
    )
    workflow = read(".github/workflows/ios-hardening-build.yml")
    report = read(
        "docs/app-store-hardening/testflight-onboarding-hotfix.md"
    )
    email_registration = section(
        firebase_auth,
        "func createAccount(_ registration:",
        "func signIn(\n        with credential:",
    )
    provider_sign_in = section(
        firebase_auth,
        "func signIn(\n        with credential:",
        "func createAccount(\n        with credential:",
    )

    markers(
        app_state,
        (
            "authError == .profileUnavailable",
            "federatedOnboardingCredential = credential",
            "federatedOnboardingProvider = credential.provider",
            "func completeFederatedOnboarding(profile:",
            "func cancelFederatedOnboarding()",
            "clearFederatedOnboardingState()",
        ),
        "First-use federated onboarding state",
        errors,
    )
    markers(
        provider_sign_in,
        (
            "Keep the just-authenticated Firebase session",
            "catch let error as AuthServiceError where error == .profileUnavailable",
            "Apple credentials should not be replayed",
        ),
        "Firebase provider sign-in session retention",
        errors,
    )
    require(
        "Keep the just-authenticated Firebase session" not in email_registration,
        "Provider-only session retention leaked into Email account creation.",
        errors,
    )
    markers(
        firebase_auth,
        (
            "if let currentUser = Auth.auth().currentUser",
            "Self.firebaseUser(currentUser, uses: credential.provider)",
            "firebaseUser = currentUser",
        ),
        "Firebase first-use session",
        errors,
    )
    markers(
        login,
        (
            "GoogleSignInButton(",
            "SignInWithAppleButton(",
            "appState.signingInRole != nil",
            "\\(provider.displayName) 驗證完成",
            "完成\\(role.title)帳號設定",
            "await appState.signIn(with: credential, role: role)",
            "await appState.completeFederatedOnboarding(profile: profile)",
        ),
        "Provider-neutral sign-in and creation UI",
        errors,
    )
    require(
        "(mode == .register && registrationProfile == nil)" not in login,
        "Provider buttons are still disabled until the registration form is complete.",
        errors,
    )
    require(
        "switch mode {\n        case .signIn:\n            await appState.signIn(with:" not in login,
        "Provider handling still splits sign-in and account creation before identity lookup.",
        errors,
    )

    markers(
        institution,
        (
            "從教育機構名錄選擇",
            "directory.institutions.count.formatted()",
            "輸入至少 2 個字",
            "輸入內容不會直接當作學校名稱保存",
            "不代表 English+ 已驗證教師資格",
            "source: .userSubmitted",
        ),
        "Teacher institution selection",
        errors,
    )
    markers(
        login + volunteer,
        (
            "第 1 步，共 2 步",
            "第 2 步，共 2 步",
            "上傳證明並送出審核",
            ".fileImporter(",
            "至少加入一份資格證明後即可送出",
        ),
        "Two-stage volunteer application",
        errors,
    )
    markers(
        report,
        (
            "Google / Apple",
            "3,921",
            "Firebase UID",
            "Xcode Cloud",
        ),
        "Hotfix report",
        errors,
    )
    markers(
        acceptance_tests,
        (
            "testFirstGoogleIdentityWithoutProfileStartsStudentOnboarding",
            "testFirstAppleIdentityCompletesTeacherProfileWithoutReplayingSignIn",
            "testReturningProviderAccountEntersItsRoleDirectly",
            "testWrongRoleDoesNotCreateAnotherProfile",
            "testEmailRegistrationStopsAtVerificationInsteadOfEnteringApp",
            "testNewVolunteerReachesEvidenceUploadBeforeApproval",
            "testRestoredSessionSkipsRoleSelectionButStillHonorsConsent",
            "testExistingEmailCollisionLinksProviderAfterOriginalLogin",
            "testSwitchingRoleDuringFirstUseCancelsAuthenticatedIdentity",
            "testPendingVolunteerCannotEnterProtectedHome",
            "testSignOutClearsAuthenticatedStateAndReturnsToRoleSelection",
            "testRestoredConsentEntersHomeWithoutShowingAgreementAgain",
        ),
        "Executable authentication acceptance suite",
        errors,
    )
    markers(
        project + scheme + workflow,
        (
            "EnglishPlusTests.xctest",
            "AuthenticationFlowAcceptanceTests.swift in Sources",
            "Run Swift unit and integration tests",
            "-only-testing:EnglishPlusTests",
            "xcodebuild \\",
            "test",
        ),
        "macOS authentication test gate",
        errors,
    )

    if errors:
        print("TestFlight onboarding hotfix validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("TestFlight onboarding hotfix validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
