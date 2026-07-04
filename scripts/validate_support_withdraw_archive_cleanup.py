#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    models = read("ios/EnglishPlus/EnglishPlus/Models/LearningModels.swift")
    store = read("ios/EnglishPlus/EnglishPlus/Services/LearningRepositoryStore.swift")
    mock = read("ios/EnglishPlus/EnglishPlus/Services/MockLearningRepository.swift")
    firebase = read("ios/EnglishPlus/EnglishPlus/Services/FirebaseLearningRepository.swift")
    support = read("ios/EnglishPlus/EnglishPlus/Features/Support/SupportView.swift")
    shared_staff = read("ios/EnglishPlus/EnglishPlus/Features/Shared/StaffSupportActionBar.swift")
    teacher = read("ios/EnglishPlus/EnglishPlus/Features/Teacher/TeacherHomeView.swift")
    volunteer = read("ios/EnglishPlus/EnglishPlus/Features/Volunteer/VolunteerHomeView.swift")

    require("var withdrawnAt: Date?" in models, "Support requests need a student withdrawal timestamp.")
    require("var isWithdrawn: Bool" in models, "Support requests need a withdrawal helper.")
    require("var canStudentWithdrawBeforeReply: Bool" in models, "Student withdrawal must be limited to unreplied threads.")
    require("var canStudentArchiveAfterStaffArchivedWithoutReply: Bool" in models, "Student must be able to hide staff-archived no-reply threads.")
    require("guard !isWithdrawn else { return false }" in models, "Withdrawn requests must disappear from staff queues.")
    require("withdrawnAt == nil" in models, "Withdrawn requests must disappear from the student inbox.")

    require("func withdrawSupportRequest(_ requestId: String)" in store, "Store protocol must expose student withdrawal.")
    require("backend.withdrawSupportRequest(requestId)" in store, "Store wrapper must forward student withdrawal.")
    require("func withdrawSupportRequest(_ requestId: String)" in mock, "Mock repository must implement student withdrawal.")
    require("func withdrawSupportRequest(_ requestId: String)" in firebase, "Firebase repository must implement student withdrawal.")
    require('"withdrawnAt"' in firebase, "Firebase payload must mirror withdrawnAt.")
    require('withdrawnAt: firestoreDate(data["withdrawnAt"])' in firebase, "Firebase decoder must restore withdrawnAt.")

    require("SupportWithdrawRequestRow" in support, "Student support page must show a withdraw action before replies.")
    require("withdrawSupportRequest(request.id)" in support, "Student withdraw button must call repository withdrawal.")
    require("canStudentArchiveAfterStaffArchivedWithoutReply" in support, "Student support page must show archive after staff archives without replying.")
    require("收回這題" in support, "Student support page needs clear withdraw wording.")

    for label, text in {
        "shared staff action bar": shared_staff,
        "teacher support page": teacher,
        "volunteer support page": volunteer,
    }.items():
        require("已讀不回" not in text, f"{label} still exposes read-without-reply wording.")
        require("markHandledWithoutReply" not in text, f"{label} still wires read-without-reply action.")
        require("markSupportThreadHandledWithoutReply" not in text, f"{label} still calls read-without-reply repository action.")

    print("support withdraw/archive cleanup validation passed")


if __name__ == "__main__":
    main()
