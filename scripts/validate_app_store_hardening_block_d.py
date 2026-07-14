#!/usr/bin/env python3
"""Validate Block D preflight contracts or the final signed-off evidence."""

import argparse
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8-sig")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--preflight",
        action="store_true",
        help="Validate the implementation and report structure before macOS evidence exists.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
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
        "Round 13-16",
        "Swift acceptance",
        "Firebase Emulator",
        "macOS isolated gate",
    ):
        if marker not in report:
            errors.append(f"Round 16 Block D report missing marker: {marker}")
    if args.preflight:
        if "Status: In progress" not in report and "Status: Passed" not in report:
            errors.append("Round 16 Block D preflight report has no recognized status")
    else:
        if "Status: Passed" not in report:
            errors.append("Round 16 Block D report is not signed off")
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
    phase = "preflight" if args.preflight else "signed-off audit"
    print(f"App Store hardening Block D {phase} passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
