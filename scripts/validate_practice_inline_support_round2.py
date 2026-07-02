from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(label: str, text: str, markers: list[str]) -> None:
    missing = [marker for marker in markers if marker not in text]
    assert not missing, f"Missing {label}: {missing}"


practice_center = read("ios/EnglishPlus/EnglishPlus/Features/Practice/PracticeCenterView.swift")
store = read("ios/EnglishPlus/EnglishPlus/Services/LearningRepositoryStore.swift")
mock_repo = read("ios/EnglishPlus/EnglishPlus/Services/MockLearningRepository.swift")
firebase_repo = read("ios/EnglishPlus/EnglishPlus/Services/FirebaseLearningRepository.swift")


require(
    "inline practice support UI",
    practice_center,
    [
        "PracticeInlineSupportPanel",
        "問 AI 解題",
        "送給老師",
        "送給志工",
        "askPracticeAI(for: item)",
        "sendPracticeSupportRequest(for: item, target: .teacher)",
        "sendPracticeSupportRequest(for: item, target: .volunteer)",
        "practiceSupportConfirmation",
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
        "題目：\\(item.question.prompt)",
        "我的答案：\\(answerText)",
        "正確答案：\\(item.question.answer)",
        "解析：\\(item.question.explanation)",
    ],
)

print("practice inline support round 2 contract passed")
