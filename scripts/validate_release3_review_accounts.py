#!/usr/bin/env python3
"""Validate credential-free RELEASE-3 App Review account tooling and seed data."""

from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
GIT_EXECUTABLE = os.environ.get("ENGLISHPLUS_GIT_EXECUTABLE", "git")
SPEC_PATH = ROOT / "docs/app-store-release/store-4/review-seed-spec.json"
REPORT_PATH = ROOT / "docs/app-store-release/release-3-review-accounts.md"
TOOL_PATH = ROOT / "scripts/release3_review_accounts.cjs"
QUESTION_BANK_PATH = ROOT / "ios/EnglishPlus/EnglishPlus/Resources/SeedData/question_bank_seed.json"


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def git(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [GIT_EXECUTABLE, *args],
        cwd=ROOT,
        text=True,
        encoding="utf-8",
        capture_output=True,
        check=False,
    )


def main() -> int:
    errors: list[str] = []
    spec = json.loads(SPEC_PATH.read_text(encoding="utf-8"))
    bank_payload = json.loads(QUESTION_BANK_PATH.read_text(encoding="utf-8"))
    bank_items = bank_payload if isinstance(bank_payload, list) else bank_payload["items"]
    bank = {item["id"]: item for item in bank_items}

    require(spec.get("environment") == "production-only", "Seed must be production-only.", errors)
    require(spec.get("containsCredentials") is False, "Seed spec must reject credentials.", errors)
    require(spec.get("containsRealPeople") is False, "Seed spec must reject real people.", errors)
    require(spec.get("resetPolicy") == "idempotent-replace-review-scope", "Wrong reset policy.", errors)
    require(spec["scope"].get("classId") == "APP-REVIEW-CLASS", "Wrong review class ID.", errors)
    for code_key in ("joinCode", "volunteerJoinCode"):
        code = spec["scope"].get(code_key, "")
        require(len(code) == 8 and code.replace("-", "").isalnum() and code == code.upper(), f"Invalid {code_key}.", errors)

    actors = spec.get("actors", [])
    require([actor.get("key") for actor in actors] == ["student", "teacher", "volunteer"], "Review roles are incomplete.", errors)
    require(all(actor.get("displayName", "").startswith("Review ") for actor in actors), "Review names must be synthetic.", errors)

    question_ids = spec.get("assignment", {}).get("questionIds", [])
    require(len(question_ids) == 5 and len(set(question_ids)) == 5, "Review assignment must have five unique questions.", errors)
    selected = [bank.get(question_id) for question_id in question_ids]
    require(all(selected), "Review assignment references a missing question.", errors)
    if all(selected):
        require(all(item.get("reviewState") == "approved" for item in selected), "Every review question must be approved.", errors)
        require(len({item["question"]["type"] for item in selected}) >= 4, "Review assignment needs at least four question types.", errors)
        require(len({item["level"] for item in selected}) >= 3, "Review assignment needs at least three levels.", errors)

    support_threads = spec.get("supportThreads", [])
    require(len(support_threads) == 2, "Pending and resolved support threads are required.", errors)
    require({item.get("state") for item in support_threads} == {"awaiting-staff-reply", "replied-unread-by-student"}, "Wrong support states.", errors)

    tool = TOOL_PATH.read_text(encoding="utf-8")
    for token in (
        'const PROJECT_ID = "englishplus-production"',
        "--confirm",
        "idempotent",
        "db.recursiveDelete",
        "firebasePasswordSignIn",
        "APP-REVIEW-CLASS",
        "item.studentUid === studentUid || item.id === studentUid",
        "userMembershipDocument(key, spec, now, earlier)",
        "memberDocument(key, user, spec, now, earlier)",
        "expectDenied",
        "productionAdmin.customClaims?.admin",
        "ENGLISHPLUS_REVIEW_CREDENTIALS_FILE",
        "Review credentials must be stored outside the Git repository",
    ):
        require(token in tool, f"Provisioning tool is missing safety token: {token}", errors)
    require("englishplus-testflight" not in tool, "Provisioning tool references the competition Firebase project.", errors)
    require("testflight.apple.com" not in tool, "Provisioning tool references the competition public link.", errors)
    require("password:" not in tool.lower().replace("password: randompassword()", ""), "Provisioning tool appears to contain a password literal.", errors)

    tracked = {line.replace("\\", "/") for line in git("ls-files").stdout.splitlines()}
    forbidden_markers = ("review-accounts.json", "review_credentials", "review-credentials")
    require(
        not any(any(marker in path.lower() for marker in forbidden_markers) for path in tracked),
        "A private review credential file is tracked.",
        errors,
    )
    require("scripts/release3_review_credentials.local.json" not in tracked, "Ignored local credentials are tracked.", errors)
    ignore_check = git("check-ignore", "--quiet", "scripts/release3_review_credentials.local.json")
    require(ignore_check.returncode == 0, "Local review credentials are not ignored.", errors)

    if REPORT_PATH.exists():
        report = REPORT_PATH.read_text(encoding="utf-8")
        for token in (
            "englishplus-production",
            "APP-REVIEW-CLASS",
            "competition build 53",
            "does not push",
            "three role sign-ins",
            "Two consecutive live apply-and-verify runs passed",
            "englishplus.tw+review.student@gmail.com",
        ):
            require(token in report, f"RELEASE-3 report is missing: {token}", errors)
    else:
        errors.append("RELEASE-3 report is missing.")

    if errors:
        print("RELEASE-3 validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("RELEASE-3 static validation passed")
    print("- review seed is fictional, credential-free and production-only")
    print("- assignment, support and learning states are deterministic")
    print("- provisioning is guarded, idempotent and competition-isolated")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
