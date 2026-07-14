from pathlib import Path
import plistlib
import sys


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


privacy_manifest = plistlib.loads(
    (ROOT / "ios/EnglishPlus/EnglishPlus/PrivacyInfo.xcprivacy").read_bytes()
)
crash_data_entries = [
    entry
    for entry in privacy_manifest.get("NSPrivacyCollectedDataTypes", [])
    if entry.get("NSPrivacyCollectedDataType") == "NSPrivacyCollectedDataTypeCrashData"
]


checks = {
    "adaptive theme colors": all(
        token in read("ios/EnglishPlus/EnglishPlus/Core/EPTheme.swift")
        for token in [
            "traits.userInterfaceStyle == .dark",
            "successSurface",
            "warningSurface",
            "dangerSurface",
            "accessibilityReduceMotion",
        ]
    ),
    "semantic content states": all(
        token in read("ios/EnglishPlus/EnglishPlus/Features/Shared/RepositorySyncBanner.swift")
        for token in [
            "enum EPContentState",
            "struct EPContentStateView",
            "content.state.loading",
            "content.state.empty",
            "content.state.failure",
        ]
    ),
    "privacy-safe diagnostics": all(
        token in read("ios/EnglishPlus/EnglishPlus/Core/AppDiagnostics.swift")
        for token in [
            "FirebaseCrashlytics",
            "setCrashlyticsCollectionEnabled",
            "deleteUnsentReports",
            "record(error: report)",
            "app_role",
            "app_route",
            "case aiProxy",
        ]
    ) and all(
        forbidden not in read("ios/EnglishPlus/EnglishPlus/Core/AppDiagnostics.swift")
        for forbidden in ["setUserID", "currentUser?.displayName", "currentUser?.email", "moodScore"]
    ),
    "crash collection defaults off": "<key>FirebaseCrashlyticsCollectionEnabled</key>\n\t<false/>"
    in read("ios/EnglishPlus/EnglishPlus/Info.plist"),
    "crash privacy manifest is unlinked and non-tracking": len(crash_data_entries) == 1
    and crash_data_entries[0].get("NSPrivacyCollectedDataTypeLinked") is False
    and crash_data_entries[0].get("NSPrivacyCollectedDataTypeTracking") is False
    and "NSPrivacyCollectedDataTypePurposeAppFunctionality"
    in crash_data_entries[0].get("NSPrivacyCollectedDataTypePurposes", []),
    "crash symbols configured": all(
        token in read("ios/EnglishPlus/EnglishPlus.xcodeproj/project.pbxproj")
        for token in [
            "FirebaseCrashlytics in Frameworks",
            "Upload Crashlytics Symbols",
            "firebase-ios-sdk/Crashlytics/run",
            "AppDiagnostics.swift in Sources",
        ]
    ),
    "diagnostic opt-out control": all(
        token in read("ios/EnglishPlus/EnglishPlus/Features/Shared/AccountDataView.swift")
        for token in [
            "分享當機與穩定性診斷",
            "AppDiagnostics.shared.setCollectionEnabled",
            "不傳送姓名、Email、題目內容、心情分數或班級名稱",
        ]
    ),
    "diagnostics require explicit opt-in": all(
        token in read("ios/EnglishPlus/EnglishPlus/Features/Consent/ConsentView.swift")
        for token in [
            "選用：當機與穩定性診斷",
            "未開啟也能完整使用",
            "consent.diagnostics",
        ]
    ) and "enableAfterPrivacyConsentIfNeeded" not in read(
        "ios/EnglishPlus/EnglishPlus/App/RootView.swift"
    ),
    "adaptive staff metrics": "ViewThatFits(in: .horizontal)"
    in read("ios/EnglishPlus/EnglishPlus/Features/Shared/StaffSupportActionBar.swift"),
    "dark and large type ui coverage": all(
        token in read("ios/EnglishPlus/EnglishPlusUITests/EnglishPlusCriticalFlowsUITests.swift")
        for token in [
            "testDarkModeAndAccessibilityTextKeepRoleChoiceUsable",
            "testDarkModeLargeTextStudentFlowKeepsPrimaryActionsReachable",
            "UICTContentSizeCategoryAccessibilityExtraExtraLarge",
        ]
    ),
    "small and large device ci matrix": all(
        token in read(".github/workflows/ios-hardening-build.yml")
        for token in [
            "Run dark mode and Dynamic Type device matrix",
            '"SE" in device["name"]',
            '"Pro Max" in device["name"]',
            "EnglishPlusAppearance-*.xcresult",
        ]
    ),
    "no forced light mode": ".preferredColorScheme(.light)"
    not in "\n".join(
        path.read_text(encoding="utf-8")
        for path in (ROOT / "ios/EnglishPlus/EnglishPlus").rglob("*.swift")
    ),
}

failed = [name for name, passed in checks.items() if not passed]
for name, passed in checks.items():
    print(f"[{'PASS' if passed else 'FAIL'}] {name}")

if failed:
    print("Round 19 validation failed: " + ", ".join(failed), file=sys.stderr)
    sys.exit(1)

print("Round 19 accessibility, appearance, state and diagnostics contracts passed.")
