#!/usr/bin/env python3
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8-sig")


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def markers(content: str, expected: tuple[str, ...], label: str, errors: list[str]) -> None:
    for marker in expected:
        require(marker in content, f"{label} missing marker: {marker}", errors)


def main() -> int:
    errors: list[str] = []
    decisions = read("docs/app-store-hardening/DECISIONS.md")
    worker = read("workers/englishplus-ai-proxy/src/index.js")
    worker_tests = read("workers/englishplus-ai-proxy/test/account-deletion.test.js")
    lifecycle = read("ios/EnglishPlus/EnglishPlus/Services/AccountLifecycleService.swift")
    account_view = read("ios/EnglishPlus/EnglishPlus/Features/Shared/AccountDataView.swift")
    app_state = read("ios/EnglishPlus/EnglishPlus/App/AppState.swift")
    repository = read("ios/EnglishPlus/EnglishPlus/Services/LearningRepositoryStore.swift")
    mock_repository = read("ios/EnglishPlus/EnglishPlus/Services/MockLearningRepository.swift")
    firebase_repository = read("ios/EnglishPlus/EnglishPlus/Services/FirebaseLearningRepository.swift")
    models = read("ios/EnglishPlus/EnglishPlus/Models/LearningModels.swift")
    student = read("ios/EnglishPlus/EnglishPlus/Features/Student/StudentHomeView.swift")
    teacher = read("ios/EnglishPlus/EnglishPlus/Features/Teacher/TeacherHomeView.swift")
    volunteer = read("ios/EnglishPlus/EnglishPlus/Features/Volunteer/VolunteerHomeView.swift")
    rules = read("docs/ios-testflight/firebase/firestore.rules.draft")
    rule_tests = read("firebase-tests/test/round8-firestore-contract.test.js")
    lifecycle_test = read("firebase-tests/test/round11-account-deletion-lifecycle.test.js")
    indexes = json.loads(read("docs/ios-testflight/firebase/firestore.indexes.draft.json"))
    smoke = read("scripts/smoke_worker_firebase_runtime.py")
    workflow = read(".github/workflows/ios-hardening-build.yml")
    report = read("docs/app-store-hardening/round-11-account-deletion-human-help.md")

    markers(decisions, ("D-19", "D-20", "anonymous aggregate", "explicit human-help"), "Decision register", errors)
    markers(worker, (
        'url.pathname === "/account/deletion-preview"',
        'url.pathname === "/account"',
        "requireRecentAuthentication(user)",
        'existingPhase === "legacySupportMessages"',
        'existingPhase === "ownedClasses"',
        'existingPhase === "classStudentData"',
        "accountDeletionJobProgress",
        "anonymousProductMetrics/account-deletions-",
        "deleteVolunteerEvidenceForAccount",
        "deleteFirebaseAuthAccount",
        "FIREBASE_WEB_API_KEY",
        "retryPendingAccountDeletions",
        "retainedData: \"anonymousAggregateOnly\"",
        "staffEscalationNeeded: false",
        "Taiwan emergency service 119; 1925 and 113",
    ), "Worker deletion and safety contract", errors)
    require(
        "staffEscalationNeeded: true" not in worker,
        "Worker can still tell a student that staff were notified automatically",
        errors,
    )
    markers(worker_tests, (
        "large accounts are staged before the final destructive pass",
        "deletion jobs retain class cleanup queues",
        "AI output can never claim that a human escalation happened automatically",
    ), "Worker account-deletion tests", errors)

    markers(lifecycle, (
        "struct RemoteAccountLifecycleService",
        'appendingPathComponent("deletion-preview")',
        'request.httpMethod = "DELETE"',
        "for _ in 0..<120",
        'value(forHTTPHeaderField: "Retry-After")',
        "AccountLifecycleError.recentSignInRequired",
    ), "iOS account lifecycle", errors)
    markers(account_view, (
        'navigationTitle("帳號與資料")',
        'TextField("刪除", text: $confirmationText)',
        'alert("永久刪除這個帳號？"',
        'detail: "離開 \\(preview.classMembershipCount) 個班級並停止後續存取"',
        'detail: "封存 \\(preview.ownedClassCount) 個班級，未完成任務停止派送"',
        "interactiveDismissDisabled(appState.isManagingAccount)",
        "ViewThatFits(in: .horizontal)",
        "learningRepository.eraseLocalData(for: uid)",
    ), "Account deletion UI", errors)
    markers(app_state, (
        "func loadAccountDeletionPreview()",
        "func deleteCurrentAccount()",
        "func completeAccountDeletion()",
    ), "App state account lifecycle", errors)
    markers(repository, ("func eraseLocalData(for uid: String)",), "Repository local deletion", errors)
    markers(mock_repository, (
        "func clearAllScopes(for uid: String)",
        "scope == normalizedUid || scope.hasPrefix(\"\\(normalizedUid)--\")",
        "defaults.removeObject(forKey: legacyPersonalKey)",
    ), "UID-scoped local cleanup", errors)
    markers(firebase_repository, (
        '"messageContextVersion": 2',
        '"studentUid": request.studentUid',
        '"riskLevel": RiskLevel.low.rawValue',
    ), "Firestore deletion and human-help context", errors)

    markers(models, (
        "var hasActionableHumanSupportContext: Bool",
        "hasCompleteQuestionSnapshotForStaff || hasActionableHumanSupportContext",
        "let priorityHelpCount: Int",
    ), "Human-help queue model", errors)
    markers(student, (
        'Label("今天先不用硬撐", systemImage: "heart.circle.fill")',
        'Label("主動請老師或志工陪我", systemImage: "person.2.fill")',
        'HumanHelpPhoneLink(title: "安心專線 1925"',
        'HumanHelpPhoneLink(title: "保護專線 113"',
        'HumanHelpPhoneLink(title: "有立即危險請撥 119"',
        "showsHumanSupportConfirmation = true",
    ), "Student explicit human-help flow", errors)
    markers(teacher, (
        "StaffHumanSupportRequestCard",
        'TeacherStatusTile(title: "優先回覆"',
        "metrics.priorityHelpCount",
    ), "Teacher explicit support queue", errors)
    markers(volunteer, ("StaffHumanSupportRequestCard",), "Volunteer explicit support queue", errors)
    for obsolete in ("高風險", "中風險", "低風險", "highRiskCount"):
        require(
            obsolete not in teacher + volunteer + models,
            f"Role-facing automatic risk language remains: {obsolete}",
            errors,
        )

    markers(rules, (
        "match /accountDeletionJobs/{uid}",
        "match /anonymousProductMetrics/{metricId}",
        "allow read, write: if false;",
    ), "Firestore server-only deletion state", errors)
    markers(rule_tests, ("account deletion jobs and anonymous metrics are backend-only",), "Firestore Rules tests", errors)
    markers(lifecycle_test, (
        "staged account deletion removes identifiable data and preserves only safe class history",
        'assert.equal(result.retainedData, "anonymousAggregateOnly")',
        'assert.equal(JSON.stringify(metric).includes(UID), false)',
    ), "Staged deletion Emulator test", errors)
    required_indexes = {
        ("users", "activeClassId"),
        ("members", "uid"),
        ("students", "uid"),
        ("supportThreads", "studentUid"),
        ("messages", "studentUid"),
        ("messages", "authorUid"),
    }
    actual_indexes = {
        (item.get("collectionGroup"), item.get("fieldPath"))
        for item in indexes.get("fieldOverrides", [])
    }
    require(required_indexes <= actual_indexes, "Deletion query indexes are incomplete", errors)
    markers(smoke, (
        'f"authenticated_{role}_account_deletion_preview"',
        "exercise_account_deletion",
        "deleted_account_cannot_sign_in_again",
    ), "Production deletion smoke suite", errors)
    markers(workflow, (
        ".github/ci-triggers/round11-ios-build",
        "validate_app_store_hardening_round11.py",
    ), "Round 11 isolated macOS gate", errors)
    markers(report, (
        "Round 11",
        "D-19",
        "D-20",
        "staged",
        "No Xcode Cloud",
    ), "Round 11 report", errors)

    if errors:
        print("App Store hardening round 11 validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("App Store hardening round 11 account deletion and human-help validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
