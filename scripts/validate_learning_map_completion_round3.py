from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

FILES = {
    "models": ROOT / "ios" / "EnglishPlus" / "EnglishPlus" / "Models" / "LearningModels.swift",
    "store": ROOT / "ios" / "EnglishPlus" / "EnglishPlus" / "Services" / "LearningRepositoryStore.swift",
    "mock_repo": ROOT / "ios" / "EnglishPlus" / "EnglishPlus" / "Services" / "MockLearningRepository.swift",
    "firebase_repo": ROOT / "ios" / "EnglishPlus" / "EnglishPlus" / "Services" / "FirebaseLearningRepository.swift",
    "practice": ROOT / "ios" / "EnglishPlus" / "EnglishPlus" / "Features" / "Practice" / "PracticeCenterView.swift",
    "map": ROOT / "ios" / "EnglishPlus" / "EnglishPlus" / "Features" / "Student" / "StudentLearningMapView.swift",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def read(name: str) -> str:
    return FILES[name].read_text(encoding="utf-8")


def main() -> None:
    for label, path in FILES.items():
        require(path.exists(), f"Missing {label}: {path}")

    models = read("models")
    store = read("store")
    mock_repo = read("mock_repo")
    firebase_repo = read("firebase_repo")
    practice = read("practice")
    learning_map = read("map")

    for token in [
        "completedFreePracticeSessionCount",
        "lastFreePracticeCompletedAt",
        "hasCompletedFreePracticeSession",
        "recordingFreePracticeSessionCompleted",
        "isPendingOnStudentLearningMap",
    ]:
        require(token in models, f"Learning models must expose third-round map completion token: {token}")

    for source_name, source in [
        ("store", store),
        ("mock repo", mock_repo),
        ("firebase repo", firebase_repo),
    ]:
        require(
            "completeFreePracticeSession(correctCount: Int, totalCount: Int)" in source,
            f"{source_name} must support recording completed free-practice sessions.",
        )

    require(
        "learningRepository.completeFreePracticeSession(" in practice,
        "Practice completion must write back to the learning repository.",
    )
    require(
        "correctCount: freePracticeCorrectCount" in practice
        and "totalCount: freePracticeSessionItems.count" in practice,
        "Practice completion must record both correct count and session size.",
    )

    for token in [
        "hasCompletedFreePracticeSession",
        "pendingSupportRequests",
        "unreadSupportReplyCount",
        "supportRepliesCleared",
        "freePracticeNodeState",
        "supportReplyNodeState",
    ]:
        require(token in learning_map, f"Learning map must derive visible node state from: {token}")

    require(
        'title: "自由練習"' in learning_map and "state: freePracticeNodeState" in learning_map,
        "Free-practice node must use the recorded completion state.",
    )
    require(
        'title: "支持回覆"' in learning_map and "state: supportReplyNodeState" in learning_map,
        "Support reply node must use pending/read/archive state.",
    )
    require(
        "studentSupportRequests.isEmpty ? .available : .current" not in learning_map,
        "Support reply node must not stay current just because old support history exists.",
    )

    print("Learning map completion round 3 validation passed.")


if __name__ == "__main__":
    main()
