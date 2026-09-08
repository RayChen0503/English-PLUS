from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SWIFT_ROOT = ROOT / "ios" / "EnglishPlus" / "EnglishPlus"


def read(relative_path: str) -> str:
    return (ROOT / relative_path).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> int:
    mapper = read("ios/EnglishPlus/EnglishPlus/Data/FirestoreSeedMapper.swift")
    contracts = read("ios/EnglishPlus/EnglishPlus/Services/LearningRepositoryContracts.swift")
    mock_repository = read("ios/EnglishPlus/EnglishPlus/Services/MockLearningRepository.swift")
    firebase_repository = read("ios/EnglishPlus/EnglishPlus/Services/FirebaseLearningRepository.swift")
    practice_view = read("ios/EnglishPlus/EnglishPlus/Features/Practice/PracticeCenterView.swift")

    require(
        "studentAccessPath: account.role == .student ? .legacyUnspecified : .notApplicable" in mapper,
        "Firestore seed users must include the role-appropriate studentAccessPath.",
    )
    require(
        "func uniqued<ID: Hashable>(by keyPath:" in contracts,
        "The shared key-path uniqueness helper is missing.",
    )
    require(
        "func uniqued() -> [Element]" in contracts,
        "The shared Hashable uniqueness helper is missing.",
    )
    require(
        "func uniqued<ID: Hashable>(by keyPath:" not in mock_repository,
        "MockLearningRepository redeclares the shared key-path uniqueness helper.",
    )
    require(
        "private extension Array where Element: Hashable" not in firebase_repository,
        "FirebaseLearningRepository redeclares the shared Hashable uniqueness helper.",
    )
    require(
        "func uniqued<ID: Hashable>(by keyPath:" not in practice_view,
        "PracticeCenterView redeclares the shared key-path uniqueness helper.",
    )

    shared_key_path_helpers = sum(
        path.read_text(encoding="utf-8").count("func uniqued<ID: Hashable>(by keyPath:")
        for path in SWIFT_ROOT.rglob("*.swift")
    )
    require(
        shared_key_path_helpers == 1,
        f"Expected exactly one shared key-path uniqueness helper, found {shared_key_path_helpers}.",
    )

    print("RELEASE-4 Xcode archive source validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
