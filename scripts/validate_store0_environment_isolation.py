#!/usr/bin/env python3
"""Validate the STORE-0 competition freeze and environment boundary."""

from __future__ import annotations

import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BASELINE = "1207a359708b8d83bec867bfdec5a8bdd5d229ac"
PUBLIC_COMPETITION_BUILD = 53
MINIMUM_PRODUCTION_BUILD = 54


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def git(*args: str) -> str:
    return subprocess.check_output(
        ["git", *args], cwd=ROOT, text=True, encoding="utf-8"
    ).strip()


def main() -> int:
    errors: list[str] = []

    git_checks_available = True
    try:
        require(
            git("merge-base", "HEAD", BASELINE) == BASELINE,
            "STORE-0 branch does not descend from the competition baseline.",
            errors,
        )
        require(
            git("rev-parse", "maic-competition-build-52^{}") == BASELINE,
            "Competition tag does not resolve to the frozen source baseline.",
            errors,
        )
        require(
            git("rev-parse", "release/maic-2026-build-52") == BASELINE,
            "Competition protection branch does not resolve to the frozen source baseline.",
            errors,
        )
    except (OSError, subprocess.CalledProcessError):
        git_checks_available = False

    project = read("ios/EnglishPlus/EnglishPlus.xcodeproj/project.pbxproj")
    info_plist = read("ios/EnglishPlus/EnglishPlus/Info.plist")
    competition_scheme = read(
        "ios/EnglishPlus/EnglishPlus.xcodeproj/xcshareddata/xcschemes/EnglishPlusCompetition.xcscheme"
    )
    ci_script = read("ci_scripts/ci_post_clone.sh")
    nested_ci_script = read("ios/EnglishPlus/ci_scripts/ci_post_clone.sh")
    runtime = read("ios/EnglishPlus/EnglishPlus/Services/FirebaseAppConfigurator.swift")

    for setting in (
        "ENGLISHPLUS_DEPLOYMENT_ENVIRONMENT = competition;",
        "ENGLISHPLUS_DEPLOYMENT_ENVIRONMENT = production;",
        'ENGLISHPLUS_EXPECTED_FIREBASE_PROJECT_ID = "englishplus-testflight";',
        'ENGLISHPLUS_EXPECTED_FIREBASE_PROJECT_ID = "englishplus-production";',
        "englishplus-ai-proxy-production.englishplus-ray.workers.dev",
    ):
        require(setting in project, f"Missing Xcode boundary: {setting}", errors)
    require('buildConfiguration = "Competition"' in competition_scheme, "Competition scheme is not isolated.", errors)
    require("$(ENGLISHPLUS_AI_PROXY_URL)" in info_plist, "AI URL is still hardcoded in Info.plist.", errors)
    require("$(ENGLISHPLUS_EXPECTED_FIREBASE_PROJECT_ID)" in info_plist, "Expected Firebase project is not injected.", errors)
    require("case configurationError" in runtime, "Production runtime is not fail-closed.", errors)
    require(
        "guard let configPath = bundledConfigPath else {\n            return .configurationError\n        }" in runtime,
        "A real build can silently fall back to mock data when Firebase config is missing.",
        errors,
    )
    require(
        "#else\n        return .configurationError\n        #endif" in runtime,
        "A real build can silently fall back to mock data when Firebase SDK is unavailable.",
        errors,
    )
    require("bundledProjectID == expectedProjectID" in runtime, "Runtime project mismatch guard is missing.", errors)
    require("EnglishPlusEnvironmentBoundary.isValid" in runtime, "Runtime boundary is not unit-testable.", errors)
    require(
        (ROOT / "ios/EnglishPlus/EnglishPlusTests/Store0EnvironmentIsolationTests.swift").is_file(),
        "STORE-0 Swift boundary tests are missing.",
        errors,
    )

    for token in (
        "GOOGLE_SERVICE_INFO_PLIST_BASE64_COMPETITION",
        "GOOGLE_SERVICE_INFO_PLIST_BASE64_PRODUCTION",
        'EXPECTED_PROJECT_ID="englishplus-testflight"',
        'EXPECTED_PROJECT_ID="englishplus-production"',
        "Firebase project mismatch",
    ):
        require(token in ci_script, f"CI environment guard missing: {token}", errors)
    require(
        'PLIST_BASE64="${GOOGLE_SERVICE_INFO_PLIST_BASE64_PRODUCTION:-}"' in ci_script,
        "Production CI may fall back to the competition plist.",
        errors,
    )
    require(ci_script == nested_ci_script, "The two Xcode Cloud scripts have drifted.", errors)

    aliases = json.loads(read(".firebaserc"))["projects"]
    require(aliases.get("default") == "englishplus-testflight", "Default Firebase alias changed competition.", errors)
    require(aliases.get("competition") == "englishplus-testflight", "Competition Firebase alias is wrong.", errors)
    require(aliases.get("production") == "englishplus-production", "Production Firebase alias is wrong.", errors)

    worker = read("workers/englishplus-ai-proxy/wrangler.toml")
    competition_worker, production_worker = worker.split("[env.production]", maxsplit=1)
    for token in (
        'name = "englishplus-ai-proxy"',
        'FIREBASE_PROJECT_ID = "englishplus-testflight"',
        "[env.production]",
        'name = "englishplus-ai-proxy-production"',
        'FIREBASE_PROJECT_ID = "englishplus-production"',
        'bucket_name = "englishplus-volunteer-evidence-production"',
        'namespace_id = "92001"',
        'namespace_id = "92002"',
    ):
        require(token in worker, f"Worker environment boundary missing: {token}", errors)
    require(
        'AI_QUOTA_MODE = "internal"' in competition_worker,
        "Competition Worker must retain the lenient internal AI quota.",
        errors,
    )
    require(
        'AI_QUOTA_MODE = "public"' in production_worker,
        "Production Worker must use the stricter public AI quota.",
        errors,
    )

    admin_config = read("admin-web/src/config.js")
    admin_env_validator = read("admin-web/scripts/validate-env.mjs")
    admin_package = json.loads(read("admin-web/package.json"))
    require("VITE_ENGLISHPLUS_ENVIRONMENT" in admin_config, "Admin build has no environment gate.", errors)
    require("firebaseConfig.projectId !== expectedProjectId" in admin_config, "Admin Firebase mismatch guard is missing.", errors)
    require("new URL(adminApiBaseURL).host !== expectedWorkerHost" in admin_config, "Admin Worker mismatch guard is missing.", errors)
    require("validate:competition-env" in admin_package["scripts"]["build"], "Competition admin build is not fail-closed.", errors)
    require("validate:production-env" in admin_package["scripts"]["build:production"], "Production admin build is not fail-closed.", errors)
    require("Missing required English+ environment value" in admin_env_validator, "Admin prebuild does not reject missing configuration.", errors)
    require("env.VITE_FIREBASE_PROJECT_ID !== expected.projectId" in admin_env_validator, "Admin prebuild does not reject Firebase mixing.", errors)
    require("expected.workerHost" in admin_env_validator, "Admin prebuild does not reject Worker mixing.", errors)
    require("--mode competition" in admin_package["scripts"]["build"], "Default admin build no longer preserves competition.", errors)
    require("--mode production" in admin_package["scripts"]["build:production"], "Production admin build script is missing.", errors)

    competition_hosting = read("firebase.competition.json")
    production_hosting = read("firebase.production.json")
    require("englishplus-testflight.firebaseapp.com" in competition_hosting, "Competition Hosting auth domain is wrong.", errors)
    require("englishplus-ai-proxy.englishplus-ray.workers.dev" in competition_hosting, "Competition Hosting Worker is wrong.", errors)
    require("englishplus-production.firebaseapp.com" in production_hosting, "Production Hosting auth domain is wrong.", errors)
    require("englishplus-ai-proxy-production.englishplus-ray.workers.dev" in production_hosting, "Production Hosting Worker is wrong.", errors)

    release_lock = json.loads(read("docs/app-store-release/release-environment-lock.json"))
    competition_lock = release_lock["competition"]
    production_lock = release_lock["production"]
    require(
        competition_lock.get("publicTestFlightBuild") == PUBLIC_COMPETITION_BUILD,
        "Public competition build is not locked to 53.",
        errors,
    )
    require(
        production_lock.get("minimumCandidateBuild") >= MINIMUM_PRODUCTION_BUILD,
        "Production candidate floor is below build 54.",
        errors,
    )
    require(
        competition_lock.get("publicTestFlightGroup") == "English+公測",
        "Public competition group changed.",
        errors,
    )

    if git_checks_available:
        tracked_files = git("ls-files").splitlines()
        require(
            not any(Path(path).name.startswith("GoogleService-Info") for path in tracked_files),
            "A Firebase iOS configuration file is tracked by Git.",
            errors,
        )
        require("admin-web/.env.production" not in tracked_files, "Production admin configuration is tracked.", errors)
    else:
        print("warning: Git subprocess checks skipped; run the documented shell ref check.")

    if errors:
        print("STORE-0 environment isolation validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("STORE-0 environment isolation validation passed")
    print("- frozen source tag: maic-competition-build-52")
    print(f"- public competition build: {PUBLIC_COMPETITION_BUILD}")
    print(f"- minimum production build: {MINIMUM_PRODUCTION_BUILD}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
