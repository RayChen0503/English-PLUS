#!/usr/bin/env python3
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
IOS_ROOT = ROOT / "ios" / "EnglishPlus" / "EnglishPlus"
SERVICES = IOS_ROOT / "Services"
WORKER_ROOT = ROOT / "workers" / "englishplus-ai-proxy"

FILES = {
    "ai_models": IOS_ROOT / "Models" / "AiProxyModels.swift",
    "ai_service": SERVICES / "AIService.swift",
    "mock_ai_service": SERVICES / "MockAIService.swift",
    "remote_ai_service": SERVICES / "RemoteAIService.swift",
    "app_state": IOS_ROOT / "App" / "AppState.swift",
    "app": IOS_ROOT / "App" / "EnglishPlusApp.swift",
    "factory": SERVICES / "FirebaseAppConfigurator.swift",
    "info": IOS_ROOT / "Info.plist",
    "project": ROOT / "ios" / "EnglishPlus" / "EnglishPlus.xcodeproj" / "project.pbxproj",
    "worker": WORKER_ROOT / "src" / "index.js",
    "wrangler": WORKER_ROOT / "wrangler.toml",
}

TASKS = [
    "dailyMission",
    "wrongAnswerExplanation",
    "emotionalSupport",
    "teacherFeedbackDraft",
    "volunteerReplyCoach",
    "progressSummary",
]


def read(key: str) -> str:
    return FILES[key].read_text(encoding="utf-8")


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def validate_files(errors: list[str]) -> None:
    for name, path in FILES.items():
        require(path.exists(), f"missing {name}: {path.relative_to(ROOT)}", errors)


def validate_ios_service_contract(errors: list[str]) -> None:
    ai_service = read("ai_service")
    mock = read("mock_ai_service")
    remote = read("remote_ai_service")
    app_state = read("app_state")
    app = read("app")
    factory = read("factory")
    info = read("info")
    project = read("project")

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
        "questionPrompt: snapshot?.prompt",
        "studentAnswer: snapshot?.selectedAnswerText",
        "correctAnswer: snapshot?.correctAnswer",
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
        "CloudflareWorkerAiProxyTransport",
        "EnglishPlusAIProxyConfig",
        "ENGLISHPLUS_AI_PROXY_URL",
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

    require("EnglishPlusServiceFactory.makeServices()" in app, "EnglishPlusApp must use EnglishPlusServiceFactory", errors)
    require("CloudflareWorkerAiProxyTransport(" in factory, "Service factory must wire Cloudflare Worker AI transport", errors)
    require("idTokenProvider: authService.currentIdToken" in factory, "Cloudflare Worker transport must receive Firebase ID token provider", errors)
    require("ENGLISHPLUS_AI_PROXY_URL" in info, "Info.plist must define ENGLISHPLUS_AI_PROXY_URL", errors)
    require("https://englishplus-ai-proxy.englishplus-ray.workers.dev/ai" in info, "Info.plist must point to the live Cloudflare Worker endpoint", errors)

    for token in ["AIService.swift", "MockAIService.swift", "RemoteAIService.swift"]:
        require(token in project, f"Xcode project missing {token}", errors)


def validate_worker_contract(errors: list[str]) -> None:
    worker = read("worker")
    wrangler = read("wrangler")

    for task in TASKS:
        require(task in worker, f"Cloudflare Worker missing task {task}", errors)

    for token in [
        "GROQ_CHAT_COMPLETIONS_URL",
        "https://api.groq.com/openai/v1/chat/completions",
        "env.GROQ_API_KEY",
        "Authorization: `Bearer ${env.GROQ_API_KEY}`",
        "buildFallbackResponse",
        "normalizeGroqResponse",
        'url.pathname === "/health"',
        'url.pathname === "/ai"',
    ]:
        require(token in worker, f"Cloudflare Worker missing {token}", errors)

    for token in [
        'name = "englishplus-ai-proxy"',
        "GROQ_DEFAULT_MODEL",
        "GROQ_QUALITY_MODEL",
    ]:
        require(token in wrangler, f"wrangler.toml missing {token}", errors)


def validate_secret_safety(errors: list[str]) -> None:
    ios_text = "\n".join(path.read_text(encoding="utf-8") for path in IOS_ROOT.rglob("*.swift"))
    for forbidden in [
        "OPENROUTER_API_KEY",
        "https://openrouter.ai",
        "sk-or-",
        "GROQ_API_KEY",
        "https://api.groq.com",
        "gsk_",
        "cloudfunctions.net",
        "englishPlusAiProxy",
    ]:
        require(forbidden not in ios_text, f"iOS Swift code must not contain {forbidden}", errors)


def main() -> int:
    errors: list[str] = []
    validate_files(errors)
    if not errors:
        validate_ios_service_contract(errors)
        validate_worker_contract(errors)
        validate_secret_safety(errors)

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print("Round 7 Groq Cloudflare AI service contract validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
