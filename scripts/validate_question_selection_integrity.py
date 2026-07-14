#!/usr/bin/env python3
import json
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8-sig")


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def main() -> int:
    errors: list[str] = []
    model = read("ios/EnglishPlus/EnglishPlus/Models/Question.swift")
    practice = read("ios/EnglishPlus/EnglishPlus/Features/Practice/PracticeCenterView.swift")
    repository = read("ios/EnglishPlus/EnglishPlus/Services/MockLearningRepository.swift")
    tests = read("ios/EnglishPlus/EnglishPlusTests/AuthenticationFlowAcceptanceTests.swift")
    worker = read("workers/englishplus-ai-proxy/src/index.js")
    worker_tests = read("workers/englishplus-ai-proxy/test/ai-actions.test.js")
    seed = json.loads(read(
        "ios/EnglishPlus/EnglishPlus/Resources/SeedData/question_bank_seed.json"
    ))

    require("static func strictSelection(" in model, "Strict question selection API is missing", errors)
    for marker in (
        "QuestionGroupingEngine.strictSelection(",
        "manualSelectionSummary",
        "selectedSetTitle: manualSelectionSummary",
        "sourceTitle: manualSelectionSummary",
        "selectedPracticeSetId = nil",
    ):
        require(marker in practice, f"Manual-practice integrity marker missing: {marker}", errors)
    require("fallbackPracticeCandidates" not in practice, "Manual practice still has a relaxed fallback", errors)

    for marker in (
        "let minutes = recommendedMinutes(for: normalizedTimeLevel)",
        "let targetCorrectCount = questionGoal(for: minutes)",
        "missionTrack(moodScore: moodScore, wantsChallenge: wantsChallenge)",
        "preferredLevels: missionLevels",
        "preferredSet.contains($0.question.type)",
        "from: exactSetItems",
    ):
        require(marker in repository, f"Mission/assignment constraint missing: {marker}", errors)
    for obsolete in (
        "aiMission?.recommendedMinutes",
        "aiMission?.targetCorrectCount",
        "missionTrack(from: aiMission?.track)",
        "sameTypeLevelMatches",
    ):
        require(obsolete not in repository, f"Obsolete relaxed selection remains: {obsolete}", errors)

    for marker in (
        "SelectionConstraintAcceptanceTests",
        "testStrictManualSelectionNeverFillsFromAnotherTypeOrLevel",
        "testStrictManualSelectionMatrixPreservesEveryTypeAndLevelCombination",
        "testDailyMissionRejectsConflictingAITypeAndUsesCheckInDifficulty",
        "testDailyMissionTranslationPreferenceSurvivesAIAndTimeChangesQuantity",
        "testDailyMissionConstraintMatrixCoversEveryTypeMoodTimeAndChallengeCombination",
        "testTeacherAssignmentContainsExactlyTheSelectedPracticeSet",
        "testEveryTeacherPracticeSetPreservesItsExactQuestionIDsAndMetadata",
    ):
        require(marker in tests, f"Selection acceptance coverage missing: {marker}", errors)

    for marker in (
        "Treat moodScore, availableTimeLevel, wantsChallenge, and preferredQuestionTypes as hard constraints.",
        "function dailyMissionPolicy(context = {})",
        "mission: normalizeMission({}, request.context)",
        'preferredQuestionTypes: ["translation"]',
    ):
        require(
            marker in worker or marker in worker_tests,
            f"Worker constraint coverage missing: {marker}",
            errors,
        )

    approved = [item for item in seed["items"] if item["reviewState"] == "approved"]
    matrix = Counter((item["question"]["type"], item["level"]) for item in approved)
    require(matrix[("translation", "A1")] == 0, "Seed assumptions changed: translation A1 now exists", errors)
    require(matrix[("translation", "A2")] > 0, "Translation A2 should be selectable", errors)
    require(matrix[("translation", "B1")] > 0, "Translation B1 should be selectable", errors)
    require(matrix[("translation", "B2")] > 0, "Translation B2 should be selectable", errors)

    if errors:
        print("Question selection integrity validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("Question selection integrity validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
