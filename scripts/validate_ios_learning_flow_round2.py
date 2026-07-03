from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(text: str, marker: str, label: str) -> None:
    if marker not in text:
        raise AssertionError(f"Missing {label}: {marker}")


def reject(text: str, marker: str, label: str) -> None:
    if marker in text:
        raise AssertionError(f"Unexpected {label}: {marker}")


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
        "enterFreePracticeMode()",
        "returnToMissionFlow()",
        "onOpenPractice()",
        "openFreePractice()",
        "前往自由練習",
        "Label(\"自由練習\"",
        "missionCompletionActions",
    ]:
        require(home, marker, "student home flow UI")

    reject(home, "startNewLearningRound(", "home-level recheck action")
    reject(home, "Label(\"重新檢測\"", "home recheck button")
    reject(home, "Label(\"再跑一輪\"", "home rerun button")

    for marker in [
        "learningRepository.learningFlow",
        "LearningFlowStage",
        "flowStageTitle",
        "flowStageDetail",
        "startNewLearningRound(",
        "onOpenHome()",
        "Label(\"重新檢測\"",
    ]:
        require(learning_map, marker, "student learning map flow UI")

    reject(learning_map, "Label(\"自由練習\"", "learning map free-practice CTA")
    reject(learning_map, "continueLearningFlow()", "learning map continuation CTA")

    for marker in [
        "@State private var selectedTab",
        "TabView(selection: $selectedTab)",
        "onOpenPractice:",
        "selectedTab = .practice",
        "onOpenHome:",
        "selectedTab = .home",
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
