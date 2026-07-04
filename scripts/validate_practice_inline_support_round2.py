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


practice_center = read("ios/EnglishPlus/EnglishPlus/Features/Practice/PracticeCenterView.swift")
store = read("ios/EnglishPlus/EnglishPlus/Services/LearningRepositoryStore.swift")
mock_repo = read("ios/EnglishPlus/EnglishPlus/Services/MockLearningRepository.swift")
firebase_repo = read("ios/EnglishPlus/EnglishPlus/Services/FirebaseLearningRepository.swift")


require(
    "inline practice shared support UI",
    practice_center,
    [
        "PracticeInlineSupportPanel",
        "askPracticeAI(for: item)",
        "sendPracticeSupportRequest(for: item)",
        "practiceSupportSentKey(for item: QuestionBankItem)",
        "supportRequestSent",
        "onSendSupport",
        "practiceSupportConfirmation",
    ],
)

reject(
    "split practice support targets",
    practice_center,
    [
        "PracticeSupportTarget",
        "onSendTeacher",
        "onSendVolunteer",
        "sendPracticeSupportRequest(for: item, target:",
        "practiceSupportOption(for target:",
        "practiceSupportMessage(for: item, target:",
    ],
)

require(
    "question-specific support request contract",
    store + mock_repo + firebase_repo,
    [
        "sendQuestionSupportRequest(",
        "questionItem: QuestionBankItem",
        "selectedAnswer: String?",
        "latestQuestionId: questionItem.id",
        "mirrorSupportRequestIfPossible(request)",
        "mirrorStudentSupportMessageIfPossible(request)",
    ],
)

require(
    "practice support message includes question context",
    practice_center,
    [
        "item.question.prompt",
        "answerText",
        "item.question.answer",
        "item.question.explanation",
    ],
)

print("practice inline support round 2 contract passed")
