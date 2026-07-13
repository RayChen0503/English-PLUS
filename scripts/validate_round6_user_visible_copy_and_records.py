from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FEATURES = ROOT / "ios" / "EnglishPlus" / "EnglishPlus" / "Features"
MODELS = ROOT / "ios" / "EnglishPlus" / "EnglishPlus" / "Models"


def fail(message: str) -> None:
    raise AssertionError(message)


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def main() -> None:
    checked_files = [
        path
        for path in FEATURES.rglob("*.swift")
        if "Diagnostics" not in path.parts
        and "Consent" not in path.parts
        and path.name != "AccountDataView.swift"
    ]
    checked_files.append(MODELS / "LearningModels.swift")

    forbidden_user_visible_terms = [
        "Firestore",
        "OpenRouter",
        "Groq",
        "Cloudflare",
        "cloudfunctions.net",
        "workers.dev",
        "API Key",
        "GROQ",
        "本機",
        "接上 Firestore",
        "可同步",
        "뎁뱄",
        "�",
        "?",
    ]

    violations: list[str] = []
    for path in checked_files:
        source = read(path)
        for term in forbidden_user_visible_terms:
            if term in source:
                violations.append(f"{path.relative_to(ROOT)} contains forbidden user-visible term: {term}")

    if violations:
        fail("\n".join(violations))

    volunteer_shell = read(FEATURES / "Volunteer" / "VolunteerShellView.swift")
    volunteer_home = read(FEATURES / "Volunteer" / "VolunteerHomeView.swift")
    learning_models = read(MODELS / "LearningModels.swift")

    if 'Label("同步"' in volunteer_shell:
        fail("Volunteer bottom tab still exposes a technical sync label.")
    if 'Label("紀錄"' not in volunteer_shell:
        fail("Volunteer bottom tab should expose a user-facing record label.")
    if "struct VolunteerSyncView" in volunteer_home:
        fail("Volunteer record screen should not be named or framed as a sync screen.")
    if "struct VolunteerRecordView" not in volunteer_home:
        fail("Volunteer record screen is missing.")
    if "VolunteerRecordStatusCard" not in volunteer_home:
        fail("Volunteer record status card is missing.")
    if "目前沒有志工回覆紀錄" not in volunteer_home:
        fail("Volunteer record screen needs a clear empty state.")
    if 'return "已完成 \\(correctCount) / \\(targetCorrectCount)"' not in learning_models:
        fail("Student progress text should be readable and explicit.")

    print("round6 user-visible copy and volunteer records validation passed")


if __name__ == "__main__":
    main()
