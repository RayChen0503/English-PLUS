#!/usr/bin/env python3
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8-sig")


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def markers(content: str, expected: tuple[str, ...], label: str, errors: list[str]) -> None:
    for marker in expected:
        require(marker in content, f"{label} missing marker: {marker}", errors)


def validate_indexes(errors: list[str]) -> None:
    config = json.loads(read("firebase.json"))
    indexes = json.loads(read("docs/ios-testflight/firebase/firestore.indexes.draft.json"))
    require(
        config.get("firestore", {}).get("indexes")
        == "docs/ios-testflight/firebase/firestore.indexes.draft.json",
        "firebase.json does not deploy the reviewed index contract",
        errors,
    )
    by_group = {
        item.get("collectionGroup"): item
        for item in indexes.get("indexes", [])
    }
    expected = {
        "supportThreads": ["studentUid", "studentVisible"],
        "staffAssignments": ["assignedToUid", "studentUid", "status"],
    }
    for group, fields in expected.items():
        item = by_group.get(group, {})
        require(item.get("queryScope") == "COLLECTION", f"{group} must use COLLECTION scope", errors)
        actual = [field.get("fieldPath") for field in item.get("fields", [])]
        require(actual == fields, f"{group} index does not match runtime query: {actual}", errors)
    overrides = {
        (item.get("collectionGroup"), item.get("fieldPath"))
        for item in indexes.get("fieldOverrides", [])
        if item.get("indexes") == []
    }
    require(("supportThreads", "questionSnapshot") in overrides, "support snapshot index exemption missing", errors)
    require(("practiceAssignments", "questionResults") in overrides, "assignment result index exemption missing", errors)


def main() -> int:
    errors: list[str] = []
    rules = read("docs/ios-testflight/firebase/firestore.rules.draft")
    firebase = read("ios/EnglishPlus/EnglishPlus/Services/FirebaseLearningRepository.swift")
    functions = read("functions/src/index.ts")
    tests = read("firebase-tests/test/round8-firestore-contract.test.js")
    report = read("docs/app-store-hardening/round-08-firestore-sync-audit.md")
    workflow = read(".github/workflows/ios-hardening-build.yml")
    paths = read("ios/EnglishPlus/EnglishPlus/Data/FirestorePath.swift")

    validate_indexes(errors)
    markers(rules, (
        "function canReadSupportThread",
        "function isActiveVolunteerMember",
        "allow get: if canReadSupportThread(classId, resource.data)",
        "allow list: if isClassTeacher(classId)",
        'request.resource.data.authorRole == memberRole(classId)',
        'request.resource.data.messageType == "teacherReply"',
        'request.resource.data.messageType == "volunteerReply"',
        'request.resource.data.questionIds.size() <= 12',
        'request.resource.data.questionResults.size()',
        'request.resource.data.diff(resource.data).affectedKeys().hasOnly([',
    ), "Firestore least-privilege rules", errors)
    markers(firebase, (
        "private var activeUserRole: UserRole?",
        "activeUserRole = profile?.role ?? user?.role",
        "guard activeUserRole == .teacher, let activeUserUid else { return }",
        "guard activeUserRole == .volunteer, let activeUserUid else { return }",
        'authorUid: activeUserUid',
        '.whereField("studentVisible", isEqualTo: true)',
        'if user?.role != .volunteer',
    ), "authenticated realtime repository", errors)
    require("demo-teacher-1" not in firebase, "Firebase repository still writes a demo teacher UID", errors)
    require("demo-volunteer-1" not in firebase, "Firebase repository still writes a demo volunteer UID", errors)
    markers(functions, (
        '.where("assignedToUid", "==", uid)',
        '.where("studentUid", "==", data.studentUid)',
        '.where("status", "in", ["open", "active", "assigned"])',
    ), "AI volunteer-scope query", errors)
    markers(tests, (
        "personal learning remains private",
        "support replies use the authenticated role",
        "leaving a class preserves readable history",
        "students can report assigned-task progress",
        "production listener query shapes",
        "assigned volunteers read class learning context",
    ), "Round 8 Emulator matrix", errors)
    markers(paths, (
        "personalCheckIn(uid:",
        "personalDailyMission(uid:",
        "personalAnswerEvent(uid:",
        "supportThread(classId:",
        "practiceAssignment(classId:",
        "staffAssignment(classId:",
    ), "Firestore path contract", errors)
    markers(workflow, (
        "validate_app_store_hardening_round8.py",
        "generic/platform=iOS Simulator",
        "CODE_SIGNING_ALLOWED=NO",
    ), "macOS compile workflow", errors)
    markers(report, (
        "Round 8",
        "Status: In verification",
        "Defects found and corrected",
        "Acceptance flow",
        "Xcode Cloud",
    ), "Round 8 report", errors)

    if errors:
        print("App Store hardening round 8 validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("App Store hardening round 8 Firestore sync audit validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
