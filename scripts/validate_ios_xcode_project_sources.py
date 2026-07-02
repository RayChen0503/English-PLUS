#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
IOS_SOURCE_ROOT = ROOT / "ios" / "EnglishPlus" / "EnglishPlus"
PROJECT_FILE = ROOT / "ios" / "EnglishPlus" / "EnglishPlus.xcodeproj" / "project.pbxproj"


def main() -> int:
    errors: list[str] = []

    if not IOS_SOURCE_ROOT.exists():
        errors.append(f"missing iOS source root: {IOS_SOURCE_ROOT.relative_to(ROOT)}")
    if not PROJECT_FILE.exists():
        errors.append(f"missing Xcode project file: {PROJECT_FILE.relative_to(ROOT)}")
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1

    project_text = PROJECT_FILE.read_text(encoding="utf-8")
    swift_files = sorted(
        path for path in IOS_SOURCE_ROOT.rglob("*.swift")
        if ".build" not in path.parts
    )

    for swift_file in swift_files:
        name = swift_file.name
        relative = swift_file.relative_to(ROOT)
        if f"/* {name} */" not in project_text:
            errors.append(f"{relative} is missing from PBXFileReference")
        if f"/* {name} in Sources */" not in project_text:
            errors.append(f"{relative} is missing from PBXSourcesBuildPhase")

    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1

    print(f"iOS Xcode project source membership validation passed: {len(swift_files)} Swift files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
