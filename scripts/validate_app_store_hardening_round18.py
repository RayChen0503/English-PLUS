#!/usr/bin/env python3
"""Validate Round 18 staff workspace and information hierarchy contracts."""

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
    shared = read("ios/EnglishPlus/EnglishPlus/Features/Shared/StaffSupportActionBar.swift")
    teacher = read("ios/EnglishPlus/EnglishPlus/Features/Teacher/TeacherHomeView.swift")
    volunteer = read("ios/EnglishPlus/EnglishPlus/Features/Volunteer/VolunteerHomeView.swift")
    ui_tests = read("ios/EnglishPlus/EnglishPlusUITests/EnglishPlusCriticalFlowsUITests.swift")

    require_markers(
        shared,
        (
            "enum StaffSupportWorkspaceRole",
            "struct StaffSupportQueueRow",
            "struct StaffSupportDetailView",
            "learningRepository.supportRequests.first { $0.id == initialRequest.id }",
            'accessibilityIdentifier("staff.handoff.detail")',
            'accessibilityIdentifier("staff.handoff.reply")',
            "learningRepository.addTeacherReply",
            "learningRepository.addVolunteerReply",
            "appState.draftTeacherFeedbackWithAI",
            "appState.coachVolunteerReplyWithAI",
            "archiveSupportThreadForStaff",
            'completionMessage = "回覆已同步給學生。"',
        ),
        "shared staff handoff flow",
        errors,
    )

    require_markers(
        teacher,
        (
            "StaffSupportQueueRow(request: request)",
            "StaffSupportDetailView(initialRequest: request, role: .teacher)",
            'accessibilityIdentifier("teacher.handoff.request.',
            'DisclosureGroup(isExpanded: $showsClassroomSettings)',
            'accessibilityIdentifier("teacher.class.settings")',
            'accessibilityIdentifier("teacher.report.preview")',
        ),
        "teacher workspace",
        errors,
    )
    require(
        "TeacherSupportRequestCard(request: request)" not in teacher,
        "teacher queue must not render the full response composer inline",
        errors,
    )

    require_markers(
        volunteer,
        (
            "StaffSupportQueueRow(request: firstRequest)",
            "StaffSupportDetailView(initialRequest: firstRequest, role: .volunteer)",
            "StaffSupportDetailView(initialRequest: request, role: .volunteer)",
            'accessibilityIdentifier("volunteer.handoff.request.',
            'DisclosureGroup(isExpanded: $isExpanded)',
            'Label(isExpanded ? "收起紀錄" : "查看題目與回覆"',
        ),
        "volunteer workspace",
        errors,
    )
    require(
        "VolunteerSupportRequestCard(request: request)" not in volunteer,
        "volunteer queue must not render the full response composer inline",
        errors,
    )

    require_markers(
        ui_tests,
        (
            "testTeacherWorkspaceKeepsDailyActionsSeparateFromSettingsAndReportDetail",
            'app.descendants(matching: .any)["teacher.class.settings"]',
            'app.descendants(matching: .any)["teacher.report.preview"]',
        ),
        "Round 18 UI regression",
        errors,
    )

    if errors:
        print("App Store hardening Round 18 validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1
    print("App Store hardening Round 18 staff workspace validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
