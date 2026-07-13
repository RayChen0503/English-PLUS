from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PRACTICE_VIEW = ROOT / "ios" / "EnglishPlus" / "EnglishPlus" / "Features" / "Practice" / "PracticeCenterView.swift"


def require_token(source: str, token: str, message: str) -> None:
    if token not in source:
        raise SystemExit(f"Missing {message}: {token}")


def forbid_token(source: str, token: str, message: str) -> None:
    if token in source:
        raise SystemExit(f"Forbidden {message}: {token}")


def main() -> None:
    source = PRACTICE_VIEW.read_text(encoding="utf-8")

    required_tokens = [
        ("practiceSelectionNote", "visible relaxed-filter note"),
        ("practiceOptionOrderByQuestionId", "stable per-question option order cache"),
        ("PracticeSessionSelection", "practice session selection result"),
        ("buildPracticeSessionItems", "shared practice session builder"),
        ("QuestionGroupingEngine.practiceSelection(", "shared exact/fallback practice selector"),
        ("selection.fallbackUsed", "partial-session fallback note"),
        ("fallbackPracticeCandidates", "relaxed fallback candidate search"),
        ("QuestionGroupingEngine.balancedFallbackCandidates(", "shared relaxed fallback candidate search"),
        ("balancedPracticeItems", "balanced item ordering"),
        ("QuestionGroupingEngine.balancedItems(", "shared diversity scoring"),
        ("balancedAnswerOptions", "stable balanced answer option ordering"),
        ("QuestionGroupingEngine.balancedOptions(", "shared answer position balancing"),
        ("shuffledAnswerOptions(for: item)", "answer UI using balanced options"),
        ("buildPracticeSessionItems(from: filteredPracticeItems)", "free practice using shared builder"),
        ("structuredRecommendationSelection(", "AI recommendation structured selector"),
        ("requestPrimarySessionStart(", "validated AI plan entering the guarded primary-session flow"),
        ("items: plan.items", "validated AI plan preserving its question items"),
        ("sourceTitle: plan.title", "validated AI plan preserving its title"),
    ]

    for token, message in required_tokens:
        require_token(source, token, message)

    forbidden_tokens = [
        ("ForEach(item.question.options, id: \\.self)", "direct option ordering"),
        ("Array(filteredPracticeItems.prefix(freePracticeSessionLimit))", "direct filtered prefix session"),
        ("buildPracticeSessionItems(from: plan.items)", "generic filler changing the validated AI plan size"),
    ]

    for token, message in forbidden_tokens:
        forbid_token(source, token, message)

    print("Practice bank fallback and quality round 2 validation passed.")


if __name__ == "__main__":
    main()
