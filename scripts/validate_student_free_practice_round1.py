from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require_markers(label: str, text: str, markers: list[str]) -> None:
    missing = [marker for marker in markers if marker not in text]
    assert not missing, f"Missing {label}: {missing}"


def require_absent(label: str, text: str, markers: list[str]) -> None:
    present = [marker for marker in markers if marker in text]
    assert not present, f"Forbidden {label}: {present}"


practice_center = read("ios/EnglishPlus/EnglishPlus/Features/Practice/PracticeCenterView.swift")


require_markers(
    "finite free-practice session controls",
    practice_center,
    [
        "freePracticeSessionLimit",
        "startFreePracticeSession()",
        "finishFreePracticeSession()",
        "isFreePracticeSessionComplete",
        "freePracticeSessionItems",
        "FreePracticeSessionSummaryCard",
    ],
)

require_markers(
    "student-visible free-practice ending",
    practice_center,
    [
        "ProgressView(value: freePracticeProgressFraction)",
        "完成這組練習",
        "再練一組",
        "回今日任務",
    ],
)

require_absent(
    "infinite wraparound practice navigation",
    practice_center,
    [
        "practiceIndex = (practiceIndex + 1) % filteredPracticeItems.count",
    ],
)

print("student free-practice round 1 finite session contract passed")
