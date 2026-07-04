from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    support = read("ios/EnglishPlus/EnglishPlus/Features/Support/SupportView.swift")
    teacher = read("ios/EnglishPlus/EnglishPlus/Features/Teacher/TeacherHomeView.swift")
    volunteer = read("ios/EnglishPlus/EnglishPlus/Features/Volunteer/VolunteerHomeView.swift")
    shared = read("ios/EnglishPlus/EnglishPlus/Features/Shared/StaffSupportActionBar.swift")
    models = read("ios/EnglishPlus/EnglishPlus/Models/LearningModels.swift")

    require("送給老師/志工" not in support, "Student empty state still uses split teacher/volunteer wording.")
    require("送給老師與志工" in support, "Student support empty state should describe one shared handoff.")
    require("老師/志工協助" in support, "Student support route title should show one shared staff support lane.")
    require("老師協助" not in support, "Student support inbox should not show old teacher-only route title.")
    require("志工陪伴" not in support, "Student support inbox should not show old volunteer-only route title.")

    require("老師與志工都會收到同一筆接力" in teacher, "Teacher queue should explain shared staff handoff.")
    require("老師與志工都會收到同一筆接力" in volunteer, "Volunteer queue should explain shared staff handoff.")
    require("任何一端回覆都會消除雙方紅點" in teacher, "Teacher queue should explain shared badge clearing.")
    require("任何一端回覆都會消除雙方紅點" in volunteer, "Volunteer queue should explain shared badge clearing.")

    require("只會消除你的紅點" in shared, "Staff action bar should explain read-without-reply is per-role.")
    require("另一端仍可看見" in shared, "Staff action bar should explain archive does not hide from the other role.")

    require("志工可以先用 AI 整理陪伴語氣" not in volunteer, "Volunteer composer still contains old verbose AI-first guidance.")
    require("VolunteerOriginalStudentMessageCard" not in volunteer, "Volunteer side should not keep a separate duplicate student-message card.")
    require("陪伴順序" not in volunteer, "Volunteer UI should not use old sequence wording.")
    require("StaffOriginalStudentMessageCard" not in teacher, "Teacher side should not keep a separate duplicate student-message card.")
    require("StaffMissingQuestionSnapshotLabel" in teacher, "Teacher side should use a low-priority missing-snapshot label.")

    require("teacherArchivedAt" in models and "volunteerArchivedAt" in models, "Support archive state must remain role-specific.")
    require("countsTowardSharedStaffBadge" in models, "Shared badge logic must remain role-aware.")
    require("hasAnyStaffAction" in models, "Shared badge clearing must be based on any staff action.")

    print("validate_shared_support_round4_final_ux: ok")


if __name__ == "__main__":
    main()
