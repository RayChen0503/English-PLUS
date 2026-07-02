#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise SystemExit(f"Missing {label}: {needle}")


def reject(text: str, needle: str, label: str) -> None:
    if needle in text:
        raise SystemExit(f"Unexpected {label}: {needle}")


def main() -> None:
    models = read("ios/EnglishPlus/EnglishPlus/Models/LearningModels.swift")
    shared_card = read("ios/EnglishPlus/EnglishPlus/Features/Shared/SupportQuestionSnapshotCard.swift")
    practice = read("ios/EnglishPlus/EnglishPlus/Features/Practice/PracticeCenterView.swift")
    student = read("ios/EnglishPlus/EnglishPlus/Features/Student/StudentHomeView.swift")
    support = read("ios/EnglishPlus/EnglishPlus/Features/Support/SupportView.swift")
    teacher = read("ios/EnglishPlus/EnglishPlus/Features/Teacher/TeacherHomeView.swift")
    volunteer = read("ios/EnglishPlus/EnglishPlus/Features/Volunteer/VolunteerHomeView.swift")
    mock_repo = read("ios/EnglishPlus/EnglishPlus/Services/MockLearningRepository.swift")
    firebase_repo = read("ios/EnglishPlus/EnglishPlus/Services/FirebaseLearningRepository.swift")
    store = read("ios/EnglishPlus/EnglishPlus/Services/LearningRepositoryStore.swift")
    ai_service = read("ios/EnglishPlus/EnglishPlus/Services/AIService.swift")

    require(models, "struct SupportQuestionSnapshot", "question snapshot model")
    require(models, "var questionSnapshot: SupportQuestionSnapshot?", "support request snapshot field")
    require(models, "selectedAnswerText", "student answer display helper")
    require(models, "correctAnswer", "correct answer snapshot field")
    require(models, "explanation", "explanation snapshot field")

    require(shared_card, "SupportQuestionSnapshotCard", "shared question snapshot card")
    require(shared_card, "selectedAnswerText", "student answer in snapshot card")
    require(shared_card, "correctAnswer", "correct answer in snapshot card")
    require(shared_card, "explanation", "explanation in snapshot card")

    require(mock_repo, "questionSnapshot: SupportQuestionSnapshot(questionItem: questionItem, selectedAnswer: selectedAnswer)", "practice support request snapshot creation")
    require(practice, "PracticeInlineSupportPanel", "free practice inline support panel")
    require(practice, "sendPracticeSupportRequest", "free practice sends staff handoff")
    require(practice, "onSendTeacher", "free practice teacher support action")
    require(practice, "onSendVolunteer", "free practice volunteer support action")
    require(practice, "onOpenSupport", "free practice support navigation")
    require(practice, "AI 解題提示", "non-link AI recommendation label")
    reject(practice, "OpenRouter", "technical AI provider copy in practice")
    reject(practice, "GROQ_API_KEY", "secret copy in practice")

    require(student, "MissionQuestionSupportPanel", "daily mission inline support panel")
    require(student, "sendMissionSupportRequest", "daily mission sends staff handoff")
    require(student, "前往支持查看回覆", "daily mission support navigation")

    require(support, "SupportQuestionSnapshotCard(", "student inbox question context")
    require(support, "snapshot: snapshot", "student inbox snapshot binding")
    require(support, "SupportThreadActionRow", "student follow-up and archive action row")
    require(support, "onOpenPractice", "student can return to practice after reading replies")
    require(support, "SupportMoodAICard", "student-friendly AI support entry")
    reject(support, "questionId)", "question-id-only student support context")
    reject(support, "OpenRouter", "technical AI provider copy in support")
    reject(support, "GROQ_API_KEY", "secret copy in support")

    require(teacher, "TeacherSupportRequestCard", "teacher support request card")
    require(teacher, "SupportQuestionSnapshotCard(", "teacher sees question context")
    require(teacher, "snapshot: snapshot", "teacher snapshot binding")
    require(teacher, "StaffSupportActionBar", "teacher can reply / mark handled / archive")
    require(volunteer, "VolunteerQuestionContextCard", "volunteer context card")
    require(volunteer, "SupportQuestionSnapshotCard(", "volunteer sees question context")
    require(volunteer, "snapshot: snapshot", "volunteer snapshot binding")
    require(volunteer, "StaffSupportActionBar", "volunteer can reply / mark handled / archive")

    require(store, "countsTowardStaffBadge", "staff badge excludes handled or archived requests")
    require(store, "markSupportThreadReadByStudent", "student read state")
    require(store, "archiveSupportThreadForStudent", "student archive state")
    require(mock_repo, "questionSnapshot: SupportQuestionSnapshot(questionItem: questionItem, selectedAnswer: selectedAnswer)", "mock repository stores snapshot")
    require(firebase_repo, "questionSnapshot", "firebase repository mirrors snapshot")
    require(firebase_repo, "supportQuestionSnapshot(from:", "firebase repository reads snapshot")
    require(ai_service, "return AiProxyRequest(", "explicit support request return for Swift archive")
    require(ai_service, "questionPrompt: snapshot?.prompt", "AI support request carries question prompt")
    require(ai_service, "studentAnswer: snapshot?.selectedAnswerText", "AI support request carries student answer")
    require(ai_service, "correctAnswer: snapshot?.correctAnswer", "AI support request carries correct answer")

    print("support thread closed loop contract passed")


if __name__ == "__main__":
    main()
