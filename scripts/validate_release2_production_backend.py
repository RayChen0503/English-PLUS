#!/usr/bin/env python3
"""Validate the RELEASE-2 production backend and competition isolation."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
GIT_EXECUTABLE = os.environ.get("ENGLISHPLUS_GIT_EXECUTABLE", "git")
LOCK_PATH = ROOT / "docs/app-store-release/release-environment-lock.json"
REPORT_PATH = ROOT / "docs/app-store-release/release-2-production-backend.md"
FIREBASE_CONFIG = ROOT / "firebase.production.json"
FIRESTORE_INDEXES = ROOT / "docs/ios-testflight/firebase/firestore.indexes.draft.json"
WRANGLER_CONFIG = ROOT / "workers/englishplus-ai-proxy/wrangler.toml"
ADMIN_ENV = ROOT / "admin-web/.env.production"


def git(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [GIT_EXECUTABLE, *args],
        cwd=ROOT,
        text=True,
        encoding="utf-8",
        capture_output=True,
        check=False,
    )


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def parse_env(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip().strip('"').strip("'")
    return values


def live_get(url: str) -> tuple[int, str]:
    request = urllib.request.Request(url, headers={"User-Agent": "EnglishPlus-Release2-Validator/1.0"})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return response.status, response.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as error:
        return error.code, error.read().decode("utf-8", errors="replace")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--live", action="store_true", help="Check deployed public endpoints.")
    args = parser.parse_args()
    errors: list[str] = []

    lock = json.loads(LOCK_PATH.read_text(encoding="utf-8"))
    production = lock["production"]
    competition = lock["competition"]

    expected_production = {
        "firebaseProject": "englishplus-production",
        "workerName": "englishplus-ai-proxy-production",
        "workerHost": "englishplus-ai-proxy-production.englishplus-ray.workers.dev",
        "workerVersion": "83577444-d957-4514-ade7-2964350f4600",
        "r2Bucket": "englishplus-volunteer-evidence-production",
        "adminHost": "englishplus-production.firebaseapp.com",
        "firestoreRegion": "asia-east1",
        "administratorEmail": "englishplus.tw@gmail.com",
    }
    for key, value in expected_production.items():
        require(production.get(key) == value, f"Wrong production identity: {key}", errors)

    require(competition.get("firebaseProject") == "englishplus-testflight", "Competition Firebase changed.", errors)
    require(competition.get("workerName") == "englishplus-ai-proxy", "Competition Worker changed.", errors)
    require(competition.get("r2Bucket") == "englishplus-volunteer-evidence", "Competition R2 changed.", errors)
    require(competition.get("publicTestFlightBuild") == 53, "Competition public build changed.", errors)

    frozen_commit = competition["frozenSourceCommit"]
    tag_commit = git("rev-parse", f"{competition['sourceTag']}^{{}}").stdout.strip()
    branch_commit = git("rev-parse", competition["protectionBranch"]).stdout.strip()
    require(tag_commit == frozen_commit, "Competition tag no longer resolves to the frozen commit.", errors)
    require(branch_commit == frozen_commit, "Competition protection branch changed.", errors)

    firebase_config = json.loads(FIREBASE_CONFIG.read_text(encoding="utf-8"))
    require(firebase_config["firestore"]["rules"].endswith("firestore.rules.draft"), "Wrong Rules path.", errors)
    require(firebase_config["firestore"]["indexes"].endswith("firestore.indexes.draft.json"), "Wrong indexes path.", errors)
    firestore_indexes = json.loads(FIRESTORE_INDEXES.read_text(encoding="utf-8"))
    report_created_at = next(
        (
            item
            for item in firestore_indexes.get("fieldOverrides", [])
            if item.get("collectionGroup") == "reports" and item.get("fieldPath") == "createdAt"
        ),
        None,
    )
    require(report_created_at is not None, "Content-report createdAt index is missing.", errors)
    if report_created_at is not None:
        require(
            any(
                index.get("order") == "DESCENDING"
                and index.get("queryScope") == "COLLECTION_GROUP"
                for index in report_created_at.get("indexes", [])
            ),
            "Content-report collection-group sorting index is missing.",
            errors,
        )
    report_reported_uid = next(
        (
            item
            for item in firestore_indexes.get("fieldOverrides", [])
            if item.get("collectionGroup") == "reports" and item.get("fieldPath") == "reportedUid"
        ),
        None,
    )
    require(report_reported_uid is not None, "Account-deletion reportedUid index is missing.", errors)
    if report_reported_uid is not None:
        require(
            any(
                index.get("order") == "ASCENDING"
                and index.get("queryScope") == "COLLECTION_GROUP"
                for index in report_reported_uid.get("indexes", [])
            ),
            "Account-deletion reportedUid collection-group index is missing.",
            errors,
        )
    hosting = firebase_config["hosting"]
    require(hosting.get("public") == "admin-web/dist", "Wrong administrator Hosting output.", errors)
    headers = json.dumps(hosting.get("headers", []), ensure_ascii=False)
    require("englishplus-ai-proxy-production" in headers, "Production Worker is missing from CSP.", errors)
    require("englishplus-production.firebaseapp.com" in headers, "Production auth domain is missing from CSP.", errors)
    require("englishplus-testflight" not in headers, "Competition domain leaked into production Hosting config.", errors)

    wrangler = WRANGLER_CONFIG.read_text(encoding="utf-8")
    for token in (
        '[env.production]',
        'name = "englishplus-ai-proxy-production"',
        'FIREBASE_PROJECT_ID = "englishplus-production"',
        'AI_QUOTA_MODE = "public"',
        'bucket_name = "englishplus-volunteer-evidence-production"',
        'namespace_id = "92001"',
        'namespace_id = "92002"',
    ):
        require(token in wrangler, f"Production Wrangler config is missing: {token}", errors)
    require('FIREBASE_PROJECT_ID = "englishplus-testflight"' in wrangler, "Competition Worker config was removed.", errors)
    require('bucket_name = "englishplus-volunteer-evidence"' in wrangler, "Competition R2 config was removed.", errors)

    require(ADMIN_ENV.is_file(), "Ignored production administrator env is missing locally.", errors)
    if ADMIN_ENV.is_file():
        env = parse_env(ADMIN_ENV)
        require(env.get("VITE_ENGLISHPLUS_ENVIRONMENT") == "production", "Admin env is not production.", errors)
        require(env.get("VITE_FIREBASE_PROJECT_ID") == "englishplus-production", "Admin env points to wrong Firebase.", errors)
        require(
            env.get("VITE_ADMIN_API_BASE_URL") == "https://englishplus-ai-proxy-production.englishplus-ray.workers.dev",
            "Admin env points to wrong Worker.",
            errors,
        )

    tracked = set(git("ls-files").stdout.splitlines())
    normalized_tracked = {path.replace("\\", "/") for path in tracked}
    forbidden_exact = {
        "admin-web/.env.production",
        "scripts/release2_google_backend_setup.cjs",
        "scripts/release2_production_smoke.cjs",
    }
    for path in forbidden_exact:
        require(path not in normalized_tracked, f"Sensitive or temporary file tracked: {path}", errors)
    require(
        not any(path.startswith(".firebase/") for path in normalized_tracked),
        "Firebase deployment cache is tracked.",
        errors,
    )
    require(
        not any("groq-production-key" in path for path in normalized_tracked),
        "Production Groq key file is tracked.",
        errors,
    )
    require(
        not any(path.endswith("englishplus-production-backend.json") for path in normalized_tracked),
        "Production service-account key is tracked.",
        errors,
    )

    for path in (ADMIN_ENV, ROOT / ".firebase"):
        ignored = git("check-ignore", "--quiet", str(path.relative_to(ROOT)))
        require(ignored.returncode == 0, f"Generated or local path is not ignored: {path.relative_to(ROOT)}", errors)

    report = REPORT_PATH.read_text(encoding="utf-8")
    for token in (
        "21 passed and 0",
        "fallbackUsed=false",
        "englishplus.tw@gmail.com",
        "admin: true",
        "1207a359708b8d83bec867bfdec5a8bdd5d229ac",
        "does not push the Git branch",
    ):
        require(token in report, f"RELEASE-2 report is missing: {token}", errors)

    if args.live:
        live_targets = {
            "competition Worker": "https://englishplus-ai-proxy.englishplus-ray.workers.dev/health",
            "competition Hosting": "https://englishplus-testflight.web.app",
            "production Worker": "https://englishplus-ai-proxy-production.englishplus-ray.workers.dev/health",
            "production Hosting": "https://englishplus-production.web.app",
        }
        for label, url in live_targets.items():
            status, body = live_get(url)
            require(status == 200, f"{label} returned HTTP {status}.", errors)
            if url.endswith("/health"):
                try:
                    payload = json.loads(body)
                    require(payload.get("provider") == "groq", f"{label} is not using Groq.", errors)
                except json.JSONDecodeError:
                    errors.append(f"{label} returned invalid health JSON.")

    if errors:
        print("RELEASE-2 production backend validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("RELEASE-2 production backend validation passed")
    print("- production Firebase, Firestore, Worker, R2 and Hosting identities are locked")
    print("- competition Git refs and resource identities remain frozen")
    print("- production administrator environment is local and ignored")
    print("- no secret or temporary deployment helper is tracked")
    if args.live:
        print("- competition and production public endpoints are healthy")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
