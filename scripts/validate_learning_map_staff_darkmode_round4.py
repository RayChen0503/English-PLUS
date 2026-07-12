from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

FILES = {
    "theme": ROOT / "ios" / "EnglishPlus" / "EnglishPlus" / "Core" / "EPTheme.swift",
    "models": ROOT / "ios" / "EnglishPlus" / "EnglishPlus" / "Models" / "LearningModels.swift",
    "store": ROOT / "ios" / "EnglishPlus" / "EnglishPlus" / "Services" / "LearningRepositoryStore.swift",
    "mock_repo": ROOT / "ios" / "EnglishPlus" / "EnglishPlus" / "Services" / "MockLearningRepository.swift",
    "map": ROOT / "ios" / "EnglishPlus" / "EnglishPlus" / "Features" / "Student" / "StudentLearningMapView.swift",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def main() -> None:
    for label, path in FILES.items():
        require(path.exists(), f"Missing {label}: {path}")

    theme = read(FILES["theme"])
    models = read(FILES["models"])
    store = read(FILES["store"])
    mock_repo = read(FILES["mock_repo"])
    learning_map = read(FILES["map"])

    for token in [
        "UIColor",
        "userInterfaceStyle == .dark",
        "static let card",
        "static let secondarySurface",
        "static let secondaryInk",
    ]:
        require(token in theme, f"Theme must support real light/dark color token: {token}")

    app_sources = "\n".join(
        path.read_text(encoding="utf-8")
        for path in (ROOT / "ios" / "EnglishPlus" / "EnglishPlus").rglob("*.swift")
    )
    require(
        ".preferredColorScheme(.light)" not in app_sources,
        "Round 4 requires real dark mode, not forcing light mode.",
    )
    require(
        ".background(.white)" not in app_sources,
        "Fixed white card backgrounds break dark mode readability.",
    )
    require(
        "Color(.systemGray6)" not in app_sources,
        "System gray surfaces must use the app theme so light/dark contrast stays controlled.",
    )

    require(
        "hasCompleteQuestionSnapshotForStaff" in models
        and "requiresStaffTeachingResponse" in models,
        "Support requests must expose whether they contain a complete question snapshot for staff.",
    )
    require(
        ".filter { $0.isVisibleInStaffQueue(for: .teacher) }" in store
        and ".filter { $0.isVisibleInStaffQueue(for: .volunteer) }" in store,
        "Role queues must use the shared visibility helper that rejects incomplete snapshots.",
    )

    for token in [
        "allLearningMapNodesCompleted",
        "todayCompleteCard",
        "learningMapNodes.allSatisfy",
        "今天的任務完成了",
    ]:
        require(token in learning_map, f"Learning map must show a clear all-done state: {token}")

    print("Round 4 learning-map, staff-queue, and dark-mode validation passed.")


if __name__ == "__main__":
    main()
