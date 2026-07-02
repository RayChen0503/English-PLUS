from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(text: str, marker: str, label: str) -> None:
    if marker not in text:
        raise AssertionError(f"Missing {label}: {marker}")


def main() -> int:
    home = read("ios/EnglishPlus/EnglishPlus/Features/Student/StudentHomeView.swift")
    shell = read("ios/EnglishPlus/EnglishPlus/Features/Student/StudentShellView.swift")
    learning_map = read("ios/EnglishPlus/EnglishPlus/Features/Student/StudentLearningMapView.swift")
    practice = read("ios/EnglishPlus/EnglishPlus/Features/Practice/PracticeCenterView.swift")

    for marker in [
        "learningRepository.learningFlow.stage",
        "case .needsCheckIn",
        "case .missionActive",
        "case .missionCompleted",
        "case .freePractice",
        "LearningFlowStatusCard",
        "continueLearningFlow()",
        "startNewLearningRound(",
        "enterFreePracticeMode()",
        "returnToMissionFlow()",
        "missionCompletionActions",
    ]:
        require(home, marker, "student home flow UI")

    for marker in [
        "learningRepository.learningFlow",
        "LearningFlowStage",
        "flowStageTitle",
        "flowStageDetail",
        "continueLearningFlow()",
        "startNewLearningRound(",
        "enterFreePracticeMode()",
    ]:
        require(learning_map, marker, "student learning map flow UI")

    for marker in [
        "@State private var selectedTab",
        "TabView(selection: $selectedTab)",
        ".tag(StudentTab.practice)",
        ".onChange(of: selectedTab)",
        "learningRepository.enterFreePracticeMode()",
    ]:
        require(shell, marker, "student shell free practice navigation state")

    if "freePracticeModeMarker" in practice:
        raise AssertionError("PracticeCenterView should not hide flow-state changes in an invisible marker")

    print("iOS learning flow round 2 UI contract passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
