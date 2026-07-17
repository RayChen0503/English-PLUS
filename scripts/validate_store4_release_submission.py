#!/usr/bin/env python3
"""Validate STORE-4 rights, privacy, review, and competition isolation gates."""

from __future__ import annotations

import importlib.util
import json
import re
import subprocess
import urllib.parse
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "docs/app-store-release/store-4/question-provenance-manifest.json"
REVIEW_SEED_PATH = ROOT / "docs/app-store-release/store-4/review-seed-spec.json"
STORE4_DIR = ROOT / "docs/app-store-release/store-4"
COMPETITION_COMMIT = "1207a35"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8-sig")


def section(markdown: str, heading: str) -> str:
    marker = f"## {heading}"
    require(marker in markdown, f"Missing metadata section: {heading}")
    body = markdown.split(marker, 1)[1]
    return body.split("\n## ", 1)[0].strip()


def inline_code_value(markdown: str, label: str) -> str:
    match = re.search(rf"^- {re.escape(label)}：`([^`]+)`$", markdown, re.MULTILINE)
    require(match is not None, f"Missing metadata field: {label}")
    return match.group(1).strip()


def section_inline_code_value(markdown: str, heading: str) -> str:
    body = section(markdown, heading)
    match = re.fullmatch(r"`([^`]+)`", body)
    require(match is not None, f"Metadata section must contain one inline-code value: {heading}")
    return match.group(1).strip()


def assert_https_url(value: str, label: str) -> None:
    parsed = urllib.parse.urlparse(value)
    require(parsed.scheme == "https" and bool(parsed.netloc), f"{label} must be an HTTPS URL")


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def load_generator():
    path = ROOT / "scripts/generate_store4_question_provenance.py"
    spec = importlib.util.spec_from_file_location("store4_provenance", path)
    require(spec is not None and spec.loader is not None, "Unable to load STORE-4 provenance generator")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def assert_no_committed_credentials() -> None:
    banned_values = [
        "student.demo@" + "englishplus.test",
        "teacher.demo@" + "englishplus.test",
        "volunteer.demo@" + "englishplus.test",
        "EnglishPlus" + "Student2026!",
        "EnglishPlus" + "Teacher2026!",
        "EnglishPlus" + "Volunteer2026!",
    ]
    searchable_suffixes = {
        ".swift", ".py", ".js", ".ts", ".tsx", ".json", ".md", ".plist",
        ".toml", ".yaml", ".yml", ".sh",
    }
    for path in ROOT.rglob("*"):
        if not path.is_file() or path.suffix.lower() not in searchable_suffixes:
            continue
        if any(part in {".git", "node_modules", ".build", "DerivedData"} for part in path.parts):
            continue
        content = path.read_text(encoding="utf-8-sig", errors="ignore")
        for value in banned_values:
            require(value not in content, f"Committed reviewer credential found in {path.relative_to(ROOT)}")

    smoke = read("scripts/smoke_worker_firebase_runtime.py")
    for role in ["STUDENT", "TEACHER", "VOLUNTEER"]:
        require(
            f"ENGLISHPLUS_SMOKE_{role}_EMAIL" in smoke
            and f"ENGLISHPLUS_SMOKE_{role}_PASSWORD" in smoke,
            f"Smoke test must load {role.lower()} credentials from environment variables",
        )


