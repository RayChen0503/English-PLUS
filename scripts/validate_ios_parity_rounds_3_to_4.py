#!/usr/bin/env python3
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
IOS_ROOT = ROOT / "ios" / "EnglishPlus" / "EnglishPlus"
DOC_ROOT = ROOT / "docs" / "ios-parity"

TEACHER_SHELL = IOS_ROOT / "Features" / "Teacher" / "TeacherShellView.swift"
TEACHER_HOME = IOS_ROOT / "Features" / "Teacher" / "TeacherHomeView.swift"
VOLUNTEER_SHELL = IOS_ROOT / "Features" / "Volunteer" / "VolunteerShellView.swift"
VOLUNTEER_HOME = IOS_ROOT / "Features" / "Volunteer" / "VolunteerHomeView.swift"
LEARNING_STORE = IOS_ROOT / "Services" / "LearningRepositoryStore.swift"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def fail(errors: list[str], message: str) -> None:
    errors.append(message)


def require_markers(errors: list[str], label: str, text: str, markers: list[str]) -> None:
    for marker in markers:
        if marker not in text:
            fail(errors, f"{label} missing marker: {marker}")


def reject_markers(errors: list[str], label: str, text: str, markers: list[str]) -> None:
    for marker in markers:
        if marker in text:
            fail(errors, f"{label} still exposes removed marker: {marker}")


def validate_docs(errors: list[str]) -> None:
    docs = {
        "round-3-teacher-parity.md": [
            "Teacher parity",
            "今日",
            "學生",
            "接力",
            "報告",
            "班級",
            "TeacherClassAssignmentView",
            "standalone `題庫` tab is intentionally removed",
        ],
        "round-4-volunteer-parity.md": [
            "Volunteer parity",
            "今日",
            "接力",
            "紀錄",
            "VolunteerHandoffWorkspaceView",
            "SupportQuestionSnapshotCard",
        ],
    }
    for filename, markers in docs.items():
        path = DOC_ROOT / filename
        if not path.exists():
            fail(errors, f"missing parity document: {filename}")
            continue
        require_markers(errors, filename, read_text(path), markers)


def validate_teacher_parity(errors: list[str]) -> None:
    shell = read_text(TEACHER_SHELL)
    home = read_text(TEACHER_HOME)
    store = read_text(LEARNING_STORE)

    require_markers(
        errors,
        "TeacherShellView",
        shell,
        [
            'Label("今日"',
            'Label("學生"',
            'Label("接力"',
            'Label("報告"',
            'Label("班級"',
            "TeacherHomeView()",
            "TeacherStudentsView()",
            "TeacherHandoffView()",
            "TeacherReportView()",
            "TeacherClassAssignmentView()",
        ],
    )
    reject_markers(
        errors,
        "TeacherShellView",
        shell,
        [
            'Label("題庫"',
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
            "TeacherPracticeSetCatalogSection",
            "SupportQuestionSnapshotCard",
            "班級週報",
            "班級派題",
            "每組最多 12 題",
            "接力優先序",
            "學生資料",
            "送出回饋",
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
        ],
    )


def validate_volunteer_parity(errors: list[str]) -> None:
    shell = read_text(VOLUNTEER_SHELL)
    home = read_text(VOLUNTEER_HOME)
    store = read_text(LEARNING_STORE)

    require_markers(
        errors,
        "VolunteerShellView",
        shell,
        [
            'Label("今日", systemImage: "heart.text.square")',
            'Label("接力", systemImage: "flag")',
            'Label("紀錄", systemImage: "list.bullet.rectangle")',
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
            'Label("同步"',
            'Label("腳本"',
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
            "VolunteerQueuePickerCard",
            "VolunteerSelectedSupportPanel",
            "VolunteerQuestionContextCard",
            "VolunteerReplyComposerCard",
            "VolunteerRecordView",
            "VolunteerScriptTemplate",
            "先接住，再陪一題",
            "接力紀錄",
            "送出陪伴回覆",
            "SupportQuestionSnapshotCard",
            "學生答案與正解",
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
        ],
    )


def main() -> int:
    errors: list[str] = []
    validate_docs(errors)
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
