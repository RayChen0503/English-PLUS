#!/usr/bin/env python3
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
IOS_ROOT = ROOT / "ios" / "EnglishPlus" / "EnglishPlus"
DOC_ROOT = ROOT / "docs" / "ios-parity"

LEARNING_MODELS = IOS_ROOT / "Models" / "LearningModels.swift"
LEARNING_STORE = IOS_ROOT / "Services" / "LearningRepositoryStore.swift"
TEACHER_HOME = IOS_ROOT / "Features" / "Teacher" / "TeacherHomeView.swift"
DOC = DOC_ROOT / "round-6-report-export-parity.md"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def require_markers(errors: list[str], label: str, text: str, markers: list[str]) -> None:
    for marker in markers:
        require(marker in text, f"{label} missing marker: {marker}", errors)


def validate_models(errors: list[str]) -> None:
    text = read_text(LEARNING_MODELS)
    require_markers(
        errors,
        "LearningModels report export",
        text,
        [
            "struct ClassroomReportExport",
            "struct ClassroomReportMetric",
            "struct ClassroomReportStudentRow",
            "struct ClassroomReportQuestionBankRow",
            "shareText",
            "htmlBody",
            "recommendedActions",
        ],
    )


def validate_store(errors: list[str]) -> None:
    text = read_text(LEARNING_STORE)
    require_markers(
        errors,
        "LearningRepositoryStore report export",
        text,
        [
            "var classroomReportExport",
            "ClassroomReportExport(",
            "ClassroomReportMetric(",
            "ClassroomReportStudentRow(",
            "ClassroomReportQuestionBankRow(",
            "teacherQueue.prefix(5)",
            "recommendedReportActions",
            "teacherReportDateFormatter",
        ],
    )


def validate_teacher_ui(errors: list[str]) -> None:
    text = read_text(TEACHER_HOME)
    require_markers(
        errors,
        "TeacherReportView",
        text,
        [
            "let report = learningRepository.makeClassroomReportExport(",
            "rosterStudentCount: appState.classroomStudents.count",
            "TeacherReportMetricGrid(report: report)",
            "TeacherReportPrioritySection(report: report)",
            "TeacherReportQuestionBankSection(report: report)",
            "TeacherReportActionList(report: report)",
            "TeacherReportPreviewCard(report: report)",
            "ShareLink(item: report.shareText)",
            "分享週報",
            "報告預覽",
        ],
    )
    require(".disabled(true)" not in text, "TeacherReportView must not keep a disabled fake share button", errors)


def validate_doc(errors: list[str]) -> None:
    require(DOC.exists(), "missing round 6 report export document", errors)
    if not DOC.exists():
        return
    require_markers(
        errors,
        "round 6 document",
        read_text(DOC),
        [
            "Round 6",
            "report/export parity",
            "ShareLink",
            "classroom report",
            "prototype-level",
            "PDF",
            "Word",
        ],
    )


def main() -> int:
    errors: list[str] = []
    for path in [LEARNING_MODELS, LEARNING_STORE, TEACHER_HOME]:
        require(path.exists(), f"missing file: {path.relative_to(ROOT)}", errors)
    if not errors:
        validate_models(errors)
        validate_store(errors)
        validate_teacher_ui(errors)
        validate_doc(errors)

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print("iOS parity round 6 report export validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
