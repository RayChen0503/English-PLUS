#!/usr/bin/env python3
import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FUNCTIONS_DIR = ROOT / "functions"
FUNCTIONS_INDEX = FUNCTIONS_DIR / "src" / "index.ts"
PACKAGE_JSON = FUNCTIONS_DIR / "package.json"
TSCONFIG = FUNCTIONS_DIR / "tsconfig.json"
SCHEMA_PATH = ROOT / "docs" / "ios-testflight" / "firebase" / "openrouter-ai-proxy.schema.json"
IOS_MODELS = ROOT / "ios" / "EnglishPlus" / "EnglishPlus" / "Models" / "AiProxyModels.swift"
IOS_SERVICE = ROOT / "ios" / "EnglishPlus" / "EnglishPlus" / "Services" / "AiProxyService.swift"
IOS_MOCK = ROOT / "ios" / "EnglishPlus" / "EnglishPlus" / "Services" / "MockAiProxyService.swift"
FIRESTORE_PATH = ROOT / "ios" / "EnglishPlus" / "EnglishPlus" / "Data" / "FirestorePath.swift"
FIRESTORE_SCHEMA = ROOT / "ios" / "EnglishPlus" / "EnglishPlus" / "Models" / "FirestoreSchema.swift"


def require(condition, message, errors):
    if not condition:
        errors.append(message)


def read(path):
    return path.read_text(encoding="utf-8")


def validate_functions(errors):
    for path in [PACKAGE_JSON, TSCONFIG, FUNCTIONS_INDEX]:
        require(path.exists(), f"missing {path.relative_to(ROOT)}", errors)

    package = json.loads(read(PACKAGE_JSON))
    require(package.get("engines", {}).get("node") == "20", "functions must target Node.js 20", errors)
    require("firebase-admin" in package.get("dependencies", {}), "firebase-admin dependency is required", errors)
    require("firebase-functions" in package.get("dependencies", {}), "firebase-functions dependency is required", errors)
    require(package.get("scripts", {}).get("build") == "tsc", "functions build script must run tsc", errors)

    tsconfig = json.loads(read(TSCONFIG))
    require(tsconfig.get("compilerOptions", {}).get("strict") is True, "functions TypeScript must be strict", errors)

    source = read(FUNCTIONS_INDEX)
    required_tokens = [
        "onCall",
        "defineSecret(\"OPENROUTER_API_KEY\")",
        "https://openrouter.ai/api/v1/chat/completions",
        "openrouter/free",
        "openrouter/auto",
        "request.auth?.uid",
        "loadMembership",
        "assertRateLimit",
        "assertVolunteerScope",
        "sanitizeContext",
        "classes/${classId}/aiUsage",
        "classes/${classId}/aiEvents",
        "thread.assignedToUid === uid",
        "\"HTTP-Referer\"",
        "\"X-OpenRouter-Title\"",
    ]
    for token in required_tokens:
        require(token in source, f"functions source missing {token}", errors)

    forbidden_tokens = ["sk-or-", "OPENROUTER_API_KEY=", "REPLACE_ME"]
    for token in forbidden_tokens:
        require(token not in source, f"functions source should not contain {token}", errors)


def validate_schema(errors):
    schema = json.loads(read(SCHEMA_PATH))
    require(schema.get("additionalProperties") is False, "AI proxy schema should reject unknown top-level fields", errors)
    task_enum = schema.get("properties", {}).get("taskType", {}).get("enum", [])
    for task in [
        "dailyMission",
        "wrongAnswerExplanation",
        "emotionalSupport",
        "teacherFeedbackDraft",
        "volunteerReplyCoach",
        "progressSummary",
    ]:
        require(task in task_enum, f"schema missing task {task}", errors)
    context_properties = schema.get("properties", {}).get("context", {}).get("properties", {})
    require("supportThreadId" in context_properties, "schema missing context.supportThreadId", errors)


def validate_ios(errors):
    for path in [IOS_MODELS, IOS_SERVICE, IOS_MOCK]:
        require(path.exists(), f"missing {path.relative_to(ROOT)}", errors)

    models = read(IOS_MODELS)
    mock = read(IOS_MOCK)
    for token in [
        "AiTaskType",
        "AiProxyRequest",
        "AiProxyResponse",
        "AiProxyUsage",
        "AiMissionOutput",
        "dailyMission",
        "wrongAnswerExplanation",
        "multipleChoice",
    ]:
        require(token in models, f"iOS AI models missing {token}", errors)

    require("SeedData.current" in mock, "mock AI proxy should use local seed data", errors)
    require("LOCAL_AI_PROXY_NOT_CONNECTED" in mock, "mock AI proxy should return explicit local fallback code", errors)
    require("OPENROUTER_API_KEY" not in models + mock, "iOS code must not reference OpenRouter API key", errors)

    firestore_path = read(FIRESTORE_PATH)
    firestore_schema = read(FIRESTORE_SCHEMA)
    for token in ["aiUsage(classId:", "aiEvent(classId:"]:
        require(token in firestore_path, f"FirestorePath missing {token}", errors)
    for token in ["FirestoreAiUsageDocument", "FirestoreAiEventDocument"]:
        require(token in firestore_schema, f"Firestore schema missing {token}", errors)


def validate_secret_safety(errors):
    require(not (FUNCTIONS_DIR / ".secret.local").exists(), "functions/.secret.local must not be committed", errors)
    gitignore = read(ROOT / ".gitignore")
    for token in ["functions/node_modules/", "functions/lib/", "functions/.secret.local"]:
        require(token in gitignore, f".gitignore missing {token}", errors)


def main():
    errors = []
    validate_functions(errors)
    validate_schema(errors)
    validate_ios(errors)
    validate_secret_safety(errors)

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print("Round 5 AI proxy contract validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
