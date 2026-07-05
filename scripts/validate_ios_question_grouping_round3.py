#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(text: str, marker: str, label: str) -> None:
    if marker not in text:
        raise AssertionError(f"Missing {label}: {marker}")


def reject(text: str, marker: str, label: str) -> None:
    if marker in text:
        raise AssertionError(f"Unexpected {label}: {marker}")


def main() -> int:
    question_model = read("ios/EnglishPlus/EnglishPlus/Models/Question.swift")
    practice = read("ios/EnglishPlus/EnglishPlus/Features/Practice/PracticeCenterView.swift")
    student_home = read("ios/EnglishPlus/EnglishPlus/Features/Student/StudentHomeView.swift")
    support_snapshot = read("ios/EnglishPlus/EnglishPlus/Features/Shared/SupportQuestionSnapshotCard.swift")
    mock_repository = read("ios/EnglishPlus/EnglishPlus/Services/MockLearningRepository.swift")
    app_sources = "\n".join(
        path.read_text(encoding="utf-8")
        for path in (ROOT / "ios" / "EnglishPlus" / "EnglishPlus").rglob("*.swift")
    )

    for marker in [
        "enum QuestionGroupingEngine",
        "static func balancedItems(",
        "static func balancedOptions(",
        "static func practiceSelection(",
        "answerSlot(",
        "recentAnswerPenalty",
        "recentSkillPenalty",
        "recentSlotPenalty",
        "fallbackUsed",
    ]:
        require(question_model, marker, "shared question grouping engine")

    reject(
        question_model,
        ".sorted { $0.id < $1.id }\n                .chunked",
        "id-only practice set chunking",
    )

    for marker in [
        "QuestionGroupingEngine.balancedItems(",
        "QuestionGroupingEngine.practiceSelection(",
        "QuestionGroupingEngine.balancedOptions(",
        "QuestionGroupingEngine.balancedFallbackCandidates(",
        "sessionItems.enumerated().map",
        "uniquingKeysWith",
        "selection.fallbackUsed",
    ]:
        require(practice, marker, "practice center balanced grouping")

    reject(
        practice,
        "practiceOptionOrderByQuestionId = Dictionary(\n            uniqueKeysWithValues:",
        "unsafe practice option dictionary creation",
    )
    reject(
        practice,
        "ForEach(shuffledAnswerOptions(for: item), id: \\.self)",
        "practice option ForEach keyed by answer text",
    )

    for marker in [
        "QuestionGroupingEngine.balancedOptions(",
        "missionOptionOrder(",
        "missionQuestionIndex(",
        "Array(missionOptionOrder(for: item).enumerated())",
    ]:
        require(student_home, marker, "student mission balanced option order")

    reject(
        student_home,
        "ForEach(item.question.options, id: \\.self)",
        "raw mission option ordering",
    )
    reject(
        student_home,
        "ForEach(missionOptionOrder(for: item), id: \\.self)",
        "mission option ForEach keyed by answer text",
    )

    require(
        support_snapshot,
        "Array(snapshot.options.enumerated())",
        "support question snapshot option identity",
    )
    reject(
        support_snapshot,
        "ForEach(snapshot.options, id: \\.self)",
        "support snapshot option ForEach keyed by answer text",
    )

    reject(
        app_sources,
        "Dictionary(uniqueKeysWithValues:",
        "runtime-trapping dictionary construction",
    )

    for marker in [
        "QuestionGroupingEngine.balancedItems(",
        "QuestionGroupingEngine.balancedFallbackCandidates(",
        "fallbackUsed",
    ]:
        require(mock_repository, marker, "daily mission balanced selection")

    print("iOS question grouping round 3 contract passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
