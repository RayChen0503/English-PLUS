#!/usr/bin/env python3
"""Validate Round 17 student journey and information hierarchy contracts."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8-sig")


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def require_markers(content: str, markers: tuple[str, ...], label: str, errors: list[str]) -> None:
    for marker in markers:
        require(marker in content, f"{label} missing marker: {marker}", errors)


def main() -> int:
    errors: list[str] = []
    home = read("ios/EnglishPlus/EnglishPlus/Features/Student/StudentHomeView.swift")
    shell = read("ios/EnglishPlus/EnglishPlus/Features/Student/StudentShellView.swift")
    classroom = read("ios/EnglishPlus/EnglishPlus/Features/Student/StudentClassroomView.swift")
    support = read("ios/EnglishPlus/EnglishPlus/Features/Support/SupportView.swift")
    learning_map = read("ios/EnglishPlus/EnglishPlus/Features/Student/StudentLearningMapView.swift")
    practice = read("ios/EnglishPlus/EnglishPlus/Features/Practice/PracticeCenterView.swift")
    ui_tests = read("ios/EnglishPlus/EnglishPlusUITests/EnglishPlusCriticalFlowsUITests.swift")

    require_markers(
        home,
        (
            "@State private var showsFreshCheckIn = false",
            "returnChoiceCard",
            "beginFreshCheckIn()",
            'accessibilityIdentifier("student.home.continue")',
            'accessibilityIdentifier("student.home.restartCheckIn")',
            'accessibilityIdentifier("student.home.generateMission")',
            'accessibilityLabel("今日任務進度")',
            "progress.remainingCount",
        ),
        "student home journey",
        errors,
    )
    require("LearningFlowStatusCard" not in home, "legacy duplicate home status card must stay removed", errors)
    require("private var freePracticeCard" not in home, "static duplicate free-practice card must stay removed", errors)
    require(
        home.count("ProgressView(value:") == 1,
        "student home must show only the active question mission progress bar",
        errors,
    )

    require_markers(
        shell,
        (
            ".badge(pendingAssignmentCount)",
            ".badge(unreadSupportReplyCount)",
            "filter(\\.hasStudentUnreadReply)",
            ".tint(EPTheme.primary)",
        ),
        "student navigation",
        errors,
    )

    require_markers(
        classroom,
        (
            'accessibilityIdentifier("student.classroom.showJoin")',
            'accessibilityIdentifier("student.classroom.joinCode")',
            'accessibilityIdentifier("student.classroom.pending")',
            "answeredQuestionCount",
            'ClassroomStatPill(title: "進度"',
            'Button("取消")',
        ),
        "personal and classroom mode",
        errors,
    )
    require(
        'ClassroomStatPill(title: "班級"' not in classroom,
        "student assignment cards must not expose internal class identifiers",
        errors,
    )
    require(
        classroom.rfind("classAccessCard") > classroom.index("pendingSection"),
        "active-class management must follow the assignment content",
        errors,
    )

    require_markers(
        learning_map,
        (
            '@State private var showsRestartConfirmation = false',
            'alert("重新安排今天的任務？"',
            "case optional",
            "case waiting",
            'return "選用"',
            'return "等待中"',
            "isDailyMissionCompleted",
            'accessibilityIdentifier("student.map.primaryAction")',
        ),
        "student learning map",
        errors,
    )
    require(
        "ProgressView(value:" not in learning_map,
        "learning map must not duplicate the in-question progress bar",
        errors,
    )
    require(
        'title: "支持回覆"' in learning_map
        and "appState.currentProfile?.activeClassId != nil || !studentSupportRequests.isEmpty" in learning_map,
        "support route must only appear when it is relevant",
        errors,
    )

    require_markers(
        practice,
        (
            'accessibilityIdentifier("student.practice.selectionHeader")',
            'accessibilityIdentifier("student.practice.askRecommendation")',
            'accessibilityIdentifier("student.practice.start")',
            'accessibilityIdentifier("student.practice.session")',
        ),
        "practice journey",
        errors,
    )
    selection_start = practice.index("private var selectionContent")
    selection_end = practice.index("private var headerCard")
    selection = practice[selection_start:selection_end]
    require(
        selection.index("aiRecommendationCard") < selection.index("filterCard"),
        "AI recommendation must be discoverable before the long manual filters",
        errors,
    )
    require(
        practice.count("ProgressView(value:") == 1,
        "practice must show a progress bar only inside the active finite session",
        errors,
    )

    require(
        "} else if studentRequests.isEmpty {" in support,
        "support empty state must not be stacked below an all-zero summary",
        errors,
    )
    require_markers(
        ui_tests,
        (
            "testStudentNewJourneyKeepsOnePrimaryActionAndOptionalPractice",
            'app.staticTexts["今天先從四題開始"]',
            'app.buttons["前往心情檢測"]',
            'app.staticTexts["選用"]',
        ),
        "Round 17 UI regression",
        errors,
    )

    if errors:
        print("App Store hardening Round 17 validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1
    print("App Store hardening Round 17 student journey validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
