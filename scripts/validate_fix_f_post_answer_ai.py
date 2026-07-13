"""Static acceptance checks for FIX-F post-submission AI assistance."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


ai_service = read("ios/EnglishPlus/EnglishPlus/Services/AIService.swift")
app_state = read("ios/EnglishPlus/EnglishPlus/App/AppState.swift")
student = read("ios/EnglishPlus/EnglishPlus/Features/Student/StudentHomeView.swift")
practice = read("ios/EnglishPlus/EnglishPlus/Features/Practice/PracticeCenterView.swift")
worker = read("workers/englishplus-ai-proxy/src/index.js")
worker_tests = read("workers/englishplus-ai-proxy/test/ai-actions.test.js")
swift_tests = read("ios/EnglishPlus/EnglishPlusTests/AuthenticationFlowAcceptanceTests.swift")

require("enum PostSubmissionAssistancePolicy" in ai_service, "Shared assistance policy is missing")
require("answer != \"尚未作答\"" in ai_service, "Placeholder answers must be rejected")
require(
    "guard context.isEligibleForExplanation else { return nil }" in app_state,
    "AppState must block invalid explanation requests",
)
require(
    "private func submitMissionAnswer(for item: QuestionBankItem)" in student,
    "Daily mission submission entry is missing",
)
require(
    "submitMissionAnswerWithAI" not in student,
    "Daily mission submission must not imply or trigger automatic AI",
)
require("missionAIRequestId" in student, "Daily mission stale AI responses must be rejected")
require(
    "learningRepository.latestMissionAttempt?.id == attempt.id" in student,
    "Daily mission AI must remain attached to the submitted attempt",
)
require(
    student.index("MissionQuestionSupportPanel(") > student.index("private struct FeedbackCard"),
    "Daily mission assistance must live in post-answer feedback",
)
require(
    "private func explainPracticeWrongAnswer" not in practice,
    "Free practice must not automatically request AI after a wrong answer",
)
require(
    "if !practiceResult.isCorrect {\n                        PracticeInlineSupportPanel(" in practice,
    "Practice assistance must render only after a submitted wrong result",
)
require(
    practice.index("nextPracticeQuestion()") < practice.index("PracticeInlineSupportPanel("),
    "The primary continue action must appear before optional assistance",
)
require(
    "PostSubmissionAssistancePolicy.canRequestExplanation" in practice,
    "Practice AI and human support must use the post-submission gate",
)
for obsolete in ("wrongAnswerAIResponse", "isLoadingWrongAnswerAI", "wrongAnswerAIRequestId"):
    require(obsolete not in practice, f"Obsolete automatic-AI state remains: {obsolete}")

require("function validateAiTaskContext" in worker, "Worker context validation is missing")
require("AI_ANSWER_SUBMISSION_REQUIRED" in worker, "Worker must reject pre-answer explanation calls")
require(
    "wrong-answer AI rejects requests without a submitted answer" in worker_tests,
    "Worker rejection coverage is missing",
)
require(
    "PostSubmissionAssistanceAcceptanceTests" in swift_tests,
    "Swift post-submission acceptance coverage is missing",
)

print("FIX-F post-submission AI assistance contract passed")
