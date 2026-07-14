#!/usr/bin/env python3
"""Validate Round 13 repository decomposition and synchronization recovery."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def require_markers(
    content: str,
    expected: tuple[str, ...],
    label: str,
    errors: list[str],
) -> None:
    for marker in expected:
        require(marker in content, f"{label} missing marker: {marker}", errors)


def main() -> int:
    errors: list[str] = []
    store_path = ROOT / "ios/EnglishPlus/EnglishPlus/Services/LearningRepositoryStore.swift"
    store = store_path.read_text(encoding="utf-8")
    contracts = read(
        "ios/EnglishPlus/EnglishPlus/Services/LearningRepositoryContracts.swift"
    )
    reporting = read(
        "ios/EnglishPlus/EnglishPlus/Services/LearningRepositoryStore+Reporting.swift"
    )
    connectivity = read(
        "ios/EnglishPlus/EnglishPlus/Services/LearningRepositoryConnectivity.swift"
    )
    banner = read(
        "ios/EnglishPlus/EnglishPlus/Features/Shared/RepositorySyncBanner.swift"
    )
    root = read("ios/EnglishPlus/EnglishPlus/App/RootView.swift")
    diagnostics = read(
        "ios/EnglishPlus/EnglishPlus/Features/Diagnostics/RuntimeDiagnosticsView.swift"
    )
    tests = read(
        "ios/EnglishPlus/EnglishPlusTests/AuthenticationFlowAcceptanceTests.swift"
    )
    project = read("ios/EnglishPlus/EnglishPlus.xcodeproj/project.pbxproj")
    workflow = read(".github/workflows/ios-hardening-build.yml")
    report = read("docs/app-store-hardening/round-13-reliability-decomposition.md")

    require(
        len(store_path.read_text(encoding="utf-8").splitlines()) < 650,
        "LearningRepositoryStore remains an oversized mixed-responsibility file",
        errors,
    )
    require_markers(
        reporting,
        (
            "extension LearningRepositoryStore",
            "var staffDashboardMetrics",
            "var volunteerDashboardMetrics",
            "func makeClassroomReportExport",
        ),
        "repository reporting boundary",
        errors,
    )
    require_markers(
        connectivity,
        (
            "protocol NetworkConnectivityMonitoring",
            "final class NetworkConnectivityMonitor",
            "NWPathMonitor",
            "case disconnected",
            "self.status = nextStatus",
        ),
        "connectivity boundary",
        errors,
    )
    require_markers(
        contracts + store,
        (
            "case connecting(classId: String)",
            "case retrying(classId: String, attempt: Int)",
            "lastSuccessfulSyncAt",
            "func retryRealtimeSync()",
            "scheduleAutomaticRetryIfPossible",
            "retryDelaysNanoseconds",
            "previousStatus == .disconnected",
            "syncContext?.scopeKey == context.scopeKey",
        ),
        "synchronization state machine",
        errors,
    )
    require(
        "String(describing: error)" not in store,
        "technical synchronization errors can still leak into role-facing UI",
        errors,
    )
    require_markers(
        banner + root,
        (
            "RepositorySyncBanner(",
            "目前為離線模式",
            "上次同步",
            'Button("重試"',
            "learningRepository.retryRealtimeSync",
        ),
        "shared recovery UI",
        errors,
    )
    require_markers(
        diagnostics,
        ("case .connecting", "case .retrying"),
        "diagnostic state coverage",
        errors,
    )
    for test_name in (
        "testDisconnectKeepsLocalDataAndReconnectRestartsListener",
        "testListenerFailureRetriesWithBackoffAndRecovers",
        "testStoppingSyncCancelsScheduledRetry",
        "testRepeatedStartForSameScopeDoesNotRestartListener",
    ):
        require(test_name in tests, f"Swift reliability test is missing: {test_name}", errors)

    for filename in (
        "LearningRepositoryContracts.swift",
        "LearningRepositoryConnectivity.swift",
        "LearningRepositoryStore+Reporting.swift",
        "RepositorySyncBanner.swift",
    ):
        require(
            f"/* {filename} */" in project and f"/* {filename} in Sources */" in project,
            f"Xcode target membership is missing for {filename}",
            errors,
        )

    require_markers(
        workflow,
        (
            "codex/app-store-hardening-d",
            ".github/ci-triggers/round13-ios-build",
            "validate_app_store_hardening_round13.py",
        ),
        "isolated macOS gate",
        errors,
    )
    require_markers(
        report,
        (
            "Round 13",
            "Status: Implementation complete",
            "automatic backoff",
            "No Xcode Cloud",
        ),
        "Round 13 evidence",
        errors,
    )

    if errors:
        print("App Store hardening round 13 validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("App Store hardening round 13 reliability validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
