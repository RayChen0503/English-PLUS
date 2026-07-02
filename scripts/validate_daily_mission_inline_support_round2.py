from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(label: str, text: str, markers: list[str]) -> None:
    missing = [marker for marker in markers if marker not in text]
    assert not missing, f"Missing {label}: {missing}"


student_home = read("ios/EnglishPlus/EnglishPlus/Features/Student/StudentHomeView.swift")
student_shell = read("ios/EnglishPlus/EnglishPlus/Features/Student/StudentShellView.swift")
store = read("ios/EnglishPlus/EnglishPlus/Services/LearningRepositoryStore.swift")


require(
    "daily mission support state and navigation",
    student_home + student_shell,
    [
        "init(onOpenSupport:",
        "let onOpenSupport: () -> Void",
        "missionSupportConfirmation",
        "missionSupportSentQuestionIds",
        "StudentHomeView(",
        "selectedTab = .support",
    ],
)

require(
    "daily mission inline support panel",
    student_home,
    [
        "MissionQuestionSupportPanel",
        "onAskAI",
        "onSendTeacher",
        "onSendVolunteer",
        "onOpenSupport",
        "問 AI 解題",
        "送給老師",
        "送給志工",
        "前往支持查看回覆",
    ],
)

require(
    "daily mission support request plumbing",
    student_home + store,
    [
        "sendMissionSupportRequest(for: item, attempt: attempt, target: .teacher)",
        "sendMissionSupportRequest(for: item, attempt: attempt, target: .volunteer)",
        "learningRepository.sendQuestionSupportRequest(",
        "questionItem: item",
        "selectedAnswer: attempt.selectedAnswer",
        "missionSupportMessage(for: item, attempt: attempt, target: target)",
    ],
)

print("daily mission inline support round 2 contract passed")
