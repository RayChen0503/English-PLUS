from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    assert condition, message


mock_repo = read("ios/EnglishPlus/EnglishPlus/Services/MockLearningRepository.swift")
student_shell = read("ios/EnglishPlus/EnglishPlus/Features/Student/StudentShellView.swift")

require(
    "private let cachedQuestionPracticeSets" in mock_repo,
    "MockLearningRepository must cache generated practice sets instead of rebuilding the full 1000+ item catalog on every view render.",
)

question_sets_getter = re.search(
    r"var questionPracticeSets:\s*\[QuestionPracticeSet\]\s*\{(?P<body>.*?)\n\s*\}",
    mock_repo,
    flags=re.S,
)
require(question_sets_getter is not None, "questionPracticeSets getter is missing.")
getter_body = question_sets_getter.group("body")
require(
    "cachedQuestionPracticeSets" in getter_body,
    "questionPracticeSets getter must return the cached catalog.",
)
require(
    "QuestionPracticeSet.catalog" not in getter_body,
    "questionPracticeSets getter must not rebuild QuestionPracticeSet.catalog during SwiftUI rendering.",
)

require(
    "Task { @MainActor in" in student_shell,
    "Practice tab side effects should be deferred onto MainActor instead of mutating repository state synchronously during TabView selection updates.",
)

print("practice tab crash guard passed")
