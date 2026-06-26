#!/usr/bin/env python3
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

FILES = {
    "round8_audit": ROOT / "docs" / "ios-parity" / "round-8-final-audit-testflight-action-package.md",
    "testflight_action_package": ROOT / "docs" / "ios-testflight" / "testflight-action-package.md",
    "manual_action_checklist": ROOT / "docs" / "ios-testflight" / "manual-action-checklist.md",
    "firebase_ai_real_connection": ROOT / "docs" / "ios-testflight" / "firebase-ai-real-connection-checklist.md",
    "shared_scheme": ROOT / "ios" / "EnglishPlus" / "EnglishPlus.xcodeproj" / "xcshareddata" / "xcschemes" / "EnglishPlus.xcscheme",
    "export_options": ROOT / "ios" / "EnglishPlus" / "Config" / "ExportOptions.TestFlight.plist",
}

VALIDATION_SCRIPTS = [
    "validate_ios_parity_round_7_xcode_cloud.py",
    "validate_ios_parity_round_6_reports.py",
    "validate_ios_parity_round_5_persistence.py",
    "validate_ios_parity_rounds_3_to_4.py",
    "validate_ios_parity_rounds_0_to_2.py",
    "validate_windows_handoff_rounds_1_to_8.py",
    "validate_round8_testflight_preparation.py",
    "validate_firebase_sync_ai_readiness.py",
    "validate_ios_seed.py",
]

REQUIRED_MARKERS = [
    "final audit",
    "TestFlight action package",
    "manual boundary",
    "234c6a6",
    "f8d4d13",
    "tw.edu.englishplus",
    "SMKVWY55QH",
    "EnglishPlus.xcscheme",
    "ExportOptions.TestFlight.plist",
    "GoogleService-Info.plist",
    "Firebase SDK",
    "Firestore",
    "Cloud Functions",
    "OPENROUTER_API_KEY",
    "OpenRouter",
    "MockAIService",
    "MockAuthService",
    "mock fallback",
    "App Store Connect",
    "Account Holder",
    "Apple ID two-factor",
    "Apple Distribution",
    "provisioning",
    "Xcode Cloud",
    "xcodebuild",
    "Archive",
    "Upload",
    "tester email",
    "privacy policy URL",
    "support URL",
    "classes/{classId}/members/{uid}",
]

FORBIDDEN_CLAIMS = [
    "TestFlight upload is complete",
    "uploaded to TestFlight",
    "fully connected Firebase",
    "real cross-device sync is complete",
    "OpenRouter key is deployed",
    "signed archive is complete",
]


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def require_markers(label: str, text: str, markers: list[str], errors: list[str]) -> None:
    for marker in markers:
        require(marker in text, f"{label} missing marker: {marker}", errors)


def validate_files(errors: list[str]) -> None:
    for label, path in FILES.items():
        require(path.exists(), f"missing {label}: {path.relative_to(ROOT)}", errors)
    for script in VALIDATION_SCRIPTS:
        path = ROOT / "scripts" / script
        require(path.exists(), f"missing validation script: scripts/{script}", errors)


def validate_docs(errors: list[str]) -> None:
    doc_paths = [
        FILES["round8_audit"],
        FILES["testflight_action_package"],
        FILES["manual_action_checklist"],
        FILES["firebase_ai_real_connection"],
    ]
    if not all(path.exists() for path in doc_paths):
        return

    combined = "\n".join(read(path) for path in doc_paths)
    require_markers("Round 8 action package docs", combined, REQUIRED_MARKERS, errors)
    require_markers("Round 8 validation list", combined, VALIDATION_SCRIPTS, errors)

    for claim in FORBIDDEN_CLAIMS:
        require(claim not in combined, f"docs contain forbidden overclaim: {claim}", errors)

    for heading in [
        "What is complete",
        "What is not complete yet",
        "Manual action order",
        "Failure interpretation",
        "Commands to run",
        "What to send back to Codex",
    ]:
        require(heading in combined, f"docs missing required section heading: {heading}", errors)


def main() -> int:
    errors: list[str] = []
    validate_files(errors)
    validate_docs(errors)

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print("iOS parity round 8 final audit and TestFlight action package validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
