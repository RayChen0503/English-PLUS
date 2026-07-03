from pathlib import Path
import re


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


def require_main_actor_async_cleanup(
    source: str,
    signature: str,
    loading_flag: str,
) -> None:
    require(
        f"@MainActor\n    {signature}" in source
        or f"@MainActor\n    private {signature.removeprefix('private ')}" in source,
        f"{signature} must be MainActor isolated before touching SwiftUI state around await.",
    )
    body = function_body(source, signature)
    require(
        f"{loading_flag} = true" in body,
        f"{signature} must set {loading_flag} before async work.",
    )
    require(
        f"defer {{ {loading_flag} = false }}" in body,
        f"{signature} must use defer to clear {loading_flag} even if AI/repository work falls back.",
    )


student_home = read("ios/EnglishPlus/EnglishPlus/Features/Student/StudentHomeView.swift")
practice_center = read("ios/EnglishPlus/EnglishPlus/Features/Practice/PracticeCenterView.swift")
support_view = read("ios/EnglishPlus/EnglishPlus/Features/Support/SupportView.swift")
teacher_home = read("ios/EnglishPlus/EnglishPlus/Features/Teacher/TeacherHomeView.swift")
volunteer_home = read("ios/EnglishPlus/EnglishPlus/Features/Volunteer/VolunteerHomeView.swift")

require_main_actor_async_cleanup(
    student_home,
    "private func generateMissionAfterAI() async",
    "isGeneratingMissionWithAI",
)
require_main_actor_async_cleanup(
    student_home,
    "private func askMissionAI(for item: QuestionBankItem, attempt: MissionAttempt) async",
    "isExplainingWrongAnswer",
)
require_main_actor_async_cleanup(
    practice_center,
    "private func requestPracticeRecommendation() async",
    "isLoadingPracticeAI",
)
require_main_actor_async_cleanup(
    practice_center,
    "private func askPracticeAI(for item: QuestionBankItem) async",
    "isLoadingPracticeQuestionAI",
)
require(
    "@MainActor\n    private func explainPracticeWrongAnswer(" in practice_center,
    "Practice wrong-answer AI explanation must run through a MainActor helper.",
)
explain_practice_body = function_body(
    practice_center,
    "private func explainPracticeWrongAnswer(attempt: MissionAttempt, item: QuestionBankItem) async",
)
require(
    "defer { isLoadingWrongAnswerAI = false }" in explain_practice_body,
    "Practice wrong-answer AI loading state must be cleared with defer.",
)
submit_body = function_body(
    practice_center,
    "private func submitPracticeAnswer(for item: QuestionBankItem)",
)
require(
    "wrongAnswerAIResponse = await" not in submit_body,
    "submitPracticeAnswer must not update AI response state inside an unisolated Task closure.",
)
require(
    "Task {\n            await explainPracticeWrongAnswer(attempt: attempt, item: item)\n        }" in submit_body,
    "submitPracticeAnswer must delegate wrong-answer AI to the MainActor helper.",
)

require(
    "@MainActor\n    private func loadSupportAI(for request: StudentSupportRequest) async" in support_view,
    "Support AI request must run through a MainActor helper.",
)
load_support_body = function_body(
    support_view,
    "private func loadSupportAI(for request: StudentSupportRequest) async",
)
require(
    "defer { isLoadingSupportAI = false }" in load_support_body,
    "Support AI loading state must be cleared with defer.",
)

header_match = re.search(
    r"private struct SupportInboxHeaderCard: View \{(?P<body>.*?)\n\}",
    support_view,
    flags=re.S,
)
require(header_match is not None, "SupportInboxHeaderCard is missing.")
header_body = header_match.group("body")
require(
    "onOpenPractice" not in header_body and "onOpenHome" not in header_body,
    "SupportInboxHeaderCard must not own navigation callbacks.",
)
require(
    "Label(\"去練習\"" not in header_body and "Label(\"回今日任務\"" not in header_body,
    "SupportInboxHeaderCard must not show the removed top navigation buttons.",
)
require(
    "SupportAIActionCard(" not in support_view,
    "Support mood AI response should not reintroduce the removed practice/home action card.",
)
require(
    "private struct SupportAIActionCard" not in support_view,
    "Removed support navigation action card should not remain in the file.",
)

require_main_actor_async_cleanup(
    teacher_home,
    "private func fillTeacherDraftWithAI() async",
    "isDraftingWithAI",
)
require_main_actor_async_cleanup(
    volunteer_home,
    "private func fillVolunteerDraftWithAI() async",
    "isDraftingWithAI",
)

print("iOS AI task crash guard and support cleanup validation passed")
