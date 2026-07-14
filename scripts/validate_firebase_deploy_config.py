#!/usr/bin/env python3
import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PROJECT_ID = "englishplus-testflight"


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def require(condition, message, errors):
    if not condition:
        errors.append(message)


def main():
    errors = []
    firebase_json_path = ROOT / "firebase.json"
    firebaserc_path = ROOT / ".firebaserc"
    gitignore_path = ROOT / ".gitignore"
    functions_index_path = ROOT / "functions" / "src" / "index.ts"

    require(firebase_json_path.exists(), "missing firebase.json", errors)
    require(firebaserc_path.exists(), "missing .firebaserc", errors)
    require(gitignore_path.exists(), "missing .gitignore", errors)
    require(functions_index_path.exists(), "missing functions/src/index.ts", errors)

    if not errors:
        firebase_json = read_json(firebase_json_path)
        firebaserc = read_json(firebaserc_path)
        gitignore = gitignore_path.read_text(encoding="utf-8")
        functions_index = functions_index_path.read_text(encoding="utf-8")

        require(
            firebaserc.get("projects", {}).get("default") == PROJECT_ID,
            f".firebaserc default project must be {PROJECT_ID}",
            errors,
        )

        require(
            "functions" not in firebase_json,
            "firebase.json must not deploy the archived OpenRouter Functions prototype",
            errors,
        )

        require("firestore" in firebase_json, "firebase.json must define Firestore rules", errors)
        firestore = firebase_json.get("firestore", {})
        require(
            firestore.get("rules") == "docs/ios-testflight/firebase/firestore.rules.draft",
            "Firestore rules path must point at the reviewed draft rules",
            errors,
        )

        require("ios/**/GoogleService-Info.plist" in gitignore, "GoogleService-Info.plist must stay ignored", errors)
        require("functions/.secret.local" in gitignore, "local function secrets must stay ignored", errors)
        require("defineSecret(\"OPENROUTER_API_KEY\")" in functions_index, "AI proxy must use OPENROUTER_API_KEY secret", errors)
        archived_notice = (ROOT / "functions" / "README.md").read_text(encoding="utf-8")
        require("must not be deployed" in archived_notice, "archived Functions source needs a deployment warning", errors)
        require("workers/englishplus-ai-proxy" in archived_notice, "archived Functions notice must name the active Worker", errors)

        require(not list(ROOT.glob("**/GoogleService-Info.plist")), "GoogleService-Info.plist must not be committed", errors)
        require(not list(ROOT.glob("**/.secret.local")), "local secret files must not be committed", errors)

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print("Firebase deploy config validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
