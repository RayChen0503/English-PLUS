from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(text: str, marker: str, label: str) -> None:
    if marker not in text:
        raise AssertionError(f"Missing {label}: {marker}")


def forbid(text: str, marker: str, label: str) -> None:
    if marker in text:
        raise AssertionError(f"Forbidden {label}: {marker}")


def main() -> int:
    models = read("ios/EnglishPlus/EnglishPlus/Models/LearningModels.swift")
    mock_repo = read("ios/EnglishPlus/EnglishPlus/Services/MockLearningRepository.swift")
    firebase_repo = read("ios/EnglishPlus/EnglishPlus/Services/FirebaseLearningRepository.swift")

    for marker in [
        "static func normalizedForToday(",
        "todayKey: String",
        "currentMission: DailyMission?",
        "missionAttempts: [MissionAttempt]",
        "stage: .needsCheckIn",
        "continuation: continuation(",
        "currentMission.dateKey != todayKey",
    ]:
        require(models, marker, "shared daily learning-flow normalization")

    for marker in [
        "LearningFlowState.normalizedForToday(",
        "todayKey: Self.dateKey(from: now())",
    ]:
        require(mock_repo, marker, "mock repository daily rollover")

    for marker in [
        "normalizeCurrentSnapshotForToday()",
        "private func normalizeCurrentSnapshotForToday()",
        "preservingSupportRequests",
        "LearningFlowState.normalizedForToday(",
        "currentSnapshot.learningFlow.stage == .needsCheckIn",
        "func continueLearningFlow()",
        "func enterFreePracticeMode()",
        "func returnToMissionFlow()",
    ]:
        require(firebase_repo, marker, "Firebase repository daily rollover")

    for marker in [
        "fallback.continueLearningFlow()",
        "fallback.enterFreePracticeMode()",
        "fallback.returnToMissionFlow()",
    ]:
        forbid(firebase_repo, marker, "Firebase flow should not overwrite remote snapshot with fallback flow")

    print("iOS learning flow round 3 daily rollover contract passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
