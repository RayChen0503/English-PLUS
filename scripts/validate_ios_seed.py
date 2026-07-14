#!/usr/bin/env python3
import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SEED_DIR = ROOT / "ios" / "EnglishPlus" / "EnglishPlus" / "Resources" / "SeedData"

ALLOWED_TYPES = {
    "vocabulary",
    "grammar",
    "fillBlank",
    "cloze",
    "reading",
    "translation",
    "dialogue",
}
ALLOWED_LEVELS = {"A1", "A2", "B1", "B2"}
ALLOWED_REVIEW_STATES = {"draft", "approved", "archived"}
MOJIBAKE_MARKERS = ["�", "?"]


def load_json(name):
    path = SEED_DIR / name
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def require(condition, message, errors):
    if not condition:
        errors.append(message)


def has_mojibake(value):
    if isinstance(value, str):
        return any(marker in value for marker in MOJIBAKE_MARKERS)
    if isinstance(value, list):
        return any(has_mojibake(item) for item in value)
    if isinstance(value, dict):
        return any(has_mojibake(item) for item in value.values())
    return False


def validate_question_bank(errors):
    seed = load_json("question_bank_seed.json")
    items = seed.get("items", [])
    prompts = set()

    require(seed.get("questionBankSchemaVersion") == 6, "question bank schema version must be 6", errors)
    require(items, "question bank must contain at least one item", errors)

    for item in items:
        item_id = item.get("id", "")
        question = item.get("question", {})
        prompt = question.get("prompt", "")
        question_type = question.get("type", "")
        level = item.get("level", "")
        review_state = item.get("reviewState", "")
        options = question.get("options", [])

        require(item_id, "question item id is required", errors)
        require(level in ALLOWED_LEVELS, f"{item_id}: invalid level {level}", errors)
        require(review_state in ALLOWED_REVIEW_STATES, f"{item_id}: invalid review state {review_state}", errors)
        require(question_type in ALLOWED_TYPES, f"{item_id}: invalid question type {question_type}", errors)
        require(prompt, f"{item_id}: prompt is required", errors)
        require(question.get("answer"), f"{item_id}: answer is required", errors)
        require(question.get("explanation"), f"{item_id}: explanation is required", errors)
        require(question.get("concept"), f"{item_id}: concept is required", errors)
        require(question.get("repairHint"), f"{item_id}: repairHint is required", errors)
        require(prompt not in prompts, f"{item_id}: duplicate prompt", errors)
        require(not has_mojibake(item), f"{item_id}: possible mojibake marker found", errors)

        if question_type in {"vocabulary", "grammar", "dialogue"}:
            require(len(options) >= 2, f"{item_id}: choice-style questions need at least 2 options", errors)
        if review_state == "approved":
            require(item.get("source"), f"{item_id}: approved item needs source", errors)

        prompts.add(prompt)

    approved_types = {
        item.get("question", {}).get("type")
        for item in items
        if item.get("reviewState") == "approved"
    }
    require(
        ALLOWED_TYPES.issubset(approved_types),
        "approved question bank must cover all handoff question types",
        errors,
    )


def validate_accounts(errors):
    seed = load_json("accounts_seed.json")
    roles = {account.get("role") for account in seed.get("accounts", [])}
    require({"student", "teacher", "volunteer"}.issubset(roles), "accounts seed must include student, teacher, and volunteer", errors)
    require(not has_mojibake(seed), "accounts seed contains possible mojibake marker", errors)


def validate_manifest(errors):
    manifest = load_json("seed_manifest.json")
    files = manifest.get("files", [])
    for file_name in files:
        require((SEED_DIR / file_name).exists(), f"manifest references missing file {file_name}", errors)


def main():
    errors = []
    validate_manifest(errors)
    validate_accounts(errors)
    validate_question_bank(errors)

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print("iOS seed validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
