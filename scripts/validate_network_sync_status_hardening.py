#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8-sig")


def main() -> int:
    contracts = read("ios/EnglishPlus/EnglishPlus/Services/LearningRepositoryContracts.swift")
    connectivity = read("ios/EnglishPlus/EnglishPlus/Services/LearningRepositoryConnectivity.swift")
    store = read("ios/EnglishPlus/EnglishPlus/Services/LearningRepositoryStore.swift")
    banner = read("ios/EnglishPlus/EnglishPlus/Features/Shared/RepositorySyncBanner.swift")
    app_state = read("ios/EnglishPlus/EnglishPlus/App/AppState.swift")
    tests = read("ios/EnglishPlus/EnglishPlusTests/AuthenticationFlowAcceptanceTests.swift")
    firebase_repository = read(
        "ios/EnglishPlus/EnglishPlus/Services/FirebaseLearningRepository.swift"
    )
    audit = read("docs/app-store-release/network-sync-status-hardening.md")

    checks = {
        "scoped status": (
            contracts + banner,
            (
                "syncIssue(reason: String, retryAvailable: Bool)",
                "部分資料暫時無法同步",
                "showsRetry: retryAvailable",
                "case .offlineFallback",
                "showsRetry: false",
            ),
        ),
        "failure classification": (
            connectivity,
            (
                "LearningRepositorySyncFailureClassifier",
                "NSURLErrorNotConnectedToInternet",
                "domain.contains(\"firestore\")",
                "目前帳號沒有讀取這部分資料的權限",
                "shouldRetry: false",
                "shouldRetry: true",
            ),
        ),
        "stable retry lifecycle": (
            store,
            (
                "listenerGeneration",
                "recoveryConfirmationDelayNanoseconds",
                "scheduleRecoveryConfirmation",
                "presentsProgress: false",
                "guard syncStatus != status else { return }",
                "if connectivityStatus == .disconnected",
            ),
        ),
        "component listener isolation": (
            contracts + connectivity + store + firebase_repository,
            (
                "LearningRepositoryListenerHealthEvent",
                "LearningRepositoryComponentIssueRegistry",
                "onComponentHealth",
                "support-messages:\\(request.id)",
                "handleComponentHealth",
                "componentIssues.isEmpty",
                "let unresolvedIssue = componentIssues.presentation",
                "A healthy sibling snapshot must not hide another listener's failure.",
            ),
        ),
        "role listener copy": (
            app_state,
            (
                "realtimeListenerMessage",
                "lastVolunteerServiceListenerErrorMessage",
                "lastClassroomVolunteerListenerErrorMessage",
                "lastMembershipListenerErrorMessage",
            ),
        ),
        "acceptance coverage": (
            tests,
            (
                "testDisconnectKeepsLocalDataAndReconnectRestartsListener",
                "testListenerFailureRetriesWithBackoffAndRecovers",
                "testPermissionFailureIsNotReportedAsOfflineOrRetried",
                "testRepeatedNonRetryableFailureDoesNotRestartOrChangeIssue",
                "testErrorFromReplacedListenerInSameScopeIsIgnored",
                "testComponentFailureDoesNotRestartWholeListenerBundleOrClearFromSiblingSnapshot",
                "testManualRetryRestartsComponentFailureOnlyWhenRetryIsAvailable",
            ),
        ),
        "audit": (
            audit,
            (
                "Confirmed root cause",
                "Only an unsatisfied `NWPathMonitor` path is presented as offline mode",
                "No push, deployment or Xcode Cloud run",
            ),
        ),
    }

    failures: list[str] = []
    for label, (content, markers) in checks.items():
        for marker in markers:
            if marker not in content:
                failures.append(f"{label} missing marker: {marker}")

    forbidden = (
        "服務班級狀態暫時無法同步，請檢查網路後重新整理。",
        "志工申請暫時無法同步，請檢查網路後重新整理。",
        "班級狀態暫時無法同步，請檢查網路後重新整理。",
    )
    for text in forbidden:
        if text in app_state:
            failures.append(f"obsolete unconditional network diagnosis remains: {text}")

    if failures:
        print("Network synchronization status gate failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print("Network synchronization status gate passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
