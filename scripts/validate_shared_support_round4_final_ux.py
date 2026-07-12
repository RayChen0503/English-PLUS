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

    require("老師/志工協助" in support, "Student support route must use one shared staff lane.")
    require(
        "老師與志工的回覆會集中在這裡" in support,
        "Student inbox must explain the shared reply center.",
    )

    shared_handoff_copy = "老師與志工都會收到同一筆接力"
    require(shared_handoff_copy in teacher, "Teacher queue must explain shared handoff.")
    require(shared_handoff_copy in volunteer, "Volunteer queue must explain shared handoff.")
    require(
        "任何一端回覆都會消除雙方紅點" in teacher
        and "任何一端回覆都會消除雙方紅點" in volunteer,
        "Both staff queues must explain shared badge clearing.",
    )

    require(
        "收起只會從你的待辦移除" in shared,
        "Staff action bar must explain role-specific archive behavior.",
    )
    require(
        "另一端仍可看見" in shared,
        "Staff archive copy must explain that the other role retains access.",
    )
    require("markSupportThreadHandledWithoutReply" not in teacher + volunteer,
            "Removed read-without-reply action must not return to staff UI.")
    require("StaffOriginalStudentMessageCard" not in teacher,
            "Teacher side must not duplicate the student message card.")
    require("VolunteerOriginalStudentMessageCard" not in volunteer,
            "Volunteer side must not duplicate the student message card.")
    require("StaffMissingQuestionSnapshotLabel" in teacher,
            "Teacher side must keep a low-priority missing-snapshot label.")

    require("teacherArchivedAt" in models and "volunteerArchivedAt" in models,
            "Support archive state must remain role-specific.")
    require("countsTowardSharedStaffBadge" in models,
            "Shared badge logic must remain role-aware.")
    require("hasAnyStaffAction" in models,
            "Shared badge clearing must be based on any staff action.")

    print("validate_shared_support_round4_final_ux: ok")


if __name__ == "__main__":
    main()
