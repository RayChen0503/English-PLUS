from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODELS = ROOT / "ios/EnglishPlus/EnglishPlus/Models/LearningModels.swift"
STORE = ROOT / "ios/EnglishPlus/EnglishPlus/Services/LearningRepositoryStore.swift"
MOCK_REPO = ROOT / "ios/EnglishPlus/EnglishPlus/Services/MockLearningRepository.swift"
FIREBASE_REPO = ROOT / "ios/EnglishPlus/EnglishPlus/Services/FirebaseLearningRepository.swift"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f"Missing {label}: {needle}")


def main() -> None:
    models = read(MODELS)
    store = read(STORE)
    mock_repo = read(MOCK_REPO)
    firebase_repo = read(FIREBASE_REPO)

    require(models, "enum LearningFlowStage", "learning flow stage enum")
    require(models, "struct LearningFlowState", "learning flow state model")
    require(models, "struct LearningContinuation", "continuable previous mission model")
    require(models, "case needsCheckIn", "check-in stage")
    require(models, "case missionActive", "mission active stage")
    require(models, "case missionCompleted", "mission completed stage")
    require(models, "case freePractice", "free practice stage")
    require(models, "let learningFlow: LearningFlowState", "snapshot persistence field")

    require(store, "var learningFlow: LearningFlowState", "published learning flow state")
    require(store, "func startNewLearningRound(", "start-new-round API")
    require(store, "func continueLearningFlow(", "continue previous progress API")
    require(store, "func enterFreePracticeMode(", "free-practice mode API")
    require(store, "func returnToMissionFlow(", "return-to-mission API")

    require(mock_repo, "learningFlow = LearningFlowState", "mock repository state initialization")
    require(mock_repo, "nextRoundNumber(", "same-day round increment")
    require(mock_repo, "-r\\(roundNumber)-", "round-specific mission/check-in ids")
    require(mock_repo, "stage: .missionCompleted", "completion state transition")
    require(mock_repo, "stage: .freePractice", "free-practice transition")
    require(mock_repo, "continuation:", "previous mission continuation")

    require(firebase_repo, "startNewLearningRound(", "Firebase repository start-new-round passthrough")
    require(firebase_repo, "continueLearningFlow(", "Firebase repository continue passthrough")
    require(firebase_repo, "enterFreePracticeMode(", "Firebase repository free-practice passthrough")
    require(firebase_repo, "returnToMissionFlow(", "Firebase repository return passthrough")

    print("iOS learning flow round 1 contract passed")


if __name__ == "__main__":
    main()
