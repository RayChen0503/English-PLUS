#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise SystemExit(f"Missing {label}: {needle}")


def forbid(text: str, needle: str, label: str) -> None:
    if needle in text:
        raise SystemExit(f"Forbidden {label}: {needle}")


def main() -> None:
    support = read("ios/EnglishPlus/EnglishPlus/Features/Support/SupportView.swift")
    teacher = read("ios/EnglishPlus/EnglishPlus/Features/Teacher/TeacherHomeView.swift")
    models = read("ios/EnglishPlus/EnglishPlus/Models/LearningModels.swift")

    forbid(
        support,
        "Text(request.studentMessage)",
        "student support page duplicated raw request message",
    )
    forbid(
        teacher,
        "Text(request.studentMessage)",
        "teacher handoff card duplicated raw request message",
    )

    require(
        support,
        "SupportOriginalStudentMessageCard(message: request.studentMessage)",
        "student fallback message card for non-question requests",
    )
    require(
        support,
        "if request.questionSnapshot == nil",
        "student fallback message only when no rich question snapshot exists",
    )
    require(
        support,
        "if visibleReplies.isEmpty",
        "student archive action gated behind visible replies",
    )
    require(
        support,
        "request.visibleStaffRepliesToStudent",
        "student support page filters replies to staff-visible replies",
    )
    require(
        support,
        "SupportReplyTimeline(replies: visibleReplies)",
        "student reply timeline contains staff replies",
    )
    require(
        support,
        "SupportThreadActionRow(",
        "student can archive only handled reply threads",
    )

    require(
        teacher,
        "StaffMissingQuestionSnapshotLabel()",
        "teacher low-priority missing-snapshot label for non-question requests",
    )
    require(
        teacher,
        "request.staffReplies",
        "teacher handoff card filters existing replies to staff replies",
    )
    require(
        teacher,
        "SupportQuestionSnapshotCard(",
        "teacher keeps rich question snapshot card",
    )
    require(
        models,
        "var visibleStaffRepliesToStudent: [SupportReply]",
        "shared student-visible staff reply helper",
    )
    require(
        models,
        "var isStaffReply: Bool",
        "shared staff reply role helper",
    )

    print("support reply dedup round 1 contract passed")


if __name__ == "__main__":
    main()
