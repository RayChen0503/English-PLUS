from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PRACTICE_VIEW = ROOT / "ios" / "EnglishPlus" / "EnglishPlus" / "Features" / "Practice" / "PracticeCenterView.swift"
STUDENT_SHELL = ROOT / "ios" / "EnglishPlus" / "EnglishPlus" / "Features" / "Student" / "StudentShellView.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    practice_source = PRACTICE_VIEW.read_text(encoding="utf-8")
    shell_source = STUDENT_SHELL.read_text(encoding="utf-8")

    require("PracticeCenterView()" in shell_source, "Student shell must expose the practice center as a first-class tab.")
    require("struct PracticeCenterView" in practice_source, "Practice center view is missing.")

    required_tokens = [
        "selectedPracticeType",
        "selectedPracticeLevel",
        "PracticeFilterChip",
        "QuestionType.allCases",
        "QuestionLevel.allCases",
        "currentPracticeItem",
        "practiceAnswer",
        "PracticeResult",
        "isCorrect",
        "acceptedAnswers",
        "submitPracticeAnswer",
        "nextPracticeQuestion",
        "recommendPracticeWithAI",
        "PracticeRecommendationAIContext",
        "practiceAIResponse",
        "recentAccuracy",
        "recentWeakSkills",
    ]

    for token in required_tokens:
        require(token in practice_source, f"Practice center is missing required behavior token: {token}")

    require(
        "SeedData.approvedQuestionBankItems" in practice_source,
        "Practice center must draw from the approved seed question bank.",
    )
    require(
        "filteredPracticeItems" in practice_source,
        "Practice center must filter question bank items instead of showing only a static prefix.",
    )
    require(
        "normalizedPracticeAnswer" in practice_source,
        "Practice center must normalize text answers before checking correctness.",
    )

    forbidden_tokens = [
        "submitMissionAnswer(",
        "generateMission(",
        "FirebaseBackendConfig",
        "OpenRouter",
        "GROQ_API_KEY",
        "cloudfunctions.net",
        "Mock",
    ]
    for token in forbidden_tokens:
        require(token not in practice_source, f"Practice center should not use implementation/detail token: {token}")

    print("Round 5 practice center flow validation passed.")


if __name__ == "__main__":
    main()
