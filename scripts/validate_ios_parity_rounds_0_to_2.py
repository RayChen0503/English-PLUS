#!/usr/bin/env python3
import json
import sys
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
IOS_ROOT = ROOT / "ios" / "EnglishPlus" / "EnglishPlus"
SEED_PATH = IOS_ROOT / "Resources" / "SeedData" / "question_bank_seed.json"
BASELINE_DOC = ROOT / "docs" / "ios-parity" / "round-0-baseline-and-gap-audit.md"
STUDENT_SHELL = IOS_ROOT / "Features" / "Student" / "StudentShellView.swift"
LEARNING_MAP = IOS_ROOT / "Features" / "Student" / "StudentLearningMapView.swift"

REQUIRED_TYPES = {
    "vocabulary",
    "grammar",
    "fillBlank",
    "cloze",
    "reading",
    "translation",
    "dialogue",
}
REQUIRED_LEVELS = {"A1", "A2", "B1", "B2"}


def fail(message, errors):
    errors.append(message)


def read_text(path):
    return path.read_text(encoding="utf-8")


def validate_round_0(errors):
    if not BASELINE_DOC.exists():
        fail("round 0 baseline audit document is missing", errors)
        return

    text = read_text(BASELINE_DOC)
    required_markers = [
        "f8d4d13",
        "Complete Firebase sync AI readiness",
        "Android parity gaps",
        "iOS parity plan",
    ]
    for marker in required_markers:
        if marker not in text:
            fail(f"round 0 baseline audit missing marker: {marker}", errors)


def validate_question_bank(errors):
    if not SEED_PATH.exists():
        fail("iOS question bank seed file is missing", errors)
        return

    seed = json.loads(SEED_PATH.read_text(encoding="utf-8"))
    items = seed.get("items", [])
    ids = [item.get("id") for item in items]
    prompts = [item.get("question", {}).get("prompt") for item in items]
    type_counts = Counter(item.get("question", {}).get("type") for item in items)
    level_counts = Counter(item.get("level") for item in items)

    if len(items) < 1000:
        fail(f"iOS question bank must contain at least 1000 items, found {len(items)}", errors)
    if len(ids) != len(set(ids)):
        fail("iOS question bank contains duplicate ids", errors)
    if len(prompts) != len(set(prompts)):
        fail("iOS question bank contains duplicate prompts", errors)

    missing_types = REQUIRED_TYPES - set(type_counts)
    if missing_types:
        fail(f"iOS question bank missing types: {', '.join(sorted(missing_types))}", errors)

    missing_levels = REQUIRED_LEVELS - set(level_counts)
    if missing_levels:
        fail(f"iOS question bank missing levels: {', '.join(sorted(missing_levels))}", errors)

    for question_type in REQUIRED_TYPES:
        if type_counts[question_type] < 100:
            fail(
                f"iOS question bank needs at least 100 {question_type} items, "
                f"found {type_counts[question_type]}",
                errors,
            )

    for level in REQUIRED_LEVELS:
        if level_counts[level] < 100:
            fail(
                f"iOS question bank needs at least 100 {level} items, found {level_counts[level]}",
                errors,
            )

    for item in items:
        question = item.get("question", {})
        item_id = item.get("id", "<missing-id>")
        if item.get("reviewState") != "approved":
            fail(f"{item_id}: all parity seed questions must be approved", errors)
        if "Android" not in item.get("source", "") and "English+" not in item.get("source", ""):
            fail(f"{item_id}: source should identify Android/English+ parity seed", errors)
        if not question.get("explanation"):
            fail(f"{item_id}: explanation is required", errors)
        if not question.get("repairHint"):
            fail(f"{item_id}: repairHint is required", errors)


def validate_learning_map(errors):
    if not LEARNING_MAP.exists():
        fail("StudentLearningMapView.swift is missing", errors)
        return

    shell = read_text(STUDENT_SHELL)
    map_text = read_text(LEARNING_MAP)

    if "StudentLearningMapView(" not in shell:
        fail("StudentShellView must use StudentLearningMapView in the map tab", errors)
    if 'Text("placeholder learning map")' in shell:
        fail("StudentShellView still contains placeholder learning map text", errors)

    required_markers = [
        "LearningMapNode",
        "今日路線",
        "心情檢測",
        "今日題目任務",
        "低壓修復",
        "自由練習",
        "支持回覆",
        "ProgressView",
        "currentMission",
        "progressSnapshot",
    ]
    for marker in required_markers:
        if marker not in map_text:
            fail(f"StudentLearningMapView missing marker: {marker}", errors)


def main():
    errors = []
    validate_round_0(errors)
    validate_question_bank(errors)
    validate_learning_map(errors)

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print("iOS parity rounds 0-2 validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
