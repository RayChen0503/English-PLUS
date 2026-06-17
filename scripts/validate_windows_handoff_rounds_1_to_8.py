#!/usr/bin/env python3
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


CHECKS = [
    ("rounds 1-6", ["python3", "scripts/validate_windows_handoff_rounds_1_to_6.py"]),
    ("round 7 AI", ["python3", "scripts/validate_round7_ai_service_contract.py"]),
    ("round 8 TestFlight", ["python3", "scripts/validate_round8_testflight_preparation.py"]),
]


def main():
    failures = []

    for label, command in CHECKS:
        result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True)
        if result.returncode != 0:
            failures.append((label, result.stderr.strip() or result.stdout.strip()))

    if failures:
        for label, output in failures:
            print(f"ERROR: {label} validation failed", file=sys.stderr)
            if output:
                print(output, file=sys.stderr)
        return 1

    print("Windows handoff rounds 1-8 validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
