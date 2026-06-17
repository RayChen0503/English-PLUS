#!/usr/bin/env python3
import plistlib
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
IOS_PROJECT = ROOT / "ios" / "EnglishPlus" / "EnglishPlus.xcodeproj" / "project.pbxproj"
INFO_PLIST = ROOT / "ios" / "EnglishPlus" / "EnglishPlus" / "Info.plist"
EXPORT_OPTIONS = ROOT / "ios" / "EnglishPlus" / "Config" / "ExportOptions.TestFlight.plist"
TESTFLIGHT_DIR = ROOT / "docs" / "ios-testflight" / "testflight"
ROUND8_DOC = ROOT / "docs" / "ios-testflight" / "round-8-testflight-preparation-check.md"

TEAM_ID = "SMKVWY55QH"

FILES = {
    "project": IOS_PROJECT,
    "info": INFO_PLIST,
    "export_options": EXPORT_OPTIONS,
    "test_info": TESTFLIGHT_DIR / "app-store-connect-test-info.md",
    "tester_email": TESTFLIGHT_DIR / "tester-email-template.md",
    "release_notes": TESTFLIGHT_DIR / "internal-build-release-notes.md",
    "round8_doc": ROUND8_DOC,
}


def read(path):
    return path.read_text(encoding="utf-8")


def require(condition, message, errors):
    if not condition:
        errors.append(message)


def validate_files(errors):
    for name, path in FILES.items():
        require(path.exists(), f"missing {name}: {path.relative_to(ROOT)}", errors)


def validate_xcode_settings(errors):
    project = read(IOS_PROJECT)
    info = read(INFO_PLIST)

    require("PRODUCT_BUNDLE_IDENTIFIER = tw.edu.englishplus;" in project, "Bundle ID must be tw.edu.englishplus", errors)
    require(project.count(f"DEVELOPMENT_TEAM = {TEAM_ID};") >= 2, f"Debug and Release must set DEVELOPMENT_TEAM {TEAM_ID}", errors)
    require(project.count("CODE_SIGN_STYLE = Automatic;") >= 2, "Debug and Release must use automatic signing", errors)
    require("CURRENT_PROJECT_VERSION = 1;" in project, "build number must be 1 for first TestFlight build", errors)
    require("MARKETING_VERSION = 1.0;" in project, "marketing version must be 1.0 for first TestFlight build", errors)
    require("TARGETED_DEVICE_FAMILY = 1;" in project, "target must stay iPhone-first", errors)
    require("<key>CFBundleDisplayName</key>" in info and "<string>English+</string>" in info, "display name must be English+", errors)


def validate_export_options(errors):
    with EXPORT_OPTIONS.open("rb") as handle:
        options = plistlib.load(handle)

    require(options.get("method") == "app-store-connect", "ExportOptions method must be app-store-connect", errors)
    require(options.get("destination") == "upload", "ExportOptions destination must be upload", errors)
    require(options.get("signingStyle") == "automatic", "ExportOptions must use automatic signing", errors)
    require(options.get("teamID") == TEAM_ID, f"ExportOptions teamID must be {TEAM_ID}", errors)
    require(options.get("uploadSymbols") is True, "ExportOptions should upload symbols", errors)


def validate_testflight_docs(errors):
    combined = "\n".join(read(path) for path in [
        FILES["test_info"],
        FILES["tester_email"],
        FILES["release_notes"],
        FILES["round8_doc"],
    ])

    for token in [
        "English+",
        "tw.edu.englishplus",
        "1.0",
        "Build",
        "Student Flow Testers",
        "Teacher Flow Testers",
        "Volunteer Flow Testers",
        "測試角色",
        "Role tested",
        "Apple ID two-factor",
        "Apple Distribution",
        "GoogleService-Info.plist",
    ]:
        require(token in combined, f"TestFlight preparation docs missing {token}", errors)


def main():
    errors = []
    validate_files(errors)
    if not errors:
        validate_xcode_settings(errors)
        validate_export_options(errors)
        validate_testflight_docs(errors)

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print("Round 8 TestFlight preparation validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
