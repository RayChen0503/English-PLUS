#!/usr/bin/env python3
import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
IOS_ROOT = ROOT / "ios" / "EnglishPlus" / "EnglishPlus"
RULES_PATH = ROOT / "docs" / "ios-testflight" / "firebase" / "firestore.rules.draft"
INDEXES_PATH = ROOT / "docs" / "ios-testflight" / "firebase" / "firestore.indexes.draft.json"
PATH_SWIFT = IOS_ROOT / "Data" / "FirestorePath.swift"
SCHEMA_SWIFT = IOS_ROOT / "Models" / "FirestoreSchema.swift"

REQUIRED_RULE_SNIPPETS = [
    "match /users/{uid}",
    "match /classes/{classId}",
    "match /members/{uid}",
    "match /students/{studentUid}",
    "match /checkIns/{dateKey}",
    "match /dailyMissions/{missionId}",
    "match /answerEvents/{eventId}",
    "match /learningEvents/{eventId}",
    "match /supportThreads/{threadId}",
    "match /messages/{messageId}",
    "match /staffAssignments/{assignmentId}",
    "match /questionBank/{questionId}",
    "match /reports/{reportId}",
    "match /syncQueue/{syncItemId}",
]

REQUIRED_PATH_BUILDERS = [
    "appConfigPublic",
    "user(uid:",
    "classDocument(classId:",
    "member(classId:",
    "student(classId:",
    "checkIn(classId:",
    "dailyMission(classId:",
    "answerEvent(classId:",
    "learningEvent(classId:",
    "supportThread(classId:",
    "supportMessage(classId:",
    "staffAssignment(classId:",
    "questionBankItem(classId:",
    "report(classId:",
    "syncQueueItem(classId:",
]


def require(condition, message, errors):
    if not condition:
        errors.append(message)


def validate_indexes(errors):
    with INDEXES_PATH.open(encoding="utf-8") as handle:
        data = json.load(handle)
    require(isinstance(data.get("indexes"), list), "firestore.indexes.draft.json must contain indexes[]", errors)
    indexes = data.get("indexes", [])
    by_group = {index.get("collectionGroup"): index for index in indexes}
    for required in ["supportThreads", "staffAssignments"]:
        require(required in by_group, f"missing index collectionGroup {required}", errors)
    for group, fields in {
        "supportThreads": ["studentUid", "studentVisible"],
        "staffAssignments": ["assignedToUid", "studentUid", "status"],
    }.items():
        index = by_group.get(group, {})
        require(index.get("queryScope") == "COLLECTION", f"{group} index must use COLLECTION scope", errors)
        actual_fields = [field.get("fieldPath") for field in index.get("fields", [])]
        require(actual_fields == fields, f"{group} index fields do not match runtime query", errors)


def validate_rules(errors):
    rules = RULES_PATH.read_text(encoding="utf-8")
    for snippet in REQUIRED_RULE_SNIPPETS:
        require(snippet in rules, f"firestore rules missing {snippet}", errors)
    require("allow delete: if false" in rules, "firestore rules should deny deletes by default", errors)
    require("request.auth != null" in rules, "firestore rules should require auth", errors)


def validate_ios_contract(errors):
    path_swift = PATH_SWIFT.read_text(encoding="utf-8")
    schema_swift = SCHEMA_SWIFT.read_text(encoding="utf-8")
    for builder in REQUIRED_PATH_BUILDERS:
        require(builder in path_swift, f"FirestorePath missing {builder}", errors)
    for token in [
        "static var projectId: String",
        "EnglishPlusDeploymentEnvironment.expectedFirebaseProjectID",
        "bundleId = \"com.englishplus\"",
        "configFileName = \"GoogleService-Info.plist\"",
        "FirestoreUserDocument",
        "FirestoreMemberDocument",
        "FirestoreQuestionBankDocument",
    ]:
        require(token in schema_swift, f"Firestore schema missing {token}", errors)


def validate_config_not_committed(errors):
    tracked_files = subprocess.run(
        ["git", "ls-files"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    ).stdout.splitlines()
    tracked_configs = [
        path for path in tracked_files if Path(path).name == "GoogleService-Info.plist"
    ]
    require(not tracked_configs, "GoogleService-Info.plist must not be committed", errors)
    gitignore = (ROOT / ".gitignore").read_text(encoding="utf-8")
    require("GoogleService-Info.plist" in gitignore, ".gitignore should protect GoogleService-Info.plist", errors)


def main():
    errors = []
    validate_indexes(errors)
    validate_rules(errors)
    validate_ios_contract(errors)
    validate_config_not_committed(errors)

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print("Round 4 backend contract validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
