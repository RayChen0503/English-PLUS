#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8-sig")


def main() -> int:
    checks = {
        "Worker transfer validation": (
            read("workers/englishplus-ai-proxy/src/index.js"),
            (
                "validateAccountDeletionClassTransfers",
                "accountDeletionOwnedClassSummary",
                "appendOwnedClassTransferPlan",
                'ownerTeacherUid: { stringValue: successorUid }',
                'throw httpError(409, "ACCOUNT_CLASS_TRANSFER_SELECTION_STALE")',
                "transferredOwnedClasses",
                "archivedOwnedClasses",
            ),
        ),
        "iOS deletion selection": (
            read("ios/EnglishPlus/EnglishPlus/Features/Shared/AccountDataView.swift")
            + read("ios/EnglishPlus/EnglishPlus/Services/AccountLifecycleService.swift")
            + read("ios/EnglishPlus/EnglishPlus/App/AppState.swift"),
            (
                "AccountDeletionOwnedClass",
                "eligibleCoTeachers",
                "selectedClassSuccessors",
                "hasCompleteClassTransferSelections",
                "classTransfers: selectedClassSuccessors",
                "classTransferSelectionStale",
            ),
        ),
        "Transfer and archive tests": (
            read("workers/englishplus-ai-proxy/test/account-deletion.test.js")
            + read("firebase-tests/test/round11-account-deletion-lifecycle.test.js")
            + read("ios/EnglishPlus/EnglishPlusTests/AuthenticationFlowAcceptanceTests.swift"),
            (
                "confirmed active co-teacher",
                "only when no eligible co-teacher exists",
                "ACCOUNT_CLASS_TRANSFER_SELECTION_REQUIRED",
                "testOwnedClassRequiresSelectionOnlyWhenAnEligibleCoTeacherExists",
            ),
        ),
        "Audit report": (
            read("docs/app-store-release/store-3-class-ownership-transfer.md"),
            ("38/38", "10/10", "No deployment, push or Xcode Cloud"),
        ),
    }
    failures = []
    for label, (content, markers) in checks.items():
        for marker in markers:
            if marker not in content:
                failures.append(f"{label} missing marker: {marker}")
    if failures:
        print("STORE-3 class ownership transfer gate failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1
    print("STORE-3 class ownership transfer gate passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
