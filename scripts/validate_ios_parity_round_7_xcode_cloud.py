#!/usr/bin/env python3
import plistlib
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "ios" / "EnglishPlus" / "EnglishPlus.xcodeproj"
PROJECT_FILE = PROJECT / "project.pbxproj"
SCHEME = PROJECT / "xcshareddata" / "xcschemes" / "EnglishPlus.xcscheme"
EXPORT_OPTIONS = ROOT / "ios" / "EnglishPlus" / "Config" / "ExportOptions.TestFlight.plist"
ROUND_DOC = ROOT / "docs" / "ios-parity" / "round-7-xcode-cloud-testflight-hardening.md"
PREFLIGHT_DOC = ROOT / "docs" / "ios-testflight" / "xcode-cloud-preflight.md"

TEAM_ID = "X7Y2V4D87G"
TARGET_ID = "100000000000000000000401"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def require_markers(label: str, text: str, markers: list[str], errors: list[str]) -> None:
    for marker in markers:
        require(marker in text, f"{label} missing marker: {marker}", errors)


def validate_shared_scheme(errors: list[str]) -> None:
    require(SCHEME.exists(), "missing shared Xcode scheme EnglishPlus.xcscheme", errors)
    if not SCHEME.exists():
        return

    tree = ET.parse(SCHEME)
    root = tree.getroot()
    require(root.tag == "Scheme", "shared scheme root must be Scheme", errors)
    require(root.attrib.get("version"), "shared scheme must define version", errors)

    text = read_text(SCHEME)
    require_markers(
        "EnglishPlus.xcscheme",
        text,
        [
            "BuildAction",
            "TestAction",
            "LaunchAction",
            "ProfileAction",
            "AnalyzeAction",
            "ArchiveAction",
            'buildConfiguration = "Release"',
            f'BlueprintIdentifier = "{TARGET_ID}"',
            'BuildableName = "EnglishPlus.app"',
            'BlueprintName = "EnglishPlus"',
            'ReferencedContainer = "container:EnglishPlus.xcodeproj"',
        ],
        errors,
    )


def validate_xcode_project_settings(errors: list[str]) -> None:
    project = read_text(PROJECT_FILE)
    require("PRODUCT_BUNDLE_IDENTIFIER = com.englishplus;" in project, "Bundle ID must stay com.englishplus", errors)
    require(project.count(f"DEVELOPMENT_TEAM = {TEAM_ID};") >= 2, f"Debug and Release must set DEVELOPMENT_TEAM {TEAM_ID}", errors)
    require(project.count("CODE_SIGN_STYLE = Automatic;") >= 2, "Debug and Release must use automatic signing", errors)
    require("CURRENT_PROJECT_VERSION = 1;" in project, "build number must stay 1 for first TestFlight build", errors)
    require("MARKETING_VERSION = 1.0;" in project, "marketing version must stay 1.0", errors)
    require("TARGETED_DEVICE_FAMILY = 1;" in project, "target must stay iPhone-first", errors)


def validate_export_options(errors: list[str]) -> None:
    require(EXPORT_OPTIONS.exists(), "missing TestFlight ExportOptions plist", errors)
    if not EXPORT_OPTIONS.exists():
        return
    with EXPORT_OPTIONS.open("rb") as handle:
        options = plistlib.load(handle)
    require(options.get("method") == "app-store-connect", "ExportOptions method must be app-store-connect", errors)
    require(options.get("destination") == "upload", "ExportOptions destination must be upload", errors)
    require(options.get("signingStyle") == "automatic", "ExportOptions must use automatic signing", errors)
    require(options.get("teamID") == TEAM_ID, f"ExportOptions teamID must be {TEAM_ID}", errors)
    require(options.get("uploadSymbols") is True, "ExportOptions should upload symbols", errors)


def validate_docs(errors: list[str]) -> None:
    for path in [ROUND_DOC, PREFLIGHT_DOC]:
        require(path.exists(), f"missing document: {path.relative_to(ROOT)}", errors)
    if not ROUND_DOC.exists() or not PREFLIGHT_DOC.exists():
        return

    combined = read_text(ROUND_DOC) + "\n" + read_text(PREFLIGHT_DOC)
    require_markers(
        "Xcode Cloud docs",
        combined,
        [
            "Round 7",
            "Xcode Cloud",
            "TestFlight hardening",
            "EnglishPlus.xcscheme",
            "shared scheme",
            "ArchiveAction",
            "com.englishplus",
            "X7Y2V4D87G",
            "GoogleService-Info.plist",
            "OPENROUTER_API_KEY",
            "Account Holder",
            "manual boundary",
            "xcodebuild",
        ],
        errors,
    )


def main() -> int:
    errors: list[str] = []
    for path in [PROJECT_FILE]:
        require(path.exists(), f"missing file: {path.relative_to(ROOT)}", errors)
    if not errors:
        validate_shared_scheme(errors)
        validate_xcode_project_settings(errors)
        validate_export_options(errors)
        validate_docs(errors)

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print("iOS parity round 7 Xcode Cloud validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
