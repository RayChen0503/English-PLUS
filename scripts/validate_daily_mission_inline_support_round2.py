from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(label: str, text: str, markers: list[str]) -> None:
    missing = [marker for marker in markers if marker not in text]
    assert not missing, f"Missing {label}: {missing}"


def reject(label: str, text: str, markers: list[str]) -> None:
    present = [marker for marker in markers if marker in text]
    assert not present, f"Unexpected {label}: {present}"


student_home = read("ios/EnglishPlus/EnglishPlus/Features/Student/StudentHomeView.swift")
student_shell = read("ios/EnglishPlus/EnglishPlus/Features/Student/StudentShellView.swift")
store = read("ios/EnglishPlus/EnglishPlus/Services/LearningRepositoryStore.swift")


require(
    "daily mission support state and navigation",
    student_home + student_shell,
    [
        "onOpenSupport: @escaping () -> Void = {}",
        "let onOpenSupport: () -> Void",
        "missionSupportConfirmation",
        "missionSupportSentQuestionIds",
        "StudentHomeView(",
        "selectedTab = .support",
    ],
)

require(
    "daily mission shared inline support panel",
    student_home,
    [
        "MissionQuestionSupportPanel",
        "onAskAI",
        "onSendSupport",
        "supportRequestSent",
        "missionSupportSentKey(for item: QuestionBankItem)",
        "onOpenSupport",
    ],
)

reject(
    "split daily mission support targets",
    student_home,
    [
        "MissionSupportTarget",
        "onSendTeacher",
        "onSendVolunteer",
        "sendMissionSupportRequest(for: item, attempt: attempt, target:",
        "missionSupportOption(for target:",
        "missionSupportMessage(for: item, attempt: attempt, target:",
    ],
)

require(
    "daily mission support request plumbing",
    student_home + store,
    [
        "sendMissionSupportRequest(for: item, attempt: attempt)",
        "learningRepository.sendQuestionSupportRequest(",
        "questionItem: item",
        "selectedAnswer: attempt.selectedAnswer",
        "missionSupportMessage(for: item, attempt: attempt)",
    ],
)

print("daily mission inline support round 2 contract passed")
