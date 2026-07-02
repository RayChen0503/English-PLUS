from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SUPPORT_VIEW = ROOT / "ios" / "EnglishPlus" / "EnglishPlus" / "Features" / "Support" / "SupportView.swift"
PRACTICE_VIEW = ROOT / "ios" / "EnglishPlus" / "EnglishPlus" / "Features" / "Practice" / "PracticeCenterView.swift"


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise SystemExit(f"Missing {label}: {needle}")


def reject(text: str, needle: str, label: str) -> None:
    if needle in text:
        raise SystemExit(f"Unexpected {label}: {needle}")


def main() -> None:
    support = SUPPORT_VIEW.read_text(encoding="utf-8")
    practice = PRACTICE_VIEW.read_text(encoding="utf-8")

    require(support, "SupportInboxHeaderCard", "support inbox header component")
    require(support, "SupportMoodAICard", "single emotional AI support entry")
    require(support, "SupportRequestInboxCard", "support request record card")
    require(support, "SupportReplyTimeline", "reply timeline")
    require(support, "SupportEmptyStateCard", "empty state")
    require(support, "我的求助紀錄", "support record section title")
    require(support, "練習時可以在題目下方問 AI，或送給老師/志工。", "practice-first support guidance")
    require(support, "SupportQuestionSnapshotCard", "question snapshot context card")
    require(support, "你送出的題目", "student question context label")
    require(support, "看回覆後再練一題", "student follow-up practice action")
    require(support, "老師/志工回覆", "visible staff reply label")
    require(support, "markSupportThreadReadByStudent(request.id)", "read-state update")
    require(support, "supportRequests(forStudentUid: appState.currentUser?.id)", "student scoped support query")
    require(support, "sendEmotionalSupportRequest()", "single support creation action")
    require(support, "provideEmotionalSupportWithAI", "AI emotional support call")
    require(support, "onOpenPractice()", "practice navigation from support")

    reject(support, "ForEach(supportOptions)", "old support option menu")
    reject(support, "supportRow(", "old support row component")

    require(practice, "PracticeInlineSupportPanel", "inline practice support remains connected")
    require(practice, "送給老師", "teacher inline support remains connected")
    require(practice, "送給志工", "volunteer inline support remains connected")

    print("student support center round 3 contract passed")


if __name__ == "__main__":
    main()
