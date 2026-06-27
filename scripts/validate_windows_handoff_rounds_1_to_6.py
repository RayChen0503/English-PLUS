#!/usr/bin/env python3
import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
IOS_ROOT = ROOT / "ios" / "EnglishPlus" / "EnglishPlus"
SEED_DIR = IOS_ROOT / "Resources" / "SeedData"


REQUIRED_DIRS = [
    IOS_ROOT / "App",
    IOS_ROOT / "Core",
    IOS_ROOT / "Models",
    IOS_ROOT / "Services",
    IOS_ROOT / "Data",
    IOS_ROOT / "Features" / "RoleSelection",
    IOS_ROOT / "Features" / "Student",
    IOS_ROOT / "Features" / "Teacher",
    IOS_ROOT / "Features" / "Volunteer",
    IOS_ROOT / "Features" / "Practice",
    IOS_ROOT / "Features" / "Support",
    IOS_ROOT / "Features" / "Consent",
]

FILES = {
    "project": ROOT / "ios" / "EnglishPlus" / "EnglishPlus.xcodeproj" / "project.pbxproj",
    "info": IOS_ROOT / "Info.plist",
    "role": IOS_ROOT / "Features" / "RoleSelection" / "RoleSelectionView.swift",
    "student": IOS_ROOT / "Features" / "Student" / "StudentHomeView.swift",
    "practice": IOS_ROOT / "Features" / "Practice" / "PracticeCenterView.swift",
    "support": IOS_ROOT / "Features" / "Support" / "SupportView.swift",
    "teacher": IOS_ROOT / "Features" / "Teacher" / "TeacherHomeView.swift",
    "teacher_shell": IOS_ROOT / "Features" / "Teacher" / "TeacherShellView.swift",
    "volunteer": IOS_ROOT / "Features" / "Volunteer" / "VolunteerHomeView.swift",
    "volunteer_shell": IOS_ROOT / "Features" / "Volunteer" / "VolunteerShellView.swift",
    "learning_models": IOS_ROOT / "Models" / "LearningModels.swift",
    "learning_repo": IOS_ROOT / "Services" / "MockLearningRepository.swift",
    "auth": IOS_ROOT / "Services" / "AuthService.swift",
    "firestore": IOS_ROOT / "Services" / "FirestoreService.swift",
    "consent": IOS_ROOT / "Features" / "Consent" / "ConsentView.swift",
    "privacy": IOS_ROOT / "Models" / "PrivacyConsent.swift",
    "firestore_schema": IOS_ROOT / "Models" / "FirestoreSchema.swift",
    "firestore_path": IOS_ROOT / "Data" / "FirestorePath.swift",
    "rules": ROOT / "docs" / "ios-testflight" / "firebase" / "firestore.rules.draft",
}

REQUIRED_TYPES = {
    "vocabulary",
    "grammar",
    "fillBlank",
    "cloze",
    "reading",
    "translation",
    "dialogue",
}


def read(path):
    return path.read_text(encoding="utf-8")


def require(condition, message, errors):
    if not condition:
        errors.append(message)


def validate_round_1_and_2(errors):
    require((ROOT / "app" / "src").exists(), "Android app/src must remain in the repository", errors)
    require(FILES["project"].exists(), "Xcode project must exist under ios/EnglishPlus", errors)
    for required_dir in REQUIRED_DIRS:
        require(required_dir.exists(), f"missing iOS folder {required_dir.relative_to(ROOT)}", errors)

    project = read(FILES["project"])
    info = read(FILES["info"])
    require("PRODUCT_BUNDLE_IDENTIFIER = com.englishplus;" in project, "Bundle ID must be com.englishplus", errors)
    require("<string>English+</string>" in info, "Display name must be English+", errors)


def validate_round_3_student_flow(errors):
    student = read(FILES["student"])
    learning_repo = read(FILES["learning_repo"])

    for token in [
        "ScaleSelector",
        "ChallengeSelector",
        "QuestionTypePicker",
        "generateMission(",
        "ProgressView(value:",
        "submitMissionAnswer",
        "FeedbackCard",
        "CompletionCard",
        "freePracticeCard",
    ]:
        require(token in student, f"student flow missing {token}", errors)

    require('Button("??敹?瑼Ｘ葫") { }' not in student, "student check-in button must not be empty", errors)
    for token in [
        "uniqueCorrectQuestionIds",
        "nextMissionQuestion",
        "targetCorrectCount",
        "missionAttempts.append",
        "mission.completedAt",
    ]:
        require(token in learning_repo, f"mission repository missing {token}", errors)


