#!/usr/bin/env python3
import json
import tomllib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8-sig")


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def markers(content: str, expected: tuple[str, ...], label: str, errors: list[str]) -> None:
    for marker in expected:
        require(marker in content, f"{label} missing marker: {marker}", errors)


def main() -> int:
    errors: list[str] = []
    worker = read("workers/englishplus-ai-proxy/src/index.js")
    config = tomllib.loads(read("workers/englishplus-ai-proxy/wrangler.toml"))
    package = json.loads(read("workers/englishplus-ai-proxy/package.json"))
    quota_tests = read("workers/englishplus-ai-proxy/test/ai-quota.test.js")
    remote_ai = read("ios/EnglishPlus/EnglishPlus/Services/RemoteAIService.swift")
    ai_models = read("ios/EnglishPlus/EnglishPlus/Models/AiProxyModels.swift")
    student_home = read("ios/EnglishPlus/EnglishPlus/Features/Student/StudentHomeView.swift")
    practice = read("ios/EnglishPlus/EnglishPlus/Features/Practice/PracticeCenterView.swift")
    smoke = read("scripts/smoke_worker_firebase_runtime.py")
    workflow = read(".github/workflows/ios-hardening-build.yml")
    decisions = read("docs/app-store-hardening/DECISIONS.md")
    report = read("docs/app-store-hardening/round-09-ai-gateway-hardening.md")

    require(config.get("vars", {}).get("AI_QUOTA_MODE") == "internal", "Internal quota mode is not selected", errors)
    require(config.get("observability", {}).get("enabled") is True, "Workers observability is disabled", errors)
    require(config.get("observability", {}).get("head_sampling_rate") == 1.0, "Internal test logs are sampled", errors)
    require(len(config.get("ratelimits", [])) == 2, "Both internal and public rate limit bindings are required", errors)
    require(
        any(item.get("name") == "AI_QUOTA" for item in config.get("durable_objects", {}).get("bindings", [])),
        "AI quota Durable Object binding is missing",
        errors,
    )
    require(
        any("AIQuotaCoordinator" in item.get("new_sqlite_classes", []) for item in config.get("migrations", [])),
        "AI quota SQLite migration is missing",
        errors,
    )

    markers(worker, (
        'url.pathname === "/ai/quota"',
        "export class AIQuotaCoordinator extends DurableObject",
        "await authorizeAiRequest(env, user, normalized)",
        "await enforceAiBurstLimit(env, user.sub)",
        "await reserveAiQuota(env, user.sub, normalized, requestId)",
        'throw httpError(403, "AI_TASK_ROLE_FORBIDDEN")',
        'throw httpError(403, "AI_CLASS_MEMBERSHIP_REQUIRED")',
        'throw httpError(403, "AI_STUDENT_IDENTITY_MISMATCH")',
        'httpError(429, "AI_BURST_LIMIT_REACHED")',
        'httpError(429, "AI_DAILY_LIMIT_REACHED")',
        'httpError(409, "AI_REQUEST_ID_REUSED")',
        "AbortSignal.timeout(12_000)",
        "TAIPEI_TIMEZONE_OFFSET_MS",
        'event: "ai_request"',
        'crypto.subtle.digest(',
    ), "AI gateway", errors)

    log_start = worker.find("async function logAiRequest")
    log_end = worker.find("async function handleEvidenceUploadTicket", log_start)
    log_block = worker[log_start:log_end]
    for forbidden in ("questionPrompt", "studentAnswer", "correctAnswer", "displayName", "classId", "studentUid"):
        require(forbidden not in log_block, f"Structured AI log exposes {forbidden}", errors)

    scripts = package.get("scripts", {})
    require(scripts.get("test") == "vitest run", "Worker runtime test command is not Vitest", errors)
    require("@cloudflare/vitest-pool-workers" in package.get("devDependencies", {}), "Workers Vitest pool is missing", errors)
    markers(quota_tests, (
        "least-privilege by authenticated role",
        "atomic, retry-safe",
        "Taipei midnight",
        "AI_INTERNAL_BURST_LIMITER",
        "AI_PUBLIC_BURST_LIMITER",
    ), "Workers runtime quota tests", errors)

    markers(remote_ai, (
        "case requestRejected(status: Int, code: String?, retryAfterSeconds: Int?)",
        'forHTTPHeaderField: "X-EnglishPlus-Request-ID"',
        "WorkerErrorEnvelope.self",
        "errorEnvelope?.retryAfterSeconds ?? retryAfterHeader",
    ), "iOS AI transport", errors)
    markers(ai_models, (
        "var userFacingAvailabilityMessage: String",
        'case "AI_DAILY_LIMIT_REACHED"',
        'case "AI_BURST_LIMIT_REACHED"',
        'case "GROQ_TIMEOUT", "GROQ_UNAVAILABLE", "AI_PROXY_TIMEOUT"',
    ), "iOS AI fallback copy", errors)
    require("response.userFacingAvailabilityMessage" in student_home, "Student mission AI card is not quota-aware", errors)
    require("response.userFacingAvailabilityMessage" in practice, "Practice AI card is not quota-aware", errors)

    markers(smoke, (
        "authenticated_ai_quota_status",
        "student_cannot_invoke_teacher_ai",
        "student_cannot_forge_ai_identity",
        "teacher_cannot_invoke_student_ai",
        "volunteer_cannot_invoke_student_ai",
        "authenticated_personal_ai_blocks_client_quality_escalation",
        "ai_request_id_is_correlated",
        "ai_request_id_replay_is_rejected",
    ), "Production smoke suite", errors)
    markers(workflow, (
        "codex/app-store-hardening-c",
        ".github/ci-triggers/round9-ios-build",
        "npm test",
        "validate_app_store_hardening_round9.py",
        "generic/platform=iOS Simulator",
    ), "Round 9 isolated macOS gate", errors)
    markers(decisions, ("D-18", "180 weighted units", "60 units"), "Decision register", errors)
    markers(report, (
        "Round 9",
        "Decision A",
        "cf6dfb11-0644-4680-9fb9-f66e86e26996",
        "15/15",
        "34/34",
        "Firebase identity",
        "Taipei midnight",
        "No Xcode Cloud",
    ), "Round 9 report", errors)

    if errors:
        print("App Store hardening round 9 validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("App Store hardening round 9 AI gateway validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
