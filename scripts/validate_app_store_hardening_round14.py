#!/usr/bin/env python3
"""Validate Round 14 deterministic XCTest, UI-test, and CI quality gates."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def require_markers(
    content: str,
    expected: tuple[str, ...],
    label: str,
    errors: list[str],
) -> None:
    for marker in expected:
        require(marker in content, f"{label} missing marker: {marker}", errors)


def main() -> int:
    errors: list[str] = []
    project = read("ios/EnglishPlus/EnglishPlus.xcodeproj/project.pbxproj")
    scheme = read(
        "ios/EnglishPlus/EnglishPlus.xcodeproj/xcshareddata/xcschemes/EnglishPlus.xcscheme"
    )
    launch = read(
        "ios/EnglishPlus/EnglishPlus/App/EnglishPlusLaunchConfiguration.swift"
    )
    app = read("ios/EnglishPlus/EnglishPlus/App/EnglishPlusApp.swift")
    factory = read(
        "ios/EnglishPlus/EnglishPlus/Services/FirebaseAppConfigurator.swift"
    )
    store = read(
        "ios/EnglishPlus/EnglishPlus/Services/LearningRepositoryStore.swift"
    )
    unit_tests = read(
        "ios/EnglishPlus/EnglishPlusTests/AuthenticationFlowAcceptanceTests.swift"
    )
    ui_tests = read(
        "ios/EnglishPlus/EnglishPlusUITests/EnglishPlusCriticalFlowsUITests.swift"
    )
    roles = read(
        "ios/EnglishPlus/EnglishPlus/Features/RoleSelection/RoleSelectionView.swift"
    )
    login = read(
        "ios/EnglishPlus/EnglishPlus/Features/RoleSelection/DemoLoginView.swift"
    )
    consent = read(
        "ios/EnglishPlus/EnglishPlus/Features/Consent/ConsentView.swift"
    )
    sync_banner = read(
        "ios/EnglishPlus/EnglishPlus/Features/Shared/RepositorySyncBanner.swift"
    )
    workflow = read(".github/workflows/ios-hardening-build.yml")
    report = read("docs/app-store-hardening/round-14-automated-quality-gates.md")

    require_markers(
        project + scheme,
        (
            "EnglishPlusUITests",
            "com.apple.product-type.bundle.ui-testing",
            "EnglishPlusCriticalFlowsUITests.swift in Sources",
            "TEST_TARGET_NAME = EnglishPlus",
            'BuildableName = "EnglishPlusUITests.xctest"',
        ),
        "Xcode UI-test target",
        errors,
    )
    require_markers(
        launch + app + factory,
        (
            "-EnglishPlusUITesting",
            "-EnglishPlusResetState",
            "-EnglishPlusStartOffline",
            "EnglishPlusLaunchConfiguration.prepareProcessIfNeeded()",
            "EnglishPlusLaunchConfiguration.isUITesting",
            "return makeMockServices()",
            "LaunchArgumentNetworkConnectivityMonitor",
        ),
        "deterministic launch boundary",
        errors,
    )
    require_markers(
        roles + login + consent,
        (
            'accessibilityIdentifier("role.\\(role.rawValue)")',
            '"auth.email"',
            'accessibilityIdentifier("auth.password")',
            'accessibilityIdentifier("auth.submit")',
            '"consent.privacy"',
            '"consent.ai"',
            '"consent.guardian"',
            '"consent.continue"',
        ),
        "stable UI identifiers",
        errors,
    )
    for test_name in (
        "testColdLaunchShowsRoleChoiceAndLegalEntryPoints",
        "testStudentCanSignInAcceptConsentAndReachStudentNavigation",
        "testTeacherCanSignInAcceptConsentAndReachTeacherNavigation",
        "testVolunteerCanSignInAcceptConsentAndReachVolunteerNavigation",
        "testOfflineStudentStillReachesNavigationAndSeesRecoveryAction",
    ):
        require(test_name in ui_tests, f"critical UI test is missing: {test_name}", errors)
    require(
        ".accessibilityElement(children: .contain)" in sync_banner,
        "offline recovery button is hidden inside a combined accessibility element",
        errors,
    )

    for test_name in (
        "testSnapshotFromCancelledScopeCannotReplaceCurrentScope",
        "testErrorFromCancelledScopeCannotScheduleRetryForCurrentScope",
    ):
        require(test_name in unit_tests, f"scope isolation test is missing: {test_name}", errors)
    require(
        store.count("syncContext?.scopeKey == context.scopeKey") >= 3,
        "listener success and failure callbacks are not both scope-guarded",
        errors,
    )
    require_markers(
        workflow,
        (
            ".github/ci-triggers/round14-test-quality",
            "validate_app_store_hardening_round14.py",
            "Run Swift unit and integration tests",
            "-only-testing:EnglishPlusTests",
            "Run critical role UI tests",
            "-only-testing:EnglishPlusUITests",
            "-parallel-testing-enabled NO",
            "-test-timeouts-enabled YES",
            "EnglishPlusUnitTests.xcresult",
            "EnglishPlusUITests.xcresult",
            "actions/upload-artifact@v4",
            "Validate Firestore rules and classroom lifecycle",
        ),
        "macOS quality gate",
        errors,
    )
    require_markers(
        report,
        (
            "Round 14",
            "EnglishPlusUITests",
            "Firebase Emulator",
            "No Xcode Cloud",
        ),
        "Round 14 evidence",
        errors,
    )

    if errors:
        print("App Store hardening round 14 validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("App Store hardening round 14 automated quality-gate validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