def validate_round_4_staff_support(errors):
    support = read(FILES["support"])
    teacher = read(FILES["teacher"])
    teacher_shell = read(FILES["teacher_shell"])
    volunteer = read(FILES["volunteer"])
    volunteer_shell = read(FILES["volunteer_shell"])
    models = read(FILES["learning_models"])
    repo = read(FILES["learning_repo"])

    for token in ["sendSupportRequest", "StudentRequestCard", "supportRequests(forStudentUid:"]:
        require(token in support, f"support flow missing {token}", errors)
    for token in ["TeacherStatusStrip", "TeacherRequestCard", "TeacherClassSummary", "addTeacherReply", "teacherQueue"]:
        require(token in teacher, f"teacher workbench missing {token}", errors)
    for token in ["TeacherStudentsView", "TeacherHandoffView", "TeacherReportView", "TeacherQuestionBankView"]:
        require(token in teacher_shell, f"teacher shell missing {token}", errors)
    for token in [
        "VolunteerTaskCard",
        "VolunteerHandoffView",
        "VolunteerStudentBriefsView",
        "VolunteerSyncView",
        "VolunteerScriptView",
        "addVolunteerReply",
        "volunteerQueue",
    ]:
        require(token in volunteer + volunteer_shell, f"volunteer flow missing {token}", errors)
    for token in ["StudentSupportRequest", "SupportReply", "StaffStudentSummary"]:
        require(token in models, f"shared support model missing {token}", errors)
    for token in ["teacherQueue", "volunteerQueue", "supportRequests", "replies.append"]:
        require(token in repo, f"shared support repository missing {token}", errors)


def validate_round_5_seed_and_repository(errors):
    question_bank = json.loads((SEED_DIR / "question_bank_seed.json").read_text(encoding="utf-8"))
    items = question_bank.get("items", [])
    approved = [item for item in items if item.get("reviewState") == "approved"]
    types = {item.get("question", {}).get("type") for item in approved}
    levels = {item.get("level") for item in approved}
    ids = [item.get("id") for item in approved]
    repo = read(FILES["learning_repo"])
    models = read(FILES["learning_models"])

    require(REQUIRED_TYPES.issubset(types), "question bank must cover all Windows handoff question types", errors)
    require(len(levels) >= 3, "question bank must cover multiple difficulty levels", errors)
    require(len(ids) == len(set(ids)), "question bank item IDs must be unique", errors)
    for token in ["selectMissionQuestions", "uniqued(by:", "preferredTypes", "MissionAttempt", "StudentProgressSnapshot"]:
        require(token in repo + models, f"local data layer missing {token}", errors)


def validate_round_6_firebase_privacy(errors):
    combined = "\n".join(read(path) for path in [
        FILES["auth"],
        FILES["firestore"],
        FILES["consent"],
        FILES["privacy"],
        FILES["firestore_schema"],
        FILES["firestore_path"],
        FILES["rules"],
    ])

    for token in [
        "AuthSession",
        "protocol FirestoreService",
        "GoogleService-Info.plist",
        "PrivacyConsentRecord",
        "acceptsPrivacy",
        "acceptsMoodAndAi",
        "FirestoreConsentDocument",
        "FirestoreDeletionRequestDocument",
        "FirestorePrivacyAuditLogDocument",
        "match /consents/{consentVersion}",
    ]:
        require(token in combined, f"round 6 Firebase/privacy contract missing {token}", errors)


def main():
    errors = []
    for name, path in FILES.items():
        require(path.exists(), f"missing {name}: {path.relative_to(ROOT)}", errors)

    if not errors:
        validate_round_1_and_2(errors)
        validate_round_3_student_flow(errors)
        validate_round_4_staff_support(errors)
        validate_round_5_seed_and_repository(errors)
        validate_round_6_firebase_privacy(errors)

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print("Windows handoff rounds 1-6 validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
