from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(label: str, text: str, markers: list[str]) -> None:
    missing = [marker for marker in markers if marker not in text]
    assert not missing, f"Missing {label}: {missing}"


support_view = read("ios/EnglishPlus/EnglishPlus/Features/Support/SupportView.swift")
store = read("ios/EnglishPlus/EnglishPlus/Services/LearningRepositoryStore.swift")


require(
    "student reply center structure",
    support_view,
    [
        "SupportReplyCenterSummaryCard",
        "SupportRequestInboxCard",
        "request.hasStudentUnreadReply",
        "SupportReplyTimeline",
    ],
)

require(
    "student can archive handled support threads",
    support_view + store,
    [
        "SupportThreadActionRow",
        "onArchive",
        "archiveSupportThreadForStudent(request.id)",
        "markSupportThreadReadByStudent",
    ],
)

require(
    "support page stays a focused reply inbox",
    support_view,
    [
        "SupportEmptyStateCard()",
        "SupportQuestionSnapshotCard",
        "SupportReplyTimeline",
    ],
)
assert "onOpenPractice" not in support_view

print("student support reply center round 3 contract passed")
