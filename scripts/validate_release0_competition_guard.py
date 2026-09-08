#!/usr/bin/env python3
"""Validate the immutable competition lane and production release boundary."""

from __future__ import annotations

import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LOCK_PATH = ROOT / "docs/app-store-release/release-environment-lock.json"


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8-sig")


def git(*args: str) -> str:
    return subprocess.check_output(
        ["git", *args], cwd=ROOT, text=True, encoding="utf-8"
    ).strip()


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def main() -> int:
    errors: list[str] = []
    lock = json.loads(LOCK_PATH.read_text(encoding="utf-8"))
    competition = lock["competition"]
    production = lock["production"]
    rules = lock["releaseRules"]

    require(lock["schemaVersion"] == 1, "Unsupported release lock schema.", errors)
    require(competition["publicTestFlightBuild"] == 53, "Competition public build must remain 53.", errors)
    require(production["minimumCandidateBuild"] >= 54, "Production candidate must start at build 54 or later.", errors)
    require(competition["publicTestFlightGroup"] == "English+公測", "Competition group changed.", errors)
    require(
        competition["publicTestFlightLink"] == "https://testflight.apple.com/join/xTWGUg3f",
        "Competition public link changed.",
        errors,
    )

    frozen = competition["frozenSourceCommit"]
    store_baseline = production["sourceBaselineCommit"]
    try:
        require(git("rev-parse", f'{competition["sourceTag"]}^{{}}') == frozen, "Competition source tag moved.", errors)
        require(git("rev-parse", competition["protectionBranch"]) == frozen, "Competition protection branch moved.", errors)
        require(git("merge-base", "HEAD", frozen) == frozen, "Current release work no longer descends from the frozen source.", errors)
        require(
            git("merge-base", "HEAD", store_baseline) == store_baseline,
            "Current release work does not include the completed STORE baseline.",
            errors,
        )
        tracked = set(git("ls-files").splitlines())
        require(
            not any(Path(path).name.startswith("GoogleService-Info") for path in tracked),
            "A Firebase iOS configuration file is tracked by Git.",
            errors,
        )
        require("admin-web/.env.production" not in tracked, "Production admin secrets are tracked by Git.", errors)
    except (OSError, subprocess.CalledProcessError) as exc:
        errors.append(f"Git release guard could not run: {exc}")

    aliases = json.loads(read(".firebaserc"))["projects"]
    require(aliases.get("competition") == competition["firebaseProject"], "Competition Firebase alias changed.", errors)
    require(aliases.get("production") == production["firebaseProject"], "Production Firebase alias changed.", errors)
    require(aliases.get("default") == competition["firebaseProject"], "Default Firebase alias no longer preserves competition.", errors)
    require(competition["firebaseProject"] != production["firebaseProject"], "Firebase environments are not isolated.", errors)

    worker = read("workers/englishplus-ai-proxy/wrangler.toml")
    competition_worker, production_worker = worker.split("[env.production]", maxsplit=1)
    require(f'name = "{competition["workerName"]}"' in competition_worker, "Competition Worker name changed.", errors)
    require(f'FIREBASE_PROJECT_ID = "{competition["firebaseProject"]}"' in competition_worker, "Competition Worker Firebase target changed.", errors)
    require(f'bucket_name = "{competition["r2Bucket"]}"' in competition_worker, "Competition Worker R2 target changed.", errors)
    require('AI_QUOTA_MODE = "internal"' in competition_worker, "Competition Worker quota mode changed.", errors)
    require(f'name = "{production["workerName"]}"' in production_worker, "Production Worker name is wrong.", errors)
    require(f'FIREBASE_PROJECT_ID = "{production["firebaseProject"]}"' in production_worker, "Production Worker Firebase target is wrong.", errors)
    require(f'bucket_name = "{production["r2Bucket"]}"' in production_worker, "Production Worker R2 target is wrong.", errors)
    require('AI_QUOTA_MODE = "public"' in production_worker, "Production Worker quota mode is not public.", errors)

    ci = read("ci_scripts/ci_post_clone.sh")
    require('EnglishPlus) DEPLOYMENT_ENVIRONMENT="production"' in ci, "Release scheme is not production-only.", errors)
    require('PLIST_BASE64="${GOOGLE_SERVICE_INFO_PLIST_BASE64_PRODUCTION:-}"' in ci, "Production CI can fall back to another plist.", errors)
    require(f'EXPECTED_PROJECT_ID="{production["firebaseProject"]}"' in ci, "Production CI project guard is wrong.", errors)
    require(ci == read("ios/EnglishPlus/ci_scripts/ci_post_clone.sh"), "Xcode Cloud scripts have drifted.", errors)

    competition_config = read("firebase.competition.json")
    production_config = read("firebase.production.json")
    require(competition["adminHost"] in competition_config, "Competition Hosting target changed.", errors)
    require(competition["workerHost"] in competition_config, "Competition Hosting Worker target changed.", errors)
    require(production["adminHost"] in production_config, "Production Hosting target is wrong.", errors)
    require(production["workerHost"] in production_config, "Production Hosting Worker target is wrong.", errors)

    freeze_doc = read("docs/app-store-release/store-0-competition-freeze.md")
    release_gate = read("docs/app-store-release/store-4/release-gate.md")
    normalized_gate = " ".join(release_gate.split())
    require("public TestFlight build: `1.0 (53)`" in freeze_doc, "Freeze document does not identify public build 53.", errors)
    require("Production candidate floor: `1.0 (54)`" in freeze_doc, "Freeze document does not reserve build 54+.", errors)
    require("public group `English+公測` still installs build 53" in normalized_gate, "Release gate does not protect public build 53.", errors)
    require("Candidate build number is 54 or higher" in normalized_gate, "Release gate does not reserve build 54+.", errors)

    for key, expected in {
        "neverAssignProductionBuildToCompetitionGroup": True,
        "neverDeployReleaseChangesToCompetitionResources": True,
        "requireExplicitFirebaseProductionAlias": True,
        "requireExplicitCloudflareProductionEnvironment": True,
        "requireManualAppStoreRelease": True,
    }.items():
        require(rules.get(key) is expected, f"Release rule is not locked: {key}", errors)

    if errors:
        print("RELEASE-0 competition guard failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("RELEASE-0 competition guard passed")
    print(f"- frozen source: {frozen}")
    print(f"- public competition build: {competition['publicTestFlightBuild']}")
    print(f"- minimum production candidate: {production['minimumCandidateBuild']}")
    print(f"- production branch: {production['releaseBranch']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
