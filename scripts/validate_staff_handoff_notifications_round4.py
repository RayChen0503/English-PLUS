from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative_path: str) -> str:
    return (ROOT / relative_path).read_text(encoding="utf-8")


teacher_home = read("ios/EnglishPlus/EnglishPlus/Features/Teacher/TeacherHomeView.swift")
teacher_shell = read("ios/EnglishPlus/EnglishPlus/Features/Teacher/TeacherShellView.swift")
volunteer_home = read("ios/EnglishPlus/EnglishPlus/Features/Volunteer/VolunteerHomeView.swift")
volunteer_shell = read("ios/EnglishPlus/EnglishPlus/Features/Volunteer/VolunteerShellView.swift")
repository_store = read("ios/EnglishPlus/EnglishPlus/Services/LearningRepositoryStore.swift")


required_teacher_markers = [
    "StaffSupportQueueHeaderCard",
    "StaffSupportActionBar",
    "archiveSupportThreadForStaff(request.id, by: appState.currentUser)",
    "learningRepository.teacherQueue",
    "waitingCount: learningRepository.staffDashboardMetrics.waitingHelpCount",
]

required_teacher_shell_markers = [
    ".badge(learningRepository.staffDashboardMetrics.waitingHelpCount)",
    "@EnvironmentObject private var learningRepository: LearningRepositoryStore",
]

required_volunteer_markers = [
    "StaffSupportQueueHeaderCard",
    "StaffSupportActionBar",
    "archiveSupportThreadForStaff(request.id, by: appState.currentUser)",
    "learningRepository.volunteerQueue",
    "waitingCount: learningRepository.volunteerDashboardMetrics.waitingCount",
]

required_volunteer_shell_markers = [
    ".badge(learningRepository.volunteerDashboardMetrics.waitingCount)",
    "@EnvironmentObject private var learningRepository: LearningRepositoryStore",
]

required_repository_markers = [
    "countsTowardSharedStaffBadge(for: .teacher)",
    "countsTowardSharedStaffBadge(for: .volunteer)",
    "isVisibleInStaffQueue(for: .teacher)",
    "isVisibleInStaffQueue(for: .volunteer)",
    "staffHandledNoReply",
]


def missing_markers(source: str, markers: list[str]) -> list[str]:
    return [marker for marker in markers if marker not in source]


failures = {
    "TeacherHomeView.swift": missing_markers(teacher_home, required_teacher_markers),
    "TeacherShellView.swift": missing_markers(teacher_shell, required_teacher_shell_markers),
    "VolunteerHomeView.swift": missing_markers(volunteer_home, required_volunteer_markers),
    "VolunteerShellView.swift": missing_markers(volunteer_shell, required_volunteer_shell_markers),
    "LearningRepositoryStore.swift": missing_markers(repository_store, required_repository_markers),
}

failures = {name: missing for name, missing in failures.items() if missing}

if failures:
    for name, missing in failures.items():
        print(f"{name} missing:")
        for marker in missing:
            print(f"  - {marker}")
    raise SystemExit(1)

print("Staff handoff notification round 4 contract passed.")
