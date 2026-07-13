#!/usr/bin/env python3
import json
from collections import Counter
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
    decisions = read("docs/app-store-hardening/DECISIONS.md")
    ai_models = read("ios/EnglishPlus/EnglishPlus/Models/AiProxyModels.swift")
    mock_ai = read("ios/EnglishPlus/EnglishPlus/Services/MockAiProxyService.swift")
    practice = read("ios/EnglishPlus/EnglishPlus/Features/Practice/PracticeCenterView.swift")
    student = read("ios/EnglishPlus/EnglishPlus/Features/Student/StudentHomeView.swift")
    questions = read("ios/EnglishPlus/EnglishPlus/Models/Question.swift")
    repository = read("ios/EnglishPlus/EnglishPlus/Services/LearningRepositoryStore.swift")
    mission_repository = read("ios/EnglishPlus/EnglishPlus/Services/MockLearningRepository.swift")
    teacher = read("ios/EnglishPlus/EnglishPlus/Features/Teacher/TeacherHomeView.swift")
    volunteer = read("ios/EnglishPlus/EnglishPlus/Features/Volunteer/VolunteerHomeView.swift")
    worker = read("workers/englishplus-ai-proxy/src/index.js")
    worker_tests = read("workers/englishplus-ai-proxy/test/ai-actions.test.js")
    smoke = read("scripts/smoke_worker_firebase_runtime.py")
    workflow = read(".github/workflows/ios-hardening-build.yml")
    report = read("docs/app-store-hardening/round-10-executable-ai-actions.md")

    markers(decisions, ("D-19", "D-20", "D-21", "D-22"), "Decision register", errors)
    markers(ai_models, (
        "struct AiPracticePlanOutput",
        "var targetQuestionCount: Int",
        "var focusSkills: [String]",
        "var practicePlan: AiPracticePlanOutput?",
    ), "iOS structured AI model", errors)
    markers(worker, (
        'case "progressSummary"',
        "Create an executable English practice recommendation, not only prose.",
        "function normalizePracticePlan(raw)",
        "function normalizePlanTotal(plan, targetCount)",
        'taskType === "wrongAnswerExplanation"',
        "function fallbackOutput(request)",
    ), "Worker executable AI contract", errors)
    markers(worker_tests, (
        "bounded executable practice plan",
        "invalid AI plan values are replaced and capped",
        "missing practice plan still produces an executable fallback shape",
        "staff draft fields stay separate",
    ), "Worker AI action tests", errors)

    markers(practice, (
        "structuredRecommendationSelection(",
        "questionType(fromAIValue:",
        "questionLevels(fromAIDifficulty:",
        "requestPrimarySessionStart(",
        "items: plan.items",
        "sourceTitle: plan.title",
        "launchPendingPracticeIfNeeded()",
        "startWrongAnswerRepair()",
        'Label("練 \\(repairQuestionCount) 題同類題", systemImage: "target")',
    ), "Practice action flow", errors)
    require(
        "buildPracticeSessionItems(from: plan.items)" not in practice,
        "Applying an AI plan still silently fills it to the generic session size",
        errors,
    )
    require(
        "這是驗證 AI 是否連線" not in practice,
        "Role-facing practice UI still exposes diagnostic copy",
        errors,
    )

    markers(questions, (
        "static func repairSelection(",
        "item.id != source.id",
        "normalizedSkill(item) == sourceSkill",
    ), "Wrong-answer repair selector", errors)
    markers(repository, (
        "struct PracticeLaunchRequest",
        "@Published private(set) var pendingPracticeLaunch",
        "func scheduleFocusedPractice(",
        "func takePendingPracticeLaunch()",
    ), "Cross-screen repair handoff", errors)
    markers(student, (
        "QuestionGroupingEngine.repairSelection(",
        "learningRepository.scheduleFocusedPractice(",
        "openPracticeFromAI(for item: QuestionBankItem)",
    ), "Daily mission repair action", errors)

    markers(mission_repository, (
        "aiPlan: aiMission?.questionPlan",
        "for planItem in aiPlan",
        "questionLevels(from: planItem.difficulty",
    ), "Daily mission structured selection", errors)
    markers(mock_ai, (
        "practiceRecommendationResponse(for:",
        "AiPracticePlanOutput(",
        "staffDraftResponse(for:",
    ), "Offline AI action fallback", errors)

    markers(teacher, (
        "struct StaffAIDraftCard",
        "aiDraftResponse = response",
        "採用並編輯這份",
        "只有按下回覆才會送給學生",
    ), "Teacher AI draft workflow", errors)
    markers(volunteer, (
        "StaffAIDraftCard(",
        "aiDraftResponse = response",
        "learningRepository.addVolunteerReply",
    ), "Volunteer AI draft workflow", errors)
    require(
        "replyDraft = response.output.studentFacingFeedback" not in teacher
        and "replyDraft = response.output.studentFacingFeedback" not in volunteer,
        "AI still overwrites a staff reply before explicit adoption",
        errors,
    )

    question_bank = json.loads(read("ios/EnglishPlus/EnglishPlus/Resources/SeedData/question_bank_seed.json"))
    approved = [item for item in question_bank["items"] if item.get("reviewState") == "approved"]
    group_counts = Counter(
        (
            item["question"]["type"],
            item["level"],
            (item.get("skill") or item["question"].get("concept") or "").strip().lower(),
        )
        for item in approved
    )
    require(len(approved) >= 1000, "Approved question bank dropped below the product baseline", errors)
    require(
        bool(group_counts) and min(group_counts.values()) >= 4,
        "At least one question type/level/skill group cannot provide a source plus three repair questions",
        errors,
    )

    markers(smoke, (
        "authenticated_ai_returns_executable_practice_plan",
        "authenticated_ai_returns_actionable_wrong_answer_repair",
    ), "Production AI action smoke suite", errors)
    markers(workflow, (
        ".github/ci-triggers/round10-ios-build",
        "validate_app_store_hardening_round10.py",
    ), "Round 10 isolated macOS gate", errors)
    markers(report, (
        "Round 10",
        "Status: Complete",
        "19/19",
        "No Xcode Cloud",
        "structured practice plan",
        "wrong-answer repair",
        "explicit adoption",
    ), "Round 10 report", errors)

    if errors:
        print("App Store hardening round 10 validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("App Store hardening round 10 executable AI actions validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