def main() -> int:
    assert_no_committed_credentials()
    generator = load_generator()
    committed = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    expected = generator.build_manifest()
    require(committed == expected, "Question provenance manifest is stale; regenerate it")
    require(committed["questionCount"] == 1080, "All 1,080 questions must be classified")
    require(committed["semanticFamilyCount"] == 218, "Unexpected semantic-family drift")
    require(committed["manifestContainsQuestionText"] is False, "Public manifest must not contain question text")
    require(committed["classificationCounts"].get("unresolved", 0) == 0, "Unresolved sources block release")
    require(
        committed["classificationCounts"].get("self_authored", 0) == 1080,
        "Current release expects all questions to remain documented English+ originals",
    )

    banned_keys = {"prompt", "answer", "acceptedAnswers", "options", "explanation", "repairHint"}
    for record in committed["records"]:
        require(not (set(record) & banned_keys), f"Manifest leaks protected question content: {record['id']}")
        require(len(record["questionContentSha256"]) == 64, f"Missing content hash: {record['id']}")
        require(len(record["semanticFamilySha256"]) == 64, f"Missing family hash: {record['id']}")
        require(record["rightsStatus"] != "requires_human_review", f"Rights review unresolved: {record['id']}")

    required_docs = [
        "question-provenance-audit.md",
        "question-origin-attestation.md",
        "app-privacy-questionnaire.md",
        "age-rating-questionnaire.md",
        "app-store-metadata-zh-Hant.md",
        "review-accounts-and-seed.md",
        "app-review-notes.md",
        "release-gate.md",
        "review-seed-spec.json",
        "screenshot-and-device-brief.md",
    ]
    for filename in required_docs:
        require((STORE4_DIR / filename).is_file(), f"Missing STORE-4 artifact: {filename}")

    review_seed = json.loads(REVIEW_SEED_PATH.read_text(encoding="utf-8"))
    require(review_seed["environment"] == "production-only", "Review seed must never target competition")
    require(review_seed["containsCredentials"] is False, "Review seed must not contain credentials")
    require(review_seed["containsRealPeople"] is False, "Review seed must contain fictional people only")
    require(review_seed["scope"]["classId"] == "APP-REVIEW-CLASS", "Review class id drifted")
    require(
        {actor["role"] for actor in review_seed["actors"]} == {"student", "teacher", "volunteer"},
        "Review seed must cover all three roles",
    )
    bank_ids = {item["id"] for item in generator.load_bank()["items"]}
    seeded_question_ids = set(review_seed["assignment"]["questionIds"])
    seeded_question_ids.update(thread["questionId"] for thread in review_seed["supportThreads"])
    seeded_question_ids.add(review_seed["learningState"]["completedAttemptQuestionId"])
    require(seeded_question_ids <= bank_ids, "Review seed references missing question ids")
    require(len(review_seed["assignment"]["questionIds"]) == 5, "Review assignment must remain finite")

    privacy = read("docs/app-store-release/store-4/app-privacy-questionnaire.md")
    for marker in [
        "Firebase Authentication",
        "Firebase Crashlytics",
        "Google Sign-In",
        "Cloudflare",
        "Groq",
        "Cloudflare R2",
        "Crash Data",
        "Product Interaction",
        "Photos or Videos",
        "not used for tracking",
    ]:
        require(marker in privacy, f"App Privacy record is missing: {marker}")

    privacy_manifest = read("ios/EnglishPlus/EnglishPlus/PrivacyInfo.xcprivacy")
    for marker in [
        "NSPrivacyCollectedDataTypePhotosorVideos",
        "NSPrivacyCollectedDataTypeOtherDiagnosticData",
        "NSPrivacyCollectedDataTypeCoarseLocation",
    ]:
        require(marker in privacy_manifest, f"Privacy manifest is missing: {marker}")

    metadata = read("docs/app-store-release/store-4/app-store-metadata-zh-Hant.md")
    name = inline_code_value(metadata, "Name")
    subtitle = inline_code_value(metadata, "Subtitle")
    keywords = section_inline_code_value(metadata, "Keywords")
    promotional_text = section(metadata, "Promotional text")
    description = section(metadata, "Description")
    require(2 <= len(name) <= 30, "App name must contain 2-30 characters")
    require(len(subtitle) <= 30, "Subtitle exceeds Apple's 30-character limit")
    require(len(promotional_text) <= 170, "Promotional text exceeds Apple's 170-character limit")
    require(len(description) <= 4000, "Description exceeds Apple's 4,000-character limit")
    require(len(keywords.encode("utf-8")) <= 100, "Keywords exceed Apple's 100-byte limit")
    require(
        all(len(item.strip()) > 2 for item in keywords.split(",")),
        "Every App Store keyword must contain more than two characters",
    )
    assert_https_url(inline_code_value(metadata, "Support URL"), "Support URL")
    assert_https_url(inline_code_value(metadata, "Privacy Policy URL"), "Privacy Policy URL")
    require("Kids Category：否" in metadata, "Release must not be submitted to the Kids Category")
    require("台灣" in metadata and "手動發布" in metadata, "Launch availability and release mode must be explicit")
    require("不提供醫療" in metadata, "Store copy must avoid implying a medical service")

    review_notes = read("docs/app-store-release/store-4/app-review-notes.md")
    for role in ["Student reviewer", "Teacher reviewer", "Volunteer reviewer"]:
        require(role in review_notes, f"Review Notes are missing role: {role}")
    for forbidden in ["PASSWORD=", "GROQ_API_KEY", "FIREBASE_SERVICE_ACCOUNT_PRIVATE_KEY"]:
        require(forbidden not in review_notes, f"Review Notes contain a secret marker: {forbidden}")

    info = read("ios/EnglishPlus/EnglishPlus/Info.plist")
    require("ITSAppUsesNonExemptEncryption" in info, "Export-compliance declaration is missing")
    require("<false/>" in info, "Only exempt system encryption is expected")

    age_rating = read("docs/app-store-release/store-4/age-rating-questionnaire.md")
    for marker in [
        "Messaging and chat | Yes",
        "User-generated content | Yes",
        "Unrestricted web access | No",
        "Advertising | No",
        "Health or wellness topics | Infrequent",
        "Made for Kids:** Not Applicable",
        "Recommended override:** 13+",
    ]:
        require(marker in age_rating, f"Age-rating answer is missing: {marker}")

    attestation = read("docs/app-store-release/store-4/question-origin-attestation.md")
    require("Fully original wording" in attestation, "Question-rights option A is missing")
    require("External material exists" in attestation, "Question-rights option B is missing")

    release_gate = read("docs/app-store-release/store-4/release-gate.md")
    require(
        "public group `English+公測` still\n      installs build 53" in release_gate,
        "Release gate does not protect the judging build 53",
    )
    require(
        "Candidate build number is 54 or higher" in release_gate,
        "Release gate does not reserve build 54+ for production",
    )

    tag_commit = git("rev-parse", "maic-competition-build-52^{commit}")
    require(tag_commit.startswith(COMPETITION_COMMIT), "Competition frozen-source tag moved")
    require(
        git("show", "maic-competition-build-52:ios/EnglishPlus/EnglishPlus/Info.plist"),
        "Competition snapshot is not readable",
    )

    print(
        "STORE-4 release submission gate passed: 1080 provenance records, "
        "privacy/age/metadata/review artifacts present, public build 53 protected"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
