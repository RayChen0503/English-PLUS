from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    assert condition, message


def function_body(source: str, signature: str) -> str:
    start = source.find(signature)
    require(start >= 0, f"Missing function signature: {signature}")
    brace = source.find("{", start)
    require(brace >= 0, f"Missing function body for: {signature}")
    depth = 0
    for index in range(brace, len(source)):
        character = source[index]
        if character == "{":
            depth += 1
        elif character == "}":
            depth -= 1
            if depth == 0:
                return source[brace + 1:index]
    raise AssertionError(f"Unclosed function body for: {signature}")


question_model = read("ios/EnglishPlus/EnglishPlus/Models/Question.swift")
practice_center = read("ios/EnglishPlus/EnglishPlus/Features/Practice/PracticeCenterView.swift")
mock_repository = read("ios/EnglishPlus/EnglishPlus/Services/MockLearningRepository.swift")

fallback_body = function_body(
    question_model,
    "static func balancedFallbackCandidates(",
)
require(
    "limit: approved.count" not in fallback_body,
    "Fallback candidate generation must not fully rebalance the entire 1000+ question bank on the main thread.",
)
require(
    "balancedItems(from: uniqueItems(tiers.flatMap { $0 })" not in fallback_body,
    "Fallback candidate generation should build a bounded candidate pool, not run the expensive balanced selector on every approved item.",
)

diversity_body = function_body(
    question_model,
    "private static func diversityScore(",
)
require(
    "selected.filter" not in diversity_body,
    "Question diversity scoring must not rescan the whole selected list for every remaining candidate.",
)

balanced_body = function_body(
    question_model,
    "static func balancedItems(",
)
require(
    "AnswerDistributionState" in balanced_body,
    "balancedItems should maintain incremental distribution state instead of recomputing selected statistics repeatedly.",
)

question_bank_items_body = function_body(
    practice_center,
    "private var questionBankItems: [QuestionBankItem]",
)
require(
    "learningRepository.questionBankItems" in question_bank_items_body,
    "PracticeCenterView should read a cached question bank list from the repository instead of flattening practice sets during view rendering.",
)
require(
    ".flatMap(\\.items)" not in question_bank_items_body,
    "PracticeCenterView.questionBankItems must not flatten every practice set during SwiftUI rendering.",
)

require(
    "@State private var recommendedPracticePlan: AIPracticeRecommendationPlan?" in practice_center,
    "Practice AI recommendation plan must be cached in SwiftUI state after the AI response, not recomputed during every render.",
)
require(
    "\n    private var recommendedPracticePlan: AIPracticeRecommendationPlan? {" not in practice_center,
    "Practice AI recommendation plan must not be a computed property that rescans the question bank during view rendering.",
)
request_ai_body = function_body(
    practice_center,
    "private func requestPracticeRecommendation() async",
)
require(
    "recommendedPracticePlan = nil" in request_ai_body
    and "recommendedPracticePlan = buildAIRecommendationPlan(from: response)" in request_ai_body,
    "Practice AI recommendation should clear stale state before loading and build the plan once after the AI response returns.",
)
reset_body = function_body(
    practice_center,
    "private func resetSelectionState()",
)
require(
    "practiceAIResponse = nil" in reset_body
    and "recommendedPracticePlan = nil" in reset_body,
    "Changing practice filters or sets must clear stale AI recommendation state without destroying an active session.",
)
require(
    "freePracticeSessionItems = []" not in reset_body
    and "clearPersistedPrimarySession()" not in reset_body,
    "Changing selection filters must not destroy an unfinished primary practice session.",
)

answer_state_body = function_body(
    question_model,
    "private struct AnswerDistributionState",
)
require(
    "QuestionGroupingEngine.normalizedAnswer" in answer_state_body
    and "QuestionGroupingEngine.normalizedSkill" in answer_state_body
    and "QuestionGroupingEngine.normalizedConcept" in answer_state_body,
    "Nested answer distribution state must call QuestionGroupingEngine helpers explicitly so Xcode Cloud can resolve them safely.",
)
require(
    "appendRecent(" not in answer_state_body
    and "to: &recent" not in answer_state_body,
    "Answer distribution state must not mutate recent arrays through overlapping inout calls.",
)

mission_selection_body = function_body(
    mock_repository,
    "private func selectMissionQuestions(",
)
require(
    "seedSnapshot.approvedQuestionBankItems" not in mission_selection_body,
    "Daily AI mission generation must use the cached question bank instead of reading the full seed snapshot on the interaction path.",
)
require(
    ".sorted" not in mission_selection_body,
    "Daily AI mission generation must not sort the entire question bank after the AI response returns.",
)
require(
    "cachedQuestionBankItems" in mission_selection_body
    and "missionCandidateWindow" in mission_selection_body,
    "Daily AI mission generation should build a bounded candidate window from cached question data.",
)
require(
    "Dictionary(uniqueKeysWithValues:" not in mock_repository,
    "Question bank id cache must tolerate duplicate or regenerated ids instead of trapping at runtime.",
)

practice_set_card_body = function_body(
    practice_center,
    "private var practiceSetSelectionCard: some View",
)
require(
    "visiblePracticeSets" in practice_set_card_body,
    "Practice center should pass a bounded, cached visible set list into the set picker instead of the full catalog during rendering.",
)

print("iOS practice runtime complexity guard passed")
