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
    files = {
        "learning_store": SERVICES / "LearningRepositoryStore.swift",
        "mock_learning": SERVICES / "MockLearningRepository.swift",
        "firebase_learning": SERVICES / "FirebaseLearningRepository.swift",
        "student_home": FEATURES / "Student" / "StudentHomeView.swift",
        "support": FEATURES / "Support" / "SupportView.swift",
        "teacher": FEATURES / "Teacher" / "TeacherHomeView.swift",
        "volunteer": FEATURES / "Volunteer" / "VolunteerHomeView.swift",
        "factory": SERVICES / "FirebaseAppConfigurator.swift",
        "remote_ai": SERVICES / "RemoteAIService.swift",
        "info": IOS_ROOT / "Info.plist",
    }

    for name, path in files.items():
        require(path.exists(), f"missing {name}: {path.relative_to(ROOT)}", errors)

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    texts = {name: read(path) for name, path in files.items()}

    require(
        "aiMission: AiMissionOutput?" in texts["learning_store"],
        "LearningRepositoryStore must let daily mission generation consume an AI mission plan",
        errors,
    )
    require(
        "aiMission?.recommendedMinutes" in texts["mock_learning"]
        and "aiMission?.targetCorrectCount" in texts["mock_learning"]
        and "missionTrack(from: aiMission?.track)" in texts["mock_learning"],
        "MockLearningRepository must apply AI mission minutes, target count, and track",
        errors,
    )
    require(
        "questionTypes(from: aiMission?.questionPlan)" in texts["mock_learning"],
        "MockLearningRepository must translate AI question plan into selectable question types",
        errors,
    )
    require(
        "aiMission: aiMission" in texts["firebase_learning"],
        "FirebaseLearningRepository must forward AI mission plans to the fallback generator before mirroring",
        errors,
    )
    require(
        "generateDailyMissionWithAI" in texts["student_home"]
        and "aiResponse.output.mission" in texts["student_home"]
        and "isGeneratingMissionWithAI" in texts["student_home"],
        "StudentHomeView must call real/fallback AI before creating the daily mission",
        errors,
    )
    require(
        "explainWrongAnswerWithAI" in texts["student_home"]
        and "latestWrongAnswerAIResponse" in texts["student_home"]
        and "AIExplanationCard" in texts["student_home"],
        "StudentHomeView must call AI for wrong-answer explanation and render the result",
        errors,
    )
    require(
        "provideEmotionalSupportWithAI" not in texts["support"]
        and "SupportAIResponseCard" not in texts["support"]
        and "SupportRequestInboxCard" in texts["support"],
        "SupportView must stay a focused human-reply inbox; question AI belongs inline in practice",
        errors,
    )
    require(
        "draftTeacherFeedbackWithAI" in texts["teacher"]
        and "fillTeacherDraftWithAI" in texts["teacher"],
        "Teacher request cards must provide AI-assisted feedback drafts",
        errors,
    )
    require(
        "coachVolunteerReplyWithAI" in texts["volunteer"]
        and "fillVolunteerDraftWithAI" in texts["volunteer"],
        "Volunteer task cards must provide AI-assisted reply coaching",
        errors,
    )
    require(
        "RemoteAIService(" in texts["factory"]
        and "CloudflareWorkerAiProxyTransport(" in texts["factory"]
        and "idTokenProvider: authService.currentIdToken" in texts["factory"],
        "Service factory must wire RemoteAIService through Cloudflare Worker transport with Firebase ID token provider",
        errors,
    )
    require(
        "ENGLISHPLUS_AI_PROXY_URL" in texts["info"]
        and "englishplus-ai-proxy.englishplus-ray.workers.dev/ai" in texts["info"],
        "Info.plist must point the app at the live Cloudflare Worker AI proxy endpoint",
        errors,
    )
    for forbidden in ["GROQ_API_KEY", "https://api.groq.com", "gsk_", "https://openrouter.ai", "OPENROUTER_API_KEY"]:
        require(forbidden not in "\n".join(texts.values()), f"iOS runtime files must not expose {forbidden}", errors)

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print("Round 4 AI runtime usage validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
