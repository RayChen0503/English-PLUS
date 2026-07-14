#!/usr/bin/env python3
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
IOS_ROOT = ROOT / "ios" / "EnglishPlus" / "EnglishPlus"

TEACHER_SHELL = IOS_ROOT / "Features" / "Teacher" / "TeacherShellView.swift"
TEACHER_HOME = IOS_ROOT / "Features" / "Teacher" / "TeacherHomeView.swift"
VOLUNTEER_SHELL = IOS_ROOT / "Features" / "Volunteer" / "VolunteerShellView.swift"
VOLUNTEER_HOME = IOS_ROOT / "Features" / "Volunteer" / "VolunteerHomeView.swift"
LEARNING_STORE = IOS_ROOT / "Services" / "LearningRepositoryStore.swift"
LEARNING_REPORTING = IOS_ROOT / "Services" / "LearningRepositoryStore+Reporting.swift"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def require_markers(errors: list[str], label: str, text: str, markers: list[str]) -> None:
    for marker in markers:
        if marker not in text:
            errors.append(f"{label} missing marker: {marker}")


def reject_markers(errors: list[str], label: str, text: str, markers: list[str]) -> None:
    for marker in markers:
        if marker in text:
            errors.append(f"{label} still exposes removed marker: {marker}")


def validate_teacher_parity(errors: list[str]) -> None:
    shell = read_text(TEACHER_SHELL)
    home = read_text(TEACHER_HOME)
    store = read_text(LEARNING_STORE) + read_text(LEARNING_REPORTING)

    require_markers(
        errors,
        "TeacherShellView",
        shell,
        [
            'Label("首頁"',
            'Label("班級"',
            'Label("接力"',
            'Label("報告"',
            ".badge(learningRepository.staffDashboardMetrics.waitingHelpCount)",
            "TeacherHomeView()",
            "TeacherClassAssignmentView()",
            "TeacherHandoffView()",
            "TeacherReportView()",
        ],
    )
    reject_markers(
        errors,
        "TeacherShellView",
        shell,
        [
            'Label("學生"',
            'Label("題庫"',
            "TeacherStudentsView()",
            "TeacherQuestionBankView()",
        ],
    )

    require_markers(
        errors,
        "TeacherHomeView",
        home,
        [
            "TeacherHandoffView",
            "TeacherReportView",
            "TeacherClassAssignmentView",
            "TeacherStudentPickerCard",
            "TeacherSelectedStudentPanel",
            "TeacherPracticeSetCatalog",
            "TeacherPracticeSetSkillSection",
            "SupportQuestionSnapshotCard",
            "StaffSupportQueueHeaderCard",
            "TeacherSupportRequestCard",
            "StaffSupportActionBar",
            "archiveSupportThreadForStaff(request.id, by: appState.currentUser)",
        ],
    )
    require_markers(
        errors,
        "LearningRepositoryStore teacher support",
        store,
        [
            "questionBankOverview",
            "staffDashboardMetrics",
            "StaffDashboardMetrics",
            "QuestionBankTypeOverview",
            "assignments(forStudentUid",
            "assignPracticeSet",
            "countsTowardSharedStaffBadge(for: .teacher)",
        ],
    )


def validate_volunteer_parity(errors: list[str]) -> None:
    shell = read_text(VOLUNTEER_SHELL)
    home = read_text(VOLUNTEER_HOME)
    store = read_text(LEARNING_STORE) + read_text(LEARNING_REPORTING)

    require_markers(
        errors,
        "VolunteerShellView",
        shell,
        [
            'Label("首頁", systemImage: "heart.text.square")',
            'Label("接力", systemImage: "flag")',
            'Label("紀錄", systemImage: "list.bullet.rectangle")',
            ".badge(learningRepository.volunteerDashboardMetrics.waitingCount)",
            "VolunteerHomeView()",
            "VolunteerHandoffWorkspaceView()",
            "VolunteerRecordView()",
        ],
    )
    reject_markers(
        errors,
        "VolunteerShellView",
        shell,
        [
            'Label("學生"',
            "VolunteerStudentBriefsView()",
            "VolunteerSyncView()",
            "VolunteerScriptView()",
        ],
    )

    require_markers(
        errors,
        "VolunteerHomeView",
        home,
        [
            "VolunteerHandoffWorkspaceView",
            "VolunteerHandoffSummaryCard",
            "VolunteerSupportRequestCard",
            "VolunteerTodayPriorityCard",
            "VolunteerEmptyQueueCard",
            "VolunteerRecordView",
            "VolunteerRecordView",
            "StaffSupportQueueHeaderCard",
            "StaffSupportActionBar",
            "SupportQuestionSnapshotCard",
            "archiveSupportThreadForStaff(request.id, by: appState.currentUser)",
        ],
    )
    require_markers(
        errors,
        "LearningRepositoryStore volunteer support",
        store,
        [
            "volunteerDashboardMetrics",
            "VolunteerDashboardMetrics",
            "visibleVolunteerReplies",
            "countsTowardSharedStaffBadge(for: .volunteer)",
        ],
    )


def main() -> int:
    errors: list[str] = []
    validate_teacher_parity(errors)
    validate_volunteer_parity(errors)

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print("iOS parity rounds 3-4 validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
