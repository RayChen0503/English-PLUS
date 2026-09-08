#!/usr/bin/env python3
"""Check real target -> Sources phase -> build file -> file reference membership."""
import json
import re
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[1]
PROJECT_ROOT = ROOT / "ios/EnglishPlus"
PROJECT_FILE = PROJECT_ROOT / "EnglishPlus.xcodeproj/project.pbxproj"
TARGET_ROOTS = {name: name for name in ("EnglishPlus", "EnglishPlusTests", "EnglishPlusUITests")}


def parse_project(text):
    # OpenStep property lists: comments carry no membership information.
    pattern = r'\s+|/\*.*?\*/|//[^\n]*|"(?:\\.|[^"\\])*"|[{}()=;,]|[^\s{}()=;,]+'
    tokens = [m.group() for m in re.finditer(pattern, text, re.S)
              if not m.group().isspace() and not m.group().startswith(("/*", "//"))]
    position = 0

    def take(expected=None):
        nonlocal position
        if position >= len(tokens):
            raise ValueError("Unexpected end of Xcode project")
        token = tokens[position]
        position += 1
        if expected is not None and token != expected:
            raise ValueError(f"Expected {expected}, found {token}")
        return token

    def value():
        token = take()
        if token == "{":
            result = {}
            while tokens[position] != "}":
                key = value()
                take("=")
                result[key] = value()
                take(";")
            take("}")
            return result
        if token == "(":
            result = []
            while tokens[position] != ")":
                result.append(value())
                if tokens[position] == ",":
                    take(",")
                elif tokens[position] != ")":
                    raise ValueError("Expected array separator")
            take(")")
            return result
        return json.loads(token) if token.startswith('"') else token

    result = value()
    if position != len(tokens):
        raise ValueError("Trailing Xcode project content")
    return result


def validate_membership(text, expected_files):
    project = parse_project(text)
    objects = project["objects"]
    root = objects[project["rootObject"]]
    references = {}
    errors = []

    def visit(identifier, parent=PurePosixPath(), ancestors=frozenset()):
        if identifier in ancestors:
            raise ValueError(f"Cyclic Xcode group: {identifier}")
        item = objects[identifier]
        tree = item.get("sourceTree", "<group>")
        base = PurePosixPath() if tree == "SOURCE_ROOT" else parent
        path = base / item.get("path", "")
        if item.get("isa") == "PBXFileReference":
            references[identifier] = path.as_posix()
        for child in item.get("children", []):
            visit(child, path, ancestors | {identifier})

    visit(root["mainGroup"])
    targets = {objects[key].get("name"): objects[key] for key in root["targets"]}
    for name, files in expected_files.items():
        target = targets.get(name)
        if not target:
            errors.append(f"Missing native target: {name}")
            continue
        members = set()
        for phase_id in target.get("buildPhases", []):
            phase = objects[phase_id]
            if phase.get("isa") != "PBXSourcesBuildPhase":
                continue
            for build_id in phase.get("files", []):
                build = objects.get(build_id, {})
                path = references.get(build.get("fileRef"))
                if build.get("isa") != "PBXBuildFile" or path is None:
                    errors.append(f"{name}: unresolved source build file {build_id}")
                else:
                    members.add(path)
        for path in sorted(files):
            if path not in members:
                errors.append(f"{path} is not in {name}'s Sources build phase")
        for path in sorted(members):
            if path.endswith(".swift") and path not in files:
                errors.append(f"{name}: unexpected or missing Swift source on disk: {path}")
    return errors


def main():
    try:
        expected = {}
        for target, relative in TARGET_ROOTS.items():
            folder = PROJECT_ROOT / relative
            if not folder.is_dir():
                raise ValueError(f"Missing source root: {folder}")
            expected[target] = {p.relative_to(PROJECT_ROOT).as_posix() for p in folder.rglob("*.swift") if ".build" not in p.parts}
        errors = validate_membership(PROJECT_FILE.read_text(encoding="utf-8"), expected)
    except (OSError, ValueError, KeyError, IndexError, TypeError) as error:
        errors = [f"Cannot validate Xcode source membership: {error}"]
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    print(f"iOS Xcode project source membership validation passed: {sum(map(len, expected.values()))} Swift files across {len(expected)} targets")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
