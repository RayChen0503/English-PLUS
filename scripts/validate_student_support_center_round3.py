from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SUPPORT_VIEW = ROOT / "ios" / "EnglishPlus" / "EnglishPlus" / "Features" / "Support" / "SupportView.swift"
PRACTICE_VIEW = ROOT / "ios" / "EnglishPlus" / "EnglishPlus" / "Features" / "Practice" / "PracticeCenterView.swift"
STUDENT_VIEW = ROOT / "ios" / "EnglishPlus" / "EnglishPlus" / "Features" / "Student" / "StudentHomeView.swift"


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise SystemExit(f"Missing {label}: {needle}")


def reject(text: str, needle: str, label: str) -> None:
    if needle in text:
        raise SystemExit(f"Unexpected {label}: {needle}")


def main() -> None:
    support = SUPPORT_VIEW.read_text(encoding="utf-8")
    practice = PRACTICE_VIEW.read_text(encoding="utf-8")
    student = STUDENT_VIEW.read_text(encoding="utf-8")

    require(support, "SupportReplyCenterSummaryCard", "reply center summary")
    require(support, "SupportRequestInboxCard", "support request record card")
    require(support, "SupportReplyTimeline", "reply timeline")
    require(support, "SupportEmptyStateCard", "empty state")
    require(support, "SupportQuestionSnapshotCard", "question snapshot context card")
    require(support, "SupportThreadActionRow", "student archive action row")
    require(support, "markSupportThreadReadByStudent(request.id)", "read-state update")
    require(support, "archiveSupportThreadForStudent(request.id)", "student archive-state update")
    require(support, "supportRequests(forStudentUid: appState.currentUser?.id)", "student scoped support query")
    require(support, "已送給老師與志工，回覆後會出現在這裡。", "shared waiting text")

    reject(support, "ForEach(supportOptions)", "old support option menu")
    reject(support, "supportRow(", "old support row component")
    reject(support, "已送給老師，回覆後會出現在這裡。", "old teacher-only waiting text")
    reject(support, "已送給志工，回覆後會出現在這裡。", "old volunteer-only waiting text")

    require(practice, "PracticeInlineSupportPanel", "inline practice support remains connected")
    require(practice, "送給老師與志工", "shared practice support action")
    require(practice, "sendPracticeSupportRequest(for: item)", "practice shared support send")
    reject(practice, "onSendTeacher", "split teacher practice action")
    reject(practice, "onSendVolunteer", "split volunteer practice action")

    require(student, "MissionQuestionSupportPanel", "daily mission support panel")
    require(student, "送給老師與志工", "shared daily mission support action")
    require(student, "sendMissionSupportRequest(for: item, attempt: attempt)", "daily shared support send")
    reject(student, "onSendTeacher", "split teacher daily action")
    reject(student, "onSendVolunteer", "split volunteer daily action")

    print("student support center round 3 contract passed")


if __name__ == "__main__":
    main()
