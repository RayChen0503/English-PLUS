#!/usr/bin/env python3
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
IOS_ROOT = ROOT / "ios" / "EnglishPlus" / "EnglishPlus"
SERVICES = IOS_ROOT / "Services"
FEATURES = IOS_ROOT / "Features"


def read(path):
    return path.read_text(encoding="utf-8")


def require(condition, message, errors):
    if not condition:
        errors.append(message)


def main():
    errors = []
    firebase_repo = SERVICES / "FirebaseLearningRepository.swift"
    learning_store = SERVICES / "LearningRepositoryStore.swift"
    mock_repo = SERVICES / "MockLearningRepository.swift"
    support_view = FEATURES / "Support" / "SupportView.swift"
    teacher_view = FEATURES / "Teacher" / "TeacherHomeView.swift"
    volunteer_view = FEATURES / "Volunteer" / "VolunteerHomeView.swift"

    for path in [firebase_repo, learning_store, mock_repo, support_view, teacher_view, volunteer_view]:
        require(path.exists(), f"missing {path.relative_to(ROOT)}", errors)

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    firebase_text = read(firebase_repo)
    store_text = read(learning_store)
    mock_text = read(mock_repo)
    support_text = read(support_view)
    teacher_text = read(teacher_view)
    volunteer_text = read(volunteer_view)

    require(
        "mirrorStudentSupportMessageIfPossible" in firebase_text,
        "FirebaseLearningRepository must mirror the original student request as the first support message",
        errors,
    )
    require(
        "SupportMessageType.studentRequest.rawValue" in firebase_text,
        "Student support message must be written with messageType=studentRequest",
        errors,
    )
    require(
        "visibleToStudent" in firebase_text and "visibility" in firebase_text,
        "Support messages must preserve student-visible visibility metadata",
        errors,
    )
    require(
        "latestMessagePreview" in firebase_text and "request.replies.last?.body ?? request.studentMessage" in firebase_text,
        "Support thread documents must keep a latestMessagePreview for staff/student lists",
        errors,
    )
    require(
        "func markSupportThreadReadByStudent(_ requestId: String)" in store_text,
        "LearningRepositoryStore must expose markSupportThreadReadByStudent",
        errors,
    )
    require(
        "func markSupportThreadReadByStudent(_ requestId: String)" in mock_text,
        "MockLearningRepository must implement markSupportThreadReadByStudent for local parity",
        errors,
    )
    require(
        "func markSupportThreadReadByStudent(_ requestId: String)" in firebase_text,
        "FirebaseLearningRepository must mirror read-by-student status",
        errors,
    )
    require(
        ".onAppear" in support_text and "markSupportThreadReadByStudent" in support_text,
        "Student support cards must mark replied support threads as read when viewed",
        errors,
    )
    require(
        "learningRepository.supportRequests(forStudentUid: appState.currentUser?.id)" in support_text,
        "Student support view must render support requests belonging to the current signed-in student",
        errors,
    )
    require(
        "learningRepository.addTeacherReply(to: request.id, body: replyDraft)" in teacher_text,
        "Teacher UI must write replies through LearningRepositoryStore",
        errors,
    )
    require(
        "learningRepository.addVolunteerReply(to: request.id, body: replyDraft)" in volunteer_text,
        "Volunteer UI must write replies through LearningRepositoryStore",
        errors,
    )

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print("Round 3 support thread interaction validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
