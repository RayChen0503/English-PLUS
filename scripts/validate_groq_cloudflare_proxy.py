#!/usr/bin/env python3
import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WORKER_ROOT = ROOT / "workers" / "englishplus-ai-proxy"
IOS_ROOT = ROOT / "ios" / "EnglishPlus" / "EnglishPlus"
REMOTE_AI = IOS_ROOT / "Services" / "RemoteAIService.swift"
FACTORY = IOS_ROOT / "Services" / "FirebaseAppConfigurator.swift"
INFO_PLIST = IOS_ROOT / "Info.plist"
GITIGNORE = ROOT / ".gitignore"
EXPECTED_AI_PROXY_URL = "https://englishplus-ai-proxy.englishplus-ray.workers.dev/ai"

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


def validate_worker(errors):
    files = {
        "worker package": WORKER_ROOT / "package.json",
        "wrangler": WORKER_ROOT / "wrangler.toml",
        "worker source": WORKER_ROOT / "src" / "index.js",
        "worker readme": WORKER_ROOT / "README.md",
    }
    for name, path in files.items():
        require(path.exists(), f"missing {name}: {path.relative_to(ROOT)}", errors)
    if errors:
        return

    package = json.loads(read(files["worker package"]))
    require(package.get("scripts", {}).get("deploy") == "wrangler deploy", "worker package must expose wrangler deploy", errors)
    require(package.get("scripts", {}).get("dev") == "wrangler dev", "worker package must expose wrangler dev", errors)

    wrangler = read(files["wrangler"])
    for token in [
        'name = "englishplus-ai-proxy"',
        'main = "src/index.js"',
        'compatibility_date',
        'GROQ_DEFAULT_MODEL',
        'llama-3.1-8b-instant',
    ]:
        require(token in wrangler, f"wrangler.toml missing {token}", errors)

    source = read(files["worker source"])
    for token in [
        "https://api.groq.com/openai/v1/chat/completions",
        "env.GROQ_API_KEY",
        "Access-Control-Allow-Origin",
        "handleHealth",
        "handleAi",
        "sanitizeContext",
        "buildFallbackResponse",
        "normalizeGroqResponse",
        "Authorization",
        "Bearer ${env.GROQ_API_KEY}",
    ]:
        require(token in source, f"worker source missing {token}", errors)
    for task in TASKS:
        require(task in source, f"worker source missing task {task}", errors)
    for forbidden in ["OPENROUTER_API_KEY", "openrouter.ai", "sk-or-", "gsk_"]:
        require(forbidden not in source, f"worker source must not contain {forbidden}", errors)

    readme = read(files["worker readme"])
    for token in ["wrangler login", "wrangler secret put GROQ_API_KEY", "wrangler deploy", "/ai", "/health"]:
        require(token in readme, f"worker README missing {token}", errors)

    gitignore = read(GITIGNORE)
    for token in ["workers/**/.dev.vars", "workers/**/.wrangler/"]:
        require(token in gitignore, f".gitignore missing {token}", errors)


def validate_ios(errors):
    for path in [REMOTE_AI, FACTORY, INFO_PLIST]:
        require(path.exists(), f"missing {path.relative_to(ROOT)}", errors)
    if errors:
        return

    remote = read(REMOTE_AI)
    factory = read(FACTORY)
    info = read(INFO_PLIST)
    all_swift = "\n".join(path.read_text(encoding="utf-8") for path in IOS_ROOT.rglob("*.swift"))

    for token in [
        "CloudflareWorkerAiProxyTransport",
        "EnglishPlusAIProxyConfig",
        "ENGLISHPLUS_AI_PROXY_URL",
        "CallableRequestEnvelope(data: request)",
        "CallableResponseEnvelope",
        "AI_PROXY_WORKER_NOT_CONFIGURED",
        "AI_PROXY_TASK_MISMATCH",
    ]:
        require(token in remote, f"RemoteAIService missing {token}", errors)

    require(
        "transport: AiProxyTransport = CloudflareWorkerAiProxyTransport()" in remote,
        "RemoteAIService default transport must be CloudflareWorkerAiProxyTransport",
        errors,
    )
    require(
        "CloudflareWorkerAiProxyTransport(" in factory,
        "Service factory must create RemoteAIService with CloudflareWorkerAiProxyTransport",
        errors,
    )
    require("ENGLISHPLUS_AI_PROXY_URL" in info, "Info.plist must define ENGLISHPLUS_AI_PROXY_URL", errors)
    require(
        EXPECTED_AI_PROXY_URL in info,
        f"Info.plist must point ENGLISHPLUS_AI_PROXY_URL to {EXPECTED_AI_PROXY_URL}",
        errors,
    )

    for forbidden in [
        "GROQ_API_KEY",
        "https://api.groq.com",
        "gsk_",
        "OPENROUTER_API_KEY",
        "https://openrouter.ai",
        "cloudfunctions.net",
        "englishPlusAiProxy",
    ]:
        require(forbidden not in all_swift, f"iOS Swift must not contain {forbidden}", errors)


def main():
    errors = []
    validate_worker(errors)
    validate_ios(errors)

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print("Groq Cloudflare proxy validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
