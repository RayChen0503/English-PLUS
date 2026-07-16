#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8-sig")


def main() -> int:
    models = read("ios/EnglishPlus/EnglishPlus/Models/LearningModels.swift")
    contracts = read("ios/EnglishPlus/EnglishPlus/Services/LearningRepositoryContracts.swift")
    store = read("ios/EnglishPlus/EnglishPlus/Services/LearningRepositoryStore+Reporting.swift")
    firebase = read("ios/EnglishPlus/EnglishPlus/Services/FirebaseLearningRepository.swift")
    support_view = read("ios/EnglishPlus/EnglishPlus/Features/Support/SupportView.swift")
    rules = read("docs/ios-testflight/firebase/firestore.rules.draft")
    rule_tests = read("firebase-tests/test/fix-a-support-sync.test.js")
    worker = read("workers/englishplus-ai-proxy/src/index.js")
    worker_tests = read("workers/englishplus-ai-proxy/test/admin-review.test.js")
    admin_api = read("admin-web/src/admin-api.js")
    admin_ui = read("admin-web/src/main.js")

    checks = {
        "report reasons": (
            models,
            (
                "enum SupportSafetyReportReason",
                "case inappropriateContent",
                "case harassment",
                "case privacyConcern",
            ),
        ),
        "repository boundary": (
            contracts + store + firebase,
            (
                "func reportSupportReply(",
                "func blockSupportAuthor(",
                "blockedSupportAuthors",
                '"reportedUid"',
            ),
        ),
        "student safety UI": (
            support_view,
            (
                'Label("檢舉這則回覆"',
                'Label("封鎖這位回覆者"',
                '"封鎖並收起這筆"',
                'accessibilityLabel("回覆選項")',
            ),
        ),
        "firestore enforcement": (
            rules,
            (
                "blockedSupportAuthorPath",
                "!exists(blockedSupportAuthorPath(thread.studentUid, request.auth.uid))",
                "match /blockedSupportAuthors/{blockedUid}",
                "match /reports/{reportId}",
                "supportMessagePath",
                'request.resource.data.status in ["reviewing", "resolved", "dismissed"]',
            ),
        ),
        "emulator coverage": (
            rule_tests,
            (
                "student can report a visible staff reply",
                "student blocking a staff author prevents future replies",
                "report-forged",
                "teacher-after-block",
            ),
        ),
        "deletion lifecycle": (
            worker,
            (
                '"blockedSupportAuthors"',
                '["reports", "reportedUid"]',
            ),
        ),
        "administrator moderation API": (
            worker + admin_api,
            (
                'url.pathname === "/admin/support-reports"',
                "/admin/support-report/",
                "normalizeAdminSupportReportReviewRequest",
                "supportReportTransitionAllowed",
                "moderationEvents",
                "async supportReports(",
                "async reviewSupportReport(",
            ),
        ),
        "administrator moderation UI": (
            admin_ui,
            (
                'data-workspace="reports"',
                'aria-label="內容檢舉清單"',
                'id="report-review-dialog"',
                'reviewSupportReport(report.classId, report.reportId',
                'reviewing: { label: "開始查核"',
                'resolved: { label: "確認完成"',
                'dismissed: { label: "不成立"',
            ),
        ),
        "administrator moderation tests": (
            worker_tests,
            (
                "support report moderation input and summaries enforce a finite workflow",
                "support report documents retain class scope and immutable moderation context",
                '"/admin/support-reports?status=open"',
                "/admin/support-report/CLASS-8A/report-1",
            ),
        ),
    }

    failures: list[str] = []
    for label, (content, markers) in checks.items():
        for marker in markers:
            if marker not in content:
                failures.append(f"{label} missing marker: {marker}")

    if failures:
        print("App Store UGC safety gate failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print("App Store UGC safety gate passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
