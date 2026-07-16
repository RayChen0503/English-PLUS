#!/usr/bin/env python3
import plistlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PRIVACY_URL = (
    "https://sites.google.com/view/englishplus-privacy/"
    "%E9%9A%B1%E7%A7%81%E6%94%BF%E7%AD%96"
)
SUPPORT_URL = (
    "https://sites.google.com/view/englishplus-privacy/"
    "%E6%94%AF%E6%8F%B4%E8%88%87%E8%81%AF%E7%B5%A1"
)
SUPPORT_EMAIL = "englishplus.tw@gmail.com"


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8-sig")


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def markers(content: str, expected: tuple[str, ...], label: str, errors: list[str]) -> None:
    for marker in expected:
        require(marker in content, f"{label} missing marker: {marker}", errors)


def main() -> int:
    errors: list[str] = []
    model = read("ios/EnglishPlus/EnglishPlus/Models/PrivacyConsent.swift")
    consent = read("ios/EnglishPlus/EnglishPlus/Features/Consent/ConsentView.swift")
    role_selection = read(
        "ios/EnglishPlus/EnglishPlus/Features/RoleSelection/RoleSelectionView.swift"
    )
    account = read("ios/EnglishPlus/EnglishPlus/Features/Shared/AccountDataView.swift")
    app_state = read("ios/EnglishPlus/EnglishPlus/App/AppState.swift")
    firestore = read("ios/EnglishPlus/EnglishPlus/Services/FirebaseFirestoreService.swift")
    project = read("ios/EnglishPlus/EnglishPlus.xcodeproj/project.pbxproj")
    privacy_label = read("docs/ios-testflight/privacy/app-privacy-label-draft.md")
    action_package = read("docs/ios-testflight/testflight-action-package.md")
    test_info = read("docs/ios-testflight/testflight/app-store-connect-test-info.md")
    decisions = read("docs/app-store-hardening/DECISIONS.md")
    report = read("docs/app-store-hardening/round-12-privacy-support-block-c-audit.md")
    workflow = read(".github/workflows/ios-hardening-build.yml")

    markers(model, (
        'currentVersion = "privacy-v3-2026-07-16"',
        SUPPORT_EMAIL,
        'privacyPolicyURL = publicPageURL(pathComponent: "隱私政策")',
        'supportURL = publicPageURL(pathComponent: "支援與聯絡")',
        'components.host = "sites.google.com"',
        'components.path = "/view/englishplus-privacy/\\(pathComponent)"',
        "case volunteerEvidence",
        "requiredCategories(for role: UserRole)",
        "guardianConsentStatus: GuardianConsentStatus",
        "LegalSupportConfiguration.privacyPolicyURL.absoluteString",
        "Cloudflare",
        "Groq AI",
    ), "Privacy model", errors)
    require("https://example.edu" not in model, "Privacy model still contains a placeholder URL", errors)

    markers(consent, (
        'title: "第三方 AI 處理"',
        'studentAccessPath == .age13OrOlder',
        'studentAccessPath == .schoolOrGuardianManaged',
        'Label("此帳號已在註冊時確認使用者年滿 13 歲。"',
        'Label("此帳號由學校或監護人管理；目前的資料同意狀態會隨帳號保留。"',
        "PrivacyPolicyCopy.requiredCategories(for: role)",
        "PrivacySupportLinks(role: role)",
        "LegalSupportConfiguration.policyEffectiveDate",
        "confirmsGuardianContext",
        'Text("我了解並繼續")',
        "appState.isSavingConsent",
    ), "Consent UI", errors)
    markers(role_selection, (
        'Text("使用前可先查看")',
        "PrivacySupportLinks()",
        "ScrollView",
    ), "Pre-login legal access", errors)
    markers(account, (
        'navigationTitle("帳號、隱私與支援")',
        "privacyAndSupportSection",
        "aiTransparencySection",
        'Label("AI 如何協助"',
        'Label("心情分數不會自動通知老師或志工"',
        "PrivacySupportLinks(role: appState.currentUser?.role)",
        'Label("查看刪除內容"',
        'TextField("刪除", text: $confirmationText)',
    ), "Account privacy and support center", errors)
    require(
        '.task {\n                await loadPreview()' not in account,
        "Opening legal/support settings still eagerly starts account deletion preview",
        errors,
    )
    markers(app_state, (
        "guardianConsentStatus: GuardianConsentStatus",
        "guardianConsentStatus: guardianConsentStatus",
        "try await firestoreService.saveConsent(record)",
        "consentErrorMessage",
    ), "Versioned consent persistence", errors)
    markers(firestore, (
        "func saveConsent(_ record: PrivacyConsentRecord) async throws",
        "try await commit(batch)",
        "record.actorRole == .student",
    ), "Confirmed and role-correct consent persistence", errors)

    manifest_path = ROOT / "ios/EnglishPlus/EnglishPlus/PrivacyInfo.xcprivacy"
    require(manifest_path.exists(), "PrivacyInfo.xcprivacy is missing", errors)
    if manifest_path.exists():
        try:
            manifest = plistlib.loads(manifest_path.read_bytes())
        except Exception as exc:
            errors.append(f"PrivacyInfo.xcprivacy is invalid: {exc}")
        else:
            require(manifest.get("NSPrivacyTracking") is False, "Privacy manifest must declare no tracking", errors)
            collected = {
                item.get("NSPrivacyCollectedDataType"): item
                for item in manifest.get("NSPrivacyCollectedDataTypes", [])
            }
            required_types = {
                "NSPrivacyCollectedDataTypeName",
                "NSPrivacyCollectedDataTypeEmailAddress",
                "NSPrivacyCollectedDataTypeUserID",
                "NSPrivacyCollectedDataTypeOtherUserContent",
                "NSPrivacyCollectedDataTypeProductInteraction",
                "NSPrivacyCollectedDataTypeSensitiveInfo",
            }
            require(required_types <= collected.keys(), "Privacy manifest omits collected data categories", errors)
            for data_type, item in collected.items():
                require(item.get("NSPrivacyCollectedDataTypeTracking") is False, f"{data_type} must not be used for tracking", errors)
            accessed = {
                item.get("NSPrivacyAccessedAPIType"): set(item.get("NSPrivacyAccessedAPITypeReasons", []))
                for item in manifest.get("NSPrivacyAccessedAPITypes", [])
            }
            require("CA92.1" in accessed.get("NSPrivacyAccessedAPICategoryUserDefaults", set()), "UserDefaults reason is missing", errors)
            require("3B52.1" in accessed.get("NSPrivacyAccessedAPICategoryFileTimestamp", set()), "User-selected file metadata reason is missing", errors)

    markers(project, (
        "PrivacyInfo.xcprivacy in Resources",
        "PrivacyInfo.xcprivacy */ = {isa = PBXFileReference",
    ), "Xcode privacy manifest membership", errors)

    for label, content in (
        ("Privacy label draft", privacy_label),
        ("TestFlight action package", action_package),
        ("App Store test information", test_info),
    ):
        markers(content, (PRIVACY_URL, SUPPORT_URL, SUPPORT_EMAIL), label, errors)
    require("OpenRouter" not in privacy_label, "Privacy label still names obsolete OpenRouter processing", errors)
    require("Firebase Cloud Functions" not in privacy_label, "Privacy label still names obsolete Cloud Functions AI transport", errors)
    markers(privacy_label, ("Cloudflare", "Groq", "not used for tracking", "Sensitive Info"), "Current App privacy disclosure", errors)
    markers(decisions, ("D-23", "D-24"), "Decision register", errors)
    markers(
        report,
        ("Round 12", "Block C", "PrivacyInfo.xcprivacy", "72/72", "22/22", "18/18"),
        "Round 12 audit report",
        errors,
    )
    markers(workflow, (
        ".github/ci-triggers/round12-ios-build",
        "validate_app_store_hardening_round12.py",
    ), "Round 12 macOS gate", errors)

    if errors:
        print("App Store hardening round 12 validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("App Store hardening round 12 privacy, support and Block C audit validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
