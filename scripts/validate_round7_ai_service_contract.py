#!/usr/bin/env python3
import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
IOS_ROOT = ROOT / "ios" / "EnglishPlus" / "EnglishPlus"
SERVICES = IOS_ROOT / "Services"
FUNCTIONS_INDEX = ROOT / "functions" / "src" / "index.ts"
SCHEMA = ROOT / "docs" / "ios-testflight" / "firebase" / "openrouter-ai-proxy.schema.json"

FILES = {
    "ai_models": IOS_ROOT / "Models" / "AiProxyModels.swift",
    "ai_proxy_service": SERVICES / "AiProxyService.swift",
    "mock_ai_proxy": SERVICES / "MockAiProxyService.swift",
    "ai_service": SERVICES / "AIService.swift",
    "mock_ai_service": SERVICES / "MockAIService.swift",
    "remote_ai_service": SERVICES / "RemoteAIService.swift",
    "app_state": IOS_ROOT / "App" / "AppState.swift",
    "app": IOS_ROOT / "App" / "EnglishPlusApp.swift",
    "project": ROOT / "ios" / "EnglishPlus" / "EnglishPlus.xcodeproj" / "project.pbxproj",
}

TASKS = [
    "dailyMission",
    "wrongAnswerExplanation",
    "emotionalSupport",
    "teacherFeedbackDraft",
    "volunteerReplyCoach",
    "progressSummary",
]


def read(path):
    return path.read_text(encoding="utf-8")


def require(condition, message, errors):
    if not condition:
        errors.append(message)


def validate_files(errors):
    for name, path in FILES.items():
        require(path.exists(), f"missing {name}: {path.relative_to(ROOT)}", errors)


def validate_high_level_ios_service(errors):
    ai_service = read(FILES["ai_service"])
    mock = read(FILES["mock_ai_service"])
    remote = read(FILES["remote_ai_service"])
    app_state = read(FILES["app_state"])
    app = read(FILES["app"])
    project = read(FILES["project"])

    for token in [
        "protocol AIService",
        "DailyMissionAIContext",
        "WrongAnswerAIContext",
        "SupportAIContext",
        "PracticeRecommendationAIContext",
        "generateDailyMission",
        "explainWrongAnswer",
        "provideEmotionalSupport",
        "draftTeacherFeedback",
        "coachVolunteerReply",
        "recommendPractice",
    ]:
        require(token in ai_service, f"AIService missing {token}", errors)

    for token in [
        "struct MockAIService",
        "MockAiProxyService",
        ".dailyMission(context:",
        ".wrongAnswerExplanation(context:",
        ".emotionalSupport(context:",
        ".teacherFeedbackDraft(context:",
        ".volunteerReplyCoach(context:",
        ".progressSummary(context:",
    ]:
        require(token in mock, f"MockAIService missing {token}", errors)

    for token in [
        "struct RemoteAIService",
        "protocol AiProxyTransport",
        "FirebaseCallableAiProxyTransport",
        "englishPlusAiProxy",
        "cloudfunctions.net",
        "Authorization",
        "CallableRequestEnvelope",
        "CallableResponseEnvelope",
        "idTokenProvider",
        "fallbackService",
        "timeoutInterval",
        "AI_PROXY_TIMEOUT",
        "AI_PROXY_INVALID_RESPONSE",
    ]:
        require(token in remote, f"RemoteAIService missing {token}", errors)

    for token in [
        "private let aiService: AIService",
        "generateDailyMissionWithAI",
        "explainWrongAnswerWithAI",
        "provideEmotionalSupportWithAI",
        "draftTeacherFeedbackWithAI",
        "coachVolunteerReplyWithAI",
        "recommendPracticeWithAI",
        "latestAIResponse",
    ]:
        require(token in app_state, f"AppState missing {token}", errors)

    require(
        "EnglishPlusServiceFactory.makeServices()" in app,
        "EnglishPlusApp must use EnglishPlusServiceFactory for mock/real AI switching",
        errors,
    )
    for token in ["AIService.swift", "MockAIService.swift", "RemoteAIService.swift"]:
        require(token in project, f"Xcode project missing {token}", errors)


def validate_proxy_task_contract(errors):
    models = read(FILES["ai_models"])
    functions = read(FUNCTIONS_INDEX)
    schema = json.loads(read(SCHEMA))
    task_enum = schema.get("properties", {}).get("taskType", {}).get("enum", [])
    preferred_enum = (
        schema.get("properties", {})
        .get("context", {})
        .get("properties", {})
        .get("preferredQuestionTypes", {})
        .get("items", {})
        .get("enum", [])
    )

    for task in TASKS:
        require(task in models, f"AiProxyModels missing task {task}", errors)
        require(task in functions, f"Cloud Function missing task {task}", errors)
        require(task in task_enum, f"AI proxy schema missing task {task}", errors)

    for question_type in ["multipleChoice", "vocabulary", "grammar", "fillBlank", "cloze", "translation", "reading", "dialogue"]:
        require(question_type in preferred_enum, f"AI proxy schema missing preferred type {question_type}", errors)


def validate_secret_safety(errors):
    ios_text = "\n".join(path.read_text(encoding="utf-8") for path in IOS_ROOT.rglob("*.swift"))
    require("OPENROUTER_API_KEY" not in ios_text, "iOS Swift code must not reference OPENROUTER_API_KEY", errors)
    require("https://openrouter.ai" not in ios_text, "iOS Swift code must not call OpenRouter directly", errors)
    require("sk-or-" not in ios_text, "iOS Swift code must not contain OpenRouter-looking keys", errors)


def main():
    errors = []
    validate_files(errors)
    if not errors:
        validate_high_level_ios_service(errors)
        validate_proxy_task_contract(errors)
        validate_secret_safety(errors)

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print("Round 7 AI service contract validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
