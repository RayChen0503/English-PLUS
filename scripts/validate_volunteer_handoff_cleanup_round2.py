#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
VOLUNTEER_HOME = ROOT / "ios" / "EnglishPlus" / "EnglishPlus" / "Features" / "Volunteer" / "VolunteerHomeView.swift"
SHARED_HANDOFF = ROOT / "ios" / "EnglishPlus" / "EnglishPlus" / "Features" / "Shared" / "StaffSupportActionBar.swift"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def require(text: str, needle: str, label: str, errors: list[str]) -> None:
    if needle not in text:
        errors.append(f"Missing {label}: {needle}")


def forbid(text: str, needle: str, label: str, errors: list[str]) -> None:
    if needle in text:
        errors.append(f"Forbidden {label}: {needle}")


def main() -> int:
    errors: list[str] = []
    if not VOLUNTEER_HOME.exists():
        print(f"missing file: {VOLUNTEER_HOME.relative_to(ROOT)}")
        return 1

    volunteer = read(VOLUNTEER_HOME)
    shared = read(SHARED_HANDOFF)

    forbid(
        volunteer,
        "Text(request.studentMessage)",
        "volunteer handoff raw duplicated student message",
        errors,
    )
    forbid(
        volunteer,
        'Label("陪伴順序"',
        "volunteer companion script block",
        errors,
    )
    forbid(
        volunteer,
        "VolunteerCompanionScriptCard",
        "volunteer separated companion script component",
        errors,
    )
    forbid(
        volunteer,
        "VolunteerScriptTemplate",
        "volunteer scripted sequence templates",
        errors,
    )
    forbid(
        volunteer,
        'Label("這筆求助有題目紀錄，但目前缺少完整題目快照。"',
        "meaningless volunteer handoff without a full question snapshot",
        errors,
    )

    require(
        volunteer,
        "VolunteerMissingQuestionSnapshotLabel()",
        "volunteer low-priority missing-snapshot label for non-question requests",
        errors,
    )
    require(
        volunteer,
        "if let snapshot = request.questionSnapshot",
        "volunteer fallback only when rich question snapshot is absent",
        errors,
    )
    require(
        volunteer,
        "request.staffReplies",
        "volunteer existing replies filtered to staff replies",
        errors,
    )
    require(
        volunteer,
        "SupportQuestionSnapshotCard(",
        "volunteer keeps rich question snapshot card",
        errors,
    )
    require(
        volunteer,
        'Text("接力優先序")',
        "volunteer handoff mirrors teacher handoff title",
        errors,
    )
    require(
        volunteer,
        "StaffSupportQueueHeaderCard(",
        "volunteer handoff uses shared staff queue header",
        errors,
    )
    require(
        volunteer,
        "ForEach(learningRepository.volunteerQueue) { request in",
        "volunteer handoff lists all queue requests like teacher handoff",
        errors,
    )
    require(
        volunteer,
        "StaffSupportQueueRow(request: request)",
        "volunteer handoff uses shared compact queue rows",
        errors,
    )
    require(
        volunteer,
        "StaffSupportDetailView(initialRequest: request, role: .volunteer)",
        "volunteer handoff opens the shared request detail",
        errors,
    )
    require(
        shared,
        "StaffSupportActionBar(",
        "shared request detail uses the staff action bar",
        errors,
    )
    require(
        shared,
        "learningRepository.addVolunteerReply(to: request.id, body: replyDraft)",
        "shared request detail persists volunteer replies",
        errors,
    )
    require(
        shared,
        "appState.coachVolunteerReplyWithAI(",
        "shared request detail keeps volunteer AI drafting",
        errors,
    )
    forbid(
        volunteer,
        "VolunteerSupportRequestCard(request: request)",
        "legacy inline volunteer response composer",
        errors,
    )
    for old_call in [
        "VolunteerQueuePickerCard(",
        "VolunteerSelectedSupportPanel(request:",
        "VolunteerQuestionContextCard(request:",
        "VolunteerCleanGuidanceCard(request:",
        "VolunteerStaffReplyComposerCard(request:",
        "@State private var selectedRequestId",
        "private var selectedRequest:",
    ]:
        forbid(volunteer, old_call, "old volunteer handoff flow call/state", errors)

    if errors:
        for error in errors:
            print(error)
        return 1

    print("volunteer handoff cleanup round 2 contract passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
