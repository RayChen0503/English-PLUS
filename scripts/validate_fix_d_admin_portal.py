#!/usr/bin/env python3
"""Static contract checks for FIX-D administrator review portal."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WORKER = ROOT / "workers/englishplus-ai-proxy/src/index.js"
PORTAL = ROOT / "admin-web/src/main.js"
API = ROOT / "admin-web/src/admin-api.js"
CONFIG = ROOT / "admin-web/src/config.js"
COMPETITION_ENV = ROOT / "admin-web/.env.competition"
FIREBASE = ROOT / "firebase.json"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    required_files = [
        ROOT / "admin-web/index.html",
        ROOT / "admin-web/package.json",
        ROOT / "admin-web/package-lock.json",
        PORTAL,
        API,
        CONFIG,
        ROOT / "admin-web/src/admin-state.js",
        ROOT / "admin-web/src/styles.css",
        ROOT / "admin-web/test/admin-api.test.js",
        ROOT / "admin-web/test/admin-state.test.js",
        ROOT / "docs/fixes/fix-d-admin-portal.md",
    ]
    for path in required_files:
        require(path.exists(), f"Missing FIX-D artifact: {path.relative_to(ROOT)}")

    worker = WORKER.read_text(encoding="utf-8")
    portal = PORTAL.read_text(encoding="utf-8")
    api = API.read_text(encoding="utf-8")
    config = CONFIG.read_text(encoding="utf-8")
    competition_env = COMPETITION_ENV.read_text(encoding="utf-8")
    firebase = json.loads(FIREBASE.read_text(encoding="utf-8"))

    for route in [
        "/admin/session",
        "/admin/volunteer-applications",
        "/admin/volunteer-audit",
        "/admin/volunteer-review/",
        "/admin/evidence",
    ]:
        require(route in worker, f"Worker route missing: {route}")

    for contract in [
        "requireAdministrator",
        "STALE_REVIEW_VERSION",
        "SELF_REVIEW_NOT_ALLOWED",
        "reviewEvents",
        "expectedVersion",
        "EVIDENCE_NOT_FOUND",
        "X-EnglishPlus-Request-ID",
    ]:
        require(contract in worker, f"Worker security contract missing: {contract}")

    for workflow in [
        "signInWithEmailAndPassword",
        "sendPasswordResetEmail",
        "loadApplications",
        "openEvidence",
        "commitReview",
        "availableReviewActions",
    ]:
        require(workflow in portal, f"Portal workflow missing: {workflow}")

    require(
        "signInWithPopup" not in portal
        and "signInWithRedirect" not in portal
        and 'data-action="google-login"' not in portal,
        "Admin portal must not expose an unverified federated sign-in path",
    )
    require("createUserWithEmailAndPassword" not in portal, "Admin portal must not offer public registration")
    require(
        'authDomain: requiredValue("VITE_FIREBASE_AUTH_DOMAIN")' in config
        and "VITE_FIREBASE_AUTH_DOMAIN=englishplus-testflight.firebaseapp.com" in competition_env,
        "Firebase Hosting auth must come from the isolated environment config",
    )
    require(
        'canonicalAdminOrigin = `https://${firebaseConfig.authDomain}`' in config
        and 'canonicalWebAppHost = firebaseConfig.authDomain.replace(' in config
        and "location.hostname === canonicalWebAppHost" in portal
        and "location.replace(canonicalURL.toString())" in portal,
        "Each environment web.app alias must canonicalize to its own Firebase Auth host",
    )
    require("Bearer ${token}" in api, "Admin API must send Firebase ID tokens")
    require("OPENROUTER" not in config and "GROQ_API_KEY" not in config, "AI secrets must not enter the portal")
    require("FIREBASE_SERVICE_ACCOUNT_PRIVATE_KEY" not in config, "Service account secret must not enter the portal")
    require(firebase.get("hosting", {}).get("public") == "admin-web/dist", "Firebase Hosting must publish the portal build")
    headers = json.dumps(firebase.get("hosting", {}).get("headers", []))
    require("Content-Security-Policy" in headers, "Hosting must send a content security policy")
    require("frame-ancestors 'none'" in headers, "Portal must block framing")

    print("FIX-D administrator portal contract validation passed.")


if __name__ == "__main__":
    main()
