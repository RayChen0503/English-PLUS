#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
VOLUNTEER_HOME = ROOT / "ios" / "EnglishPlus" / "EnglishPlus" / "Features" / "Volunteer" / "VolunteerHomeView.swift"
VOLUNTEER_SHELL = ROOT / "ios" / "EnglishPlus" / "EnglishPlus" / "Features" / "Volunteer" / "VolunteerShellView.swift"
SUPPORT_VIEW = ROOT / "ios" / "EnglishPlus" / "EnglishPlus" / "Features" / "Support" / "SupportView.swift"
STORE = ROOT / "ios" / "EnglishPlus" / "EnglishPlus" / "Services" / "LearningRepositoryStore.swift"
MOCK_REPOSITORY = ROOT / "ios" / "EnglishPlus" / "EnglishPlus" / "Services" / "MockLearningRepository.swift"
FIREBASE_REPOSITORY = ROOT / "ios" / "EnglishPlus" / "EnglishPlus" / "Services" / "FirebaseLearningRepository.swift"


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def main() -> int:
    errors: list[str] = []
    for path in [VOLUNTEER_HOME, VOLUNTEER_SHELL, SUPPORT_VIEW, STORE, MOCK_REPOSITORY, FIREBASE_REPOSITORY]:
        require(path.exists(), f"missing file: {path.relative_to(ROOT)}", errors)

    if errors:
        for error in errors:
            print(error)
        return 1

    volunteer_home = read(VOLUNTEER_HOME)
    volunteer_shell = read(VOLUNTEER_SHELL)
    support_view = read(SUPPORT_VIEW)
    store = read(STORE)
    mock_repository = read(MOCK_REPOSITORY)
    firebase_repository = read(FIREBASE_REPOSITORY)

    required_shell_tokens = [
        'Label("今日", systemImage: "heart.text.square")',
        'Label("接力", systemImage: "flag")',
        'Label("紀錄", systemImage: "list.bullet.rectangle")',
    ]
    for token in required_shell_tokens:
        require(token in volunteer_shell, f"Volunteer shell missing focused tab token: {token}", errors)

    forbidden_shell_tokens = [
        'Label("學生"',
        'Label("腳本"',
        "VolunteerStudentBriefsView()",
        "VolunteerScriptView()",
    ]
    for token in forbidden_shell_tokens:
        require(token not in volunteer_shell, f"Volunteer shell still exposes separated non-flow tab: {token}", errors)

    required_volunteer_tokens = [
        "VolunteerHandoffWorkspaceView",
        "VolunteerQueuePickerCard",
        "VolunteerSelectedSupportPanel",
        "VolunteerQuestionContextCard",
        "VolunteerReplyComposerCard",
        "VolunteerCompanionScriptCard",
        "selectedRequestId",
        "selectedRequest",
        "learningRepository.addVolunteerReply(to: request.id, body: replyDraft)",
        "appState.coachVolunteerReplyWithAI(context: SupportAIContext(request: request))",
        "送出後學生會在支援紀錄看到",
        "先接住，再陪一題",
        "SupportQuestionSnapshotCard",
        "學生答案與正解",
    ]
    for token in required_volunteer_tokens:
        require(token in volunteer_home, f"Volunteer handoff flow missing token: {token}", errors)

    required_support_tokens = [
        "志工陪伴",
        "老師/志工回覆",
        "visibleReplies",
        "markSupportThreadReadByStudent",
    ]
    for token in required_support_tokens:
        require(token in support_view, f"Student support inbox missing volunteer-visible reply token: {token}", errors)

    required_store_tokens = [
        "visibleVolunteerReplies",
        "request.status == .waitingForStaff || request.status == .open",
    ]
    for token in required_store_tokens:
        require(token in store, f"Repository missing volunteer queue token: {token}", errors)

    required_backend_tokens = [
        "supportRequests[index].replies.append(reply)",
        "supportRequests[index].status = .replied",
        "supportRequests[index].updatedAt = date",
        "appendSupportReply(",
        "authorRole: .volunteer",
    ]
    backend_text = mock_repository + firebase_repository
    for token in required_backend_tokens:
        require(token in backend_text, f"Repository backend missing volunteer reply persistence token: {token}", errors)

    forbidden_copy_tokens = [
        "志工端只顯示陪伴所需資訊，不顯示老師的班級管理與評分資料。",
        "可以直接照著說，也可以改成自己的語氣。",
    ]
    for token in forbidden_copy_tokens:
        require(token not in volunteer_home, f"Volunteer flow still contains detached explanatory copy: {token}", errors)

    if errors:
        for error in errors:
            print(error)
        return 1

    print("volunteer handoff round 5 contract passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
