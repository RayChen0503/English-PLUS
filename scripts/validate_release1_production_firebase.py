#!/usr/bin/env python3
"""Validate the RELEASE-1 production Firebase identity foundation."""

from __future__ import annotations

import json
import os
import plistlib
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
GIT_EXECUTABLE = os.environ.get("ENGLISHPLUS_GIT_EXECUTABLE", "git")
LOCK_PATH = ROOT / "docs/app-store-release/release-environment-lock.json"
REPORT_PATH = ROOT / "docs/app-store-release/release-1-production-firebase-foundation.md"
PLIST_PATH = ROOT / "ios/EnglishPlus/EnglishPlus/GoogleService-Info.plist"


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


def main() -> int:
    errors: list[str] = []
    lock = json.loads(LOCK_PATH.read_text(encoding="utf-8"))
    production = lock["production"]
    competition = lock["competition"]

    expected = {
        "firebaseProject": "englishplus-production",
        "firebaseProjectNumber": "410725934322",
        "firebaseIosAppId": "1:410725934322:ios:4eada3d210b1b4c923dc6b",
        "firebaseWebAppId": "1:410725934322:web:f558ce818c91e0b123dc6b",
        "iosBundleId": "com.englishplus",
        "appStoreId": "6785041320",
        "adminHost": "englishplus-production.firebaseapp.com",
    }
    for key, value in expected.items():
        require(production.get(key) == value, f"Wrong production identity: {key}", errors)

    require(competition["firebaseProject"] == "englishplus-testflight", "Competition Firebase project changed.", errors)
    require(competition["publicTestFlightBuild"] == 53, "Competition public build changed.", errors)
    require(competition["publicTestFlightGroup"] == "English+公測", "Competition public group changed.", errors)
    require(production["minimumCandidateBuild"] >= 54, "Production candidate floor is below build 54.", errors)

    providers = production.get("authProviders", {})
    require(providers.get("emailPassword") == "enabled", "Email/password is not recorded as enabled.", errors)
    require(providers.get("emailLink") == "disabled", "Email-link state is not locked as disabled.", errors)
    require(providers.get("google") == "enabled", "Google provider is not recorded as enabled.", errors)
    require(providers.get("apple") == "enabled", "Apple provider is not recorded as enabled.", errors)

    apple = production.get("appleAuth", {})
    require(apple.get("servicesId") == "com.englishplus.firebaseauth", "Apple Services ID is wrong.", errors)
    require(apple.get("teamId") == "X7Y2V4D87G", "Apple Team ID is wrong.", errors)
    require(apple.get("keyId") == "WAU6QVCTR6", "Apple Key ID is wrong.", errors)
    require(apple.get("nativeIosReady") is True, "Native iOS Apple path is not marked ready.", errors)
    require(
        apple.get("productionWebCallback") == "configured-and-verified",
        "Apple production web callback status is not explicit.",
        errors,
    )

    require(PLIST_PATH.is_file(), "Production GoogleService-Info.plist is missing locally.", errors)
    if PLIST_PATH.is_file():
        with PLIST_PATH.open("rb") as handle:
            plist = plistlib.load(handle)
        require(plist.get("PROJECT_ID") == expected["firebaseProject"], "Local plist points to the wrong project.", errors)
        require(plist.get("BUNDLE_ID") == expected["iosBundleId"], "Local plist has the wrong bundle ID.", errors)
        require(plist.get("GOOGLE_APP_ID") == expected["firebaseIosAppId"], "Local plist has the wrong app ID.", errors)
        require(bool(plist.get("CLIENT_ID")), "Local plist has no Google client ID.", errors)
        require(bool(plist.get("REVERSED_CLIENT_ID")), "Local plist has no reversed client ID.", errors)

    ignored = git("check-ignore", "--quiet", str(PLIST_PATH.relative_to(ROOT)))
    require(ignored.returncode == 0, "Production plist is not ignored by Git.", errors)
    tracked = git("ls-files").stdout.splitlines()
    require(
        not any(Path(path).name.startswith("GoogleService-Info") for path in tracked),
        "A Firebase iOS configuration file is tracked by Git.",
        errors,
    )
    require(not any(path.lower().endswith(".p8") for path in tracked), "An Apple private key is tracked by Git.", errors)
    require(not any("authkey_" in path.lower() for path in tracked), "An Apple AuthKey file is tracked by Git.", errors)

    report = REPORT_PATH.read_text(encoding="utf-8")
    for token in (
        "englishplus-production",
        "englishplus-testflight",
        "Email/password: enabled",
        "Google: enabled",
        "Apple: enabled",
        "configured-and-verified",
        "No GitHub push or Xcode Cloud trigger was performed",
    ):
        require(token in report, f"RELEASE-1 report is missing: {token}", errors)

    auth_service = (ROOT / "ios/EnglishPlus/EnglishPlus/Services/FirebaseAuthService.swift").read_text(encoding="utf-8")
    coordinator = (ROOT / "ios/EnglishPlus/EnglishPlus/Services/FederatedSignInCoordinator.swift").read_text(encoding="utf-8")
    require("OAuthProvider.appleCredential" in auth_service, "Native Apple credential exchange is missing.", errors)
    require("ASAuthorizationAppleIDRequest" in coordinator, "Native Apple authorization flow is missing.", errors)

    if errors:
        print("RELEASE-1 production Firebase validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("RELEASE-1 production Firebase validation passed")
    print(f"- Firebase project: {production['firebaseProject']}")
    print(f"- iOS app: {production['firebaseIosAppId']}")
    print(f"- Web app: {production['firebaseWebAppId']}")
    print("- Email, Google and Apple providers: enabled")
    print("- production plist: local, ignored and untracked")
    print("- Apple production web callback: configured and verified")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
