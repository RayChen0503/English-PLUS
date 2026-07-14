#!/usr/bin/env python3
"""Validate the signed-off evidence and CI surface for hardening Block D."""

import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8-sig")


def main() -> int:
    errors: list[str] = []
    for round_number in range(13, 17):
        result = subprocess.run(
            [sys.executable, str(ROOT / f"scripts/validate_app_store_hardening_round{round_number}.py")],
            cwd=ROOT,
            check=False,
        )
        if result.returncode != 0:
            errors.append(f"Round {round_number} validator failed")

    report = read("docs/app-store-hardening/round-16-mastery-spaced-review-block-d-audit.md")
    state = read("docs/app-store-hardening/CURRENT_STATE.md")
    workflow = read(".github/workflows/ios-hardening-build.yml")
    for marker in (
        "Status: Passed",
        "Round 13-16",
        "Swift acceptance",
        "Firebase Emulator",
        "macOS isolated gate",
    ):
        if marker not in report:
            errors.append(f"Round 16 Block D report missing marker: {marker}")
    if "16/20 fully signed off" not in state:
        errors.append("CURRENT_STATE does not record 16/20 signed-off rounds")
    for round_number in range(13, 17):
        if f"validate_app_store_hardening_round{round_number}.py" not in workflow:
            errors.append(f"macOS workflow does not run Round {round_number} validator")

    if errors:
        print("App Store hardening Block D validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1
    print("App Store hardening Block D audit passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
