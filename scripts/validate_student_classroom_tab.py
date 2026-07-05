from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
IOS = ROOT / "ios" / "EnglishPlus" / "EnglishPlus"
PBXPROJ = ROOT / "ios" / "EnglishPlus" / "EnglishPlus.xcodeproj" / "project.pbxproj"


def read(relative: str) -> str:
    return (IOS / relative).read_text(encoding="utf-8")


def assert_contains(text: str, needle: str, message: str) -> None:
    if needle not in text:
        raise AssertionError(message)


def assert_not_contains(text: str, needle: str, message: str) -> None:
    if needle in text:
        raise AssertionError(message)


def main() -> None:
    shell = read("Features/Student/StudentShellView.swift")
    home = read("Features/Student/StudentHomeView.swift")
    learning_map = read("Features/Student/StudentLearningMapView.swift")
    classroom_path = IOS / "Features" / "Student" / "StudentClassroomView.swift"
    project = PBXPROJ.read_text(encoding="utf-8")

    if not classroom_path.exists():
        raise AssertionError("StudentClassroomView.swift should exist for the dedicated class tab.")

    classroom = classroom_path.read_text(encoding="utf-8")

    assert_contains(shell, "StudentClassroomView", "Student shell should include the class assignment tab view.")
    assert_contains(shell, 'Label("班級"', "Student shell should expose a visible class tab.")
    assert_contains(shell, "pendingAssignmentCount", "Student shell should compute pending assignment badge count.")
    assert_contains(shell, ".badge(pendingAssignmentCount)", "Student shell should show a badge on pending class assignments.")
    assert_contains(shell, "case classroom", "StudentTab should include a classroom case.")

    practice_index = shell.find('Label("練習"')
    classroom_index = shell.find('Label("班級"')
    support_index = shell.find('Label("支持"')
    if not (practice_index != -1 and classroom_index != -1 and support_index != -1):
        raise AssertionError("Practice, class, and support tabs must all be present.")
    if not (practice_index < classroom_index < support_index):
        raise AssertionError("Class tab should be placed between practice and support.")

    assert_contains(classroom, "pendingAssignments", "Classroom view should distinguish pending assignments.")
    assert_contains(classroom, "completedAssignments", "Classroom view should show completed assignment history.")
    assert_contains(classroom, "startAssignedPracticeTask", "Classroom view should start teacher-assigned practice tasks.")
    assert_contains(
        classroom,
        "$0.status == .pending || $0.status == .active",
        "Classroom view should only treat pending/active assignments as work to do.",
    )
    assert_contains(
        classroom,
        "$0.status != .withdrawn",
        "Classroom view should hide withdrawn assignments.",
    )
    assert_contains(classroom, "目前沒有老師指派任務", "Classroom view should have a clear empty state.")

    assert_not_contains(home, "assignedPracticeTaskCard", "Student home should no longer own teacher assignment cards.")

    assert_not_contains(learning_map, "questionBankCard", "Learning map should not render the question bank card.")
    assert_not_contains(learning_map, "supportTimelineCard", "Learning map should not render the support timeline card.")

    assert_contains(project, "StudentClassroomView.swift in Sources", "Xcode project should compile StudentClassroomView.swift.")

    print("student classroom tab validation passed")


if __name__ == "__main__":
    main()
