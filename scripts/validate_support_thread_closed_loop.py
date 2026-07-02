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
    support = read("ios/EnglishPlus/EnglishPlus/Features/Support/SupportView.swift")
    teacher = read("ios/EnglishPlus/EnglishPlus/Features/Teacher/TeacherHomeView.swift")
    volunteer = read("ios/EnglishPlus/EnglishPlus/Features/Volunteer/VolunteerHomeView.swift")
    mock_repo = read("ios/EnglishPlus/EnglishPlus/Services/MockLearningRepository.swift")
    firebase_repo = read("ios/EnglishPlus/EnglishPlus/Services/FirebaseLearningRepository.swift")

    require(models, "struct SupportQuestionSnapshot", "question snapshot model")
    require(models, "var questionSnapshot: SupportQuestionSnapshot?", "support request snapshot field")
    require(models, "selectedAnswerText", "student answer display helper")
    require(models, "correctAnswer", "correct answer snapshot field")
    require(models, "explanation", "explanation snapshot field")

    require(shared_card, "SupportQuestionSnapshotCard", "shared question snapshot card")
    require(shared_card, "學生答案", "student answer in snapshot card")
    require(shared_card, "正確答案", "correct answer in snapshot card")
    require(shared_card, "解析", "explanation in snapshot card")

    require(mock_repo, "questionSnapshot: SupportQuestionSnapshot(questionItem: questionItem, selectedAnswer: selectedAnswer)", "practice support request snapshot creation")
    require(practice, "送出後到「支持」查看回覆", "student support handoff copy")
    require(practice, "前往支持查看回覆", "direct support navigation after handoff")
    require(practice, "AI 建議", "non-link AI recommendation label")
    reject(practice, "線上 AI 已回應", "technical AI connection copy in practice")

    require(support, "SupportQuestionSnapshotCard(", "student inbox question context")
    require(support, "snapshot: snapshot", "student inbox snapshot binding")
    require(support, "看回覆後再練一題", "student follow-up action")
    require(support, "AI 已整理", "student-friendly AI result copy")
    reject(support, "相關題目：\\(questionId)", "question-id-only student support context")
    reject(support, "線上 AI 已回應", "technical AI connection copy in support")

    require(teacher, "SupportQuestionSnapshotCard(", "teacher sees question context")
    require(teacher, "snapshot: snapshot", "teacher snapshot binding")
    require(teacher, "針對這一題回覆", "teacher reply intent copy")
    require(volunteer, "SupportQuestionSnapshotCard(", "volunteer sees question context")
    require(volunteer, "snapshot: snapshot", "volunteer snapshot binding")
    require(volunteer, "學生答案與正解", "volunteer context copy")

    require(mock_repo, "questionSnapshot: SupportQuestionSnapshot(questionItem: questionItem, selectedAnswer: selectedAnswer)", "mock repository stores snapshot")
    require(firebase_repo, "questionSnapshot", "firebase repository mirrors snapshot")
    require(firebase_repo, "supportQuestionSnapshot(from:", "firebase repository reads snapshot")
    require(read("ios/EnglishPlus/EnglishPlus/Services/AIService.swift"), "questionPrompt: snapshot?.prompt", "AI support request carries question prompt")
    require(read("ios/EnglishPlus/EnglishPlus/Services/AIService.swift"), "studentAnswer: snapshot?.selectedAnswerText", "AI support request carries student answer")
    require(read("ios/EnglishPlus/EnglishPlus/Services/AIService.swift"), "correctAnswer: snapshot?.correctAnswer", "AI support request carries correct answer")

    print("support thread closed loop contract passed")


if __name__ == "__main__":
    main()
