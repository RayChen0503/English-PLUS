#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise SystemExit(f"Missing {label}: {needle}")


def main() -> None:
    models = read("ios/EnglishPlus/EnglishPlus/Models/LearningModels.swift")
    schema = read("ios/EnglishPlus/EnglishPlus/Models/FirestoreSchema.swift")
    store = read("ios/EnglishPlus/EnglishPlus/Services/LearningRepositoryStore.swift")
    store += read("ios/EnglishPlus/EnglishPlus/Services/LearningRepositoryStore+Reporting.swift")
    mock = read("ios/EnglishPlus/EnglishPlus/Services/MockLearningRepository.swift")
    firebase = read("ios/EnglishPlus/EnglishPlus/Services/FirebaseLearningRepository.swift")

    require(schema, "case staffHandledNoReply", "staff handled without reply status")
    require(schema, "case archived", "archived support status")
    require(models, "var studentArchivedAt: Date?", "student archive timestamp")
    require(models, "var staffArchivedAt: Date?", "staff archive timestamp")
    require(models, "var handledWithoutReplyAt: Date?", "handled without reply timestamp")
    require(models, "var studentLastReadAt: Date?", "student last read timestamp")
    require(models, "var isVisibleToStudent: Bool", "student visibility helper")
    require(models, "var isWaitingForStaffAction: Bool", "staff waiting helper")
    require(models, "var countsTowardStaffBadge: Bool", "staff badge helper")

    require(store, "func archiveSupportThreadForStudent(_ requestId: String)", "student archive store method")
    require(store, "func markSupportThreadHandledWithoutReply(_ requestId: String, by staffUser: DemoUser?)", "staff no-reply store method")
    require(store, "func archiveSupportThreadForStaff(_ requestId: String, by staffUser: DemoUser?)", "staff archive store method")
    require(store, ".filter(\\.isVisibleToStudent)", "student support list hides archived threads")
    require(store, ".filter { $0.isVisibleInStaffQueue(for: .teacher) }", "teacher queue uses role visibility helper")
    require(store, "countsTowardSharedStaffBadge(for: .teacher)", "staff metrics uses role-aware badge helper")

    require(mock, "func archiveSupportThreadForStudent(_ requestId: String)", "mock student archive")
    require(mock, "func markSupportThreadHandledWithoutReply(_ requestId: String, by staffUser: DemoUser?)", "mock staff no-reply")
    require(mock, "func archiveSupportThreadForStaff(_ requestId: String, by staffUser: DemoUser?)", "mock staff archive")

    require(firebase, "func archiveSupportThreadForStudent(_ requestId: String)", "firebase student archive")
    require(firebase, "func markSupportThreadHandledWithoutReply(_ requestId: String, by staffUser: DemoUser?)", "firebase staff no-reply")
    require(firebase, "func archiveSupportThreadForStaff(_ requestId: String, by staffUser: DemoUser?)", "firebase staff archive")
    require(firebase, '"studentArchivedAt"', "firebase student archive field")
    require(firebase, '"staffArchivedAt"', "firebase staff archive field")
    require(firebase, '"handledWithoutReplyAt"', "firebase no-reply field")
    require(firebase, '"studentLastReadAt"', "firebase student read field")

    print("support lifecycle round 1 contract passed")


if __name__ == "__main__":
    main()
