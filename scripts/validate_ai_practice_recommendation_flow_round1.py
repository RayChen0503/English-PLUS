from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PRACTICE_VIEW = ROOT / "ios" / "EnglishPlus" / "EnglishPlus" / "Features" / "Practice" / "PracticeCenterView.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    source = PRACTICE_VIEW.read_text(encoding="utf-8")

    required_tokens = [
        "AIPracticeRecommendationPlan",
        "recommendedPracticePlan",
        "buildAIRecommendationPlan",
        "applyAIRecommendedPracticePlan",
        "startPracticeSession(with:",
        "recommendationSearchText",
        "inferRecommendedQuestionTypes",
        "scoreAIRecommendedItem",
        "PracticeAIRecommendationActionCard(plan:",
    ]

    for token in required_tokens:
        require(token in source, f"Practice AI recommendation flow is missing token: {token}")

    require(
        "onApplyRecommendation: applyAIRecommendedPracticePlan" in source,
        "AI recommendation card must apply the executable recommendation plan.",
    )
    require(
        "structuredRecommendationSelection(" in source,
        "AI recommendations must be converted from a structured, quality-controlled plan.",
    )
    require(
        "startPracticeSession(with: plan.items, sourceTitle: plan.title)" in source,
        "Applying an AI recommendation must start exactly the validated plan without silently changing its size.",
    )
    require(
        "buildPracticeSessionItems(from: plan.items)" not in source,
        "A validated AI plan must not be refilled to the generic session limit.",
    )
    require(
        "selectedPracticeSetId = nil" in source,
        "AI recommendation plans should not depend on a static catalog set id.",
    )
    require(
        "recommendedPracticeSet:" not in source,
        "The AI recommendation UI should no longer pass around a loose static practice set.",
    )

    print("Round 1 AI practice recommendation flow validation passed.")


if __name__ == "__main__":
    main()
