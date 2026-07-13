#!/usr/bin/env python3
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
IOS_ROOT = ROOT / "ios" / "EnglishPlus" / "EnglishPlus"
DOC_ROOT = ROOT / "docs" / "ios-parity"

LEARNING_MODELS = IOS_ROOT / "Models" / "LearningModels.swift"
MOCK_REPOSITORY = IOS_ROOT / "Services" / "MockLearningRepository.swift"
LEARNING_STORE = IOS_ROOT / "Services" / "LearningRepositoryStore.swift"
FIREBASE_REPOSITORY = IOS_ROOT / "Services" / "FirebaseLearningRepository.swift"
DOC = DOC_ROOT / "round-5-local-persistence-sync-boundary.md"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def fail(errors: list[str], message: str) -> None:
    errors.append(message)


def require_markers(errors: list[str], label: str, text: str, markers: list[str]) -> None:
    for marker in markers:
        if marker not in text:
            fail(errors, f"{label} missing marker: {marker}")


def validate_models(errors: list[str]) -> None:
    text = read_text(LEARNING_MODELS)
    require_markers(
        errors,
        "LearningModels",
        text,
        [
            "struct LocalLearningSnapshot",
            "Codable",
            "MoodCheckIn: Identifiable, Codable",
            "DailyMission: Identifiable, Codable",
            "MissionAttempt: Identifiable, Codable",
            "StudentSupportRequest: Identifiable, Codable",
            "SupportReply: Identifiable, Codable",
            "repositorySnapshot",
            "savedAt",
        ],
    )


def validate_repository_persistence(errors: list[str]) -> None:
    text = read_text(MOCK_REPOSITORY)
    require_markers(
        errors,
        "MockLearningRepository",
        text,
        [
            "protocol LocalLearningPersistence",
            "struct UserDefaultsLearningPersistence",
            "englishplus.learning.snapshot.v1",
            "JSONEncoder",
            "JSONDecoder",
            "loadSnapshot()",
            "saveSnapshot(_ snapshot: LocalLearningSnapshot)",
            "persistSnapshot()",
            "localPersistence",
            "LocalLearningSnapshot(snapshot: snapshot)",
        ],
    )

    required_persist_calls = [
        "missionAttempts = []\n        persistSnapshot()",
        "supportRequests.insert(request, at: 0)\n        persistSnapshot()",
        "supportRequests[index].updatedAt = date\n        persistSnapshot()",
        "missionAttempts.append(attempt)",
    ]
    require_markers(errors, "MockLearningRepository mutation persistence", text, required_persist_calls)
    if text.count("persistSnapshot()") < 4:
        fail(errors, "MockLearningRepository should persist after all state-changing paths")


def validate_sync_boundary(errors: list[str]) -> None:
    store = read_text(LEARNING_STORE)
    firebase = read_text(FIREBASE_REPOSITORY)
    require_markers(
        errors,
        "LearningRepositoryStore",
        store,
        [
            "LearningRepositorySnapshot",
            "LearningRepositoryBackend",
            "startRealtimeSync",
            "apply(backend.snapshot)",
        ],
    )
    require_markers(
        errors,
        "FirebaseLearningRepository",
        firebase,
        [
            "fallback: MockLearningRepository",
            "currentSnapshot = fallback.snapshot",
            "mirrorCheckInAndMissionIfPossible",
            "mirrorAttemptIfPossible",
            "persistNewSupportRequest",
            "persistSupportReply",
        ],
    )


def validate_docs(errors: list[str]) -> None:
    if not DOC.exists():
        fail(errors, "missing round 5 persistence document")
        return
    require_markers(
        errors,
        "round 5 document",
        read_text(DOC),
        [
            "Round 5",
            "local persistence",
            "UserDefaults",
            "Firestore-ready",
            "check-in",
            "daily mission",
            "mission attempts",
            "support requests",
        ],
    )


def main() -> int:
    errors: list[str] = []
    for path in [LEARNING_MODELS, MOCK_REPOSITORY, LEARNING_STORE, FIREBASE_REPOSITORY]:
        if not path.exists():
            fail(errors, f"missing file: {path.relative_to(ROOT)}")
    if not errors:
        validate_models(errors)
        validate_repository_persistence(errors)
        validate_sync_boundary(errors)
        validate_docs(errors)

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print("iOS parity round 5 persistence validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
