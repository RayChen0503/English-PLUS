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
    model = read("ios/EnglishPlus/EnglishPlus/Models/LearningModels.swift")
    store = read("ios/EnglishPlus/EnglishPlus/Services/LearningRepositoryStore.swift")
    mock_repo = read("ios/EnglishPlus/EnglishPlus/Services/MockLearningRepository.swift")
    firebase_repo = read("ios/EnglishPlus/EnglishPlus/Services/FirebaseLearningRepository.swift")
    student = read("ios/EnglishPlus/EnglishPlus/Features/Student/StudentHomeView.swift")
    practice = read("ios/EnglishPlus/EnglishPlus/Features/Practice/PracticeCenterView.swift")
    teacher = read("ios/EnglishPlus/EnglishPlus/Features/Teacher/TeacherHomeView.swift")
    volunteer = read("ios/EnglishPlus/EnglishPlus/Features/Volunteer/VolunteerHomeView.swift")

    for needle in [
        "teacherArchivedAt",
        "volunteerArchivedAt",
        "teacherHandledWithoutReplyAt",
        "volunteerHandledWithoutReplyAt",
        "func isVisibleInStaffQueue(for role: UserRole) -> Bool",
        "func countsTowardSharedStaffBadge(for role: UserRole) -> Bool",
        "hasAnyStaffAction",
    ]:
        require(model, needle, "role-aware support request model")

    for needle in [
        "isVisibleInStaffQueue(for: .teacher)",
        "isVisibleInStaffQueue(for: .volunteer)",
        "countsTowardSharedStaffBadge(for: .teacher)",
        "countsTowardSharedStaffBadge(for: .volunteer)",
    ]:
        require(store, needle, "shared staff queue store filters")

    for repository_name, text in {
        "mock repository": mock_repo,
    }.items():
        for needle in [
            "markStaffThreadHandled",
            "archiveStaffThread",
            "teacherHandledWithoutReplyAt",
            "volunteerHandledWithoutReplyAt",
            "teacherArchivedAt",
            "volunteerArchivedAt",
        ]:
            require(text, needle, repository_name)

    for needle in [
        "activeStaffRole",
        "staffVisibleSupportRequest",
        "updateSupportThread",
        "teacherHandledWithoutReplyAt",
        "volunteerHandledWithoutReplyAt",
        "teacherArchivedAt",
        "volunteerArchivedAt",
    ]:
        require(firebase_repo, needle, "firebase confirmed support mutation repository")

    for needle in [
        "\"teacherHandledWithoutReplyAt\"",
        "\"volunteerHandledWithoutReplyAt\"",
        "\"teacherArchivedAt\"",
        "\"volunteerArchivedAt\"",
    ]:
        require(firebase_repo, needle, "Firestore role-specific fields")

    require(student, "送給老師與志工", "student daily shared support copy")
    require(student, "missionSupportSentKey(for item: QuestionBankItem)", "student shared support sent key")
    require(practice, "送給老師與志工", "practice shared support copy")
    require(practice, "practiceSupportSentKey(for item: QuestionBankItem)", "practice shared support sent key")
    require(teacher, "waitingCount: learningRepository.staffDashboardMetrics.waitingHelpCount", "teacher badge metric")
    require(volunteer, "waitingCount: learningRepository.volunteerDashboardMetrics.waitingCount", "volunteer badge metric")

    for label, text in {"student": student, "practice": practice}.items():
        for needle in [
            'Label("送給老師"',
            'Label("送給志工"',
            '"已送老師"',
            '"已送志工"',
            "onSendTeacher",
            "onSendVolunteer",
        ]:
            reject(text, needle, f"{label} split support target")

    print("Shared staff handoff round 3 validation passed.")


if __name__ == "__main__":
    main()
