#!/usr/bin/env python3
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
IOS_ROOT = ROOT / "ios" / "EnglishPlus" / "EnglishPlus"
PROJECT = ROOT / "ios" / "EnglishPlus" / "EnglishPlus.xcodeproj" / "project.pbxproj"
CI_POST_CLONE = ROOT / "ci_scripts" / "ci_post_clone.sh"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig")


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def git_ls_files() -> str:
    candidates = [
        "git",
        r"C:\Program Files\Git\cmd\git.exe",
        r"C:\Program Files\Git\bin\git.exe",
    ]
    for candidate in candidates:
        try:
            result = subprocess.run(
                [candidate, "ls-files"],
                cwd=ROOT,
                check=True,
                capture_output=True,
                text=True,
                encoding="utf-8",
            )
            return result.stdout
        except (FileNotFoundError, PermissionError, subprocess.CalledProcessError):
            continue
    return ""


def main() -> int:
    errors: list[str] = []
    paths = {
        "role_selection": IOS_ROOT / "Features" / "RoleSelection" / "RoleSelectionView.swift",
        "login": IOS_ROOT / "Features" / "RoleSelection" / "DemoLoginView.swift",
        "root": IOS_ROOT / "App" / "RootView.swift",
        "app_state": IOS_ROOT / "App" / "AppState.swift",
        "factory": IOS_ROOT / "Services" / "FirebaseAppConfigurator.swift",
        "auth": IOS_ROOT / "Services" / "AuthService.swift",
        "firebase_auth": IOS_ROOT / "Services" / "FirebaseAuthService.swift",
        "remote_ai": IOS_ROOT / "Services" / "RemoteAIService.swift",
        "student_home": IOS_ROOT / "Features" / "Student" / "StudentHomeView.swift",
        "practice": IOS_ROOT / "Features" / "Practice" / "PracticeCenterView.swift",
        "support": IOS_ROOT / "Features" / "Support" / "SupportView.swift",
        "teacher": IOS_ROOT / "Features" / "Teacher" / "TeacherHomeView.swift",
        "volunteer": IOS_ROOT / "Features" / "Volunteer" / "VolunteerHomeView.swift",
        "info": IOS_ROOT / "Info.plist",
        "project": PROJECT,
        "ci_post_clone": CI_POST_CLONE,
        "gitignore": ROOT / ".gitignore",
    }

    for name, path in paths.items():
        require(path.exists(), f"missing {name}: {path.relative_to(ROOT)}", errors)
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    text = {name: read(path) for name, path in paths.items()}
    tracked = git_ls_files()

    all_ios_text = "\n".join(
        body for key, body in text.items()
        if key not in {"ci_post_clone", "gitignore"}
    )

    for bad in ["�", "\ue000", "\uf8ff", "撌", "蝑", "瘜", "銵", "隞", "餈"]:
        require(bad not in all_ios_text, f"iOS user-visible/runtime source contains mojibake marker {bad!r}", errors)

    require("appState.chooseRole(role)" in text["role_selection"], "Role selection must choose a role first", errors)
    require("route = .demoLogin(role)" in text["app_state"], "Choosing a role must open the credential login route", errors)
    require("await appState.signIn(role: role)" not in text["role_selection"], "Role buttons must not skip login", errors)
    require("case .demoLogin(let role):" in text["root"] and "DemoLoginView(role: role)" in text["root"], "RootView must render credential login route", errors)
    require('title: "Email"' in text["login"], "Login screen must show an email field", errors)
    require('SecureField("至少 8 個字元"' in text["login"], "Login screen must show a password field", errors)
    require("登入後繼續你的每日任務" in text["login"], "Login copy must describe real account access", errors)
    require("不加入班級也能使用完整的個人學習功能" in text["login"], "Student registration must explain optional class membership", errors)
    require("本機展示帳號" not in text["login"], "Login copy must not promise local demo fallback", errors)
    require("authService.signIn(" in text["app_state"] and "expectedRole: role" in text["app_state"], "AppState must call credential AuthService sign-in", errors)
    require("Auth.auth().signIn(withEmail: email, password: password)" in text["firebase_auth"], "FirebaseAuthService must call Firebase Auth sign-in", errors)
    require("FirestorePath.member(classId: classId, uid: uid)" in text["firebase_auth"], "FirebaseAuthService must validate class membership by UID", errors)
    require("throw AuthServiceError.roleMismatch(expected: selectedRole, actual: primaryRole)" in text["firebase_auth"], "FirebaseAuthService must reject role mismatch", errors)

    require("GoogleService-Info.plist in Resources" in text["project"], "Xcode target must include GoogleService-Info.plist as a resource", errors)
    require("GOOGLE_SERVICE_INFO_PLIST_BASE64" in text["ci_post_clone"], "Xcode Cloud post-clone script must restore Firebase plist from an environment variable", errors)
    require("ios/**/GoogleService-Info*.plist" in text["gitignore"], "GoogleService-Info plist must stay ignored by git", errors)
    require("GoogleService-Info.plist" not in tracked, "GoogleService-Info.plist must not be committed", errors)

    require("RemoteAIService(" in text["factory"], "Service factory must use RemoteAIService in Firebase runtime", errors)
    require("CloudflareWorkerAiProxyTransport(" in text["factory"], "Service factory must wire Cloudflare Worker AI transport", errors)
    require("idTokenProvider: authService.currentIdToken" in text["factory"], "Remote AI calls must use Firebase ID token provider when available", errors)
    require("ENGLISHPLUS_AI_PROXY_URL" in text["info"], "Info.plist must define AI proxy endpoint", errors)
    require("https://englishplus-ai-proxy.englishplus-ray.workers.dev/ai" in text["info"], "Info.plist must point to the live Groq Cloudflare Worker endpoint", errors)
    for forbidden in ["GROQ_API_KEY", "https://api.groq.com", "gsk_", "OPENROUTER_API_KEY", "https://openrouter.ai", "cloudfunctions.net", "englishPlusAiProxy"]:
        require(forbidden not in all_ios_text, f"iOS app must not expose or call forbidden AI token/endpoint {forbidden}", errors)

    for token in [
        "開始心情檢測",
        "1. 今天的心情量表",
        "2. 今天有足夠的時間練習英文嗎？",
        "今天會想要挑戰更難的題目嗎？",
        "想要多練習哪幾種題型？",
        "generateDailyMissionWithAI",
        "aiResponse.output.mission",
        "答對才會增加進度",
        "explainWrongAnswerWithAI",
        "今日任務完成",
        "response.userFacingAvailabilityMessage",
        "appState.signOut()",
    ]:
        require(token in text["student_home"], f"StudentHomeView missing Windows parity token: {token}", errors)

    require("recommendPracticeWithAI" in text["practice"], "Practice center must expose AI practice recommendation", errors)
    require("explainWrongAnswerWithAI" in text["practice"], "Practice center must provide AI wrong-answer explanation", errors)
    require("AI 建議" in text["practice"], "Practice center must visibly show AI recommendation status", errors)
    require("SupportRequestInboxCard" in text["support"], "Support page must render the human reply inbox", errors)
    require("provideEmotionalSupportWithAI" not in text["support"], "Support page must not restore the removed standalone AI branch", errors)
    require("老師與志工的回覆會集中在這裡" in text["support"], "Support page must explain its reply-center purpose", errors)
    require("draftTeacherFeedbackWithAI" in text["teacher"], "Teacher request cards must support AI draft feedback", errors)
    require("coachVolunteerReplyWithAI" in text["volunteer"], "Volunteer task cards must support AI reply coaching", errors)
    require("appState.signOut()" in text["teacher"], "Teacher home must expose sign out for login verification", errors)
    require("appState.signOut()" in text["volunteer"], "Volunteer home must expose sign out for login verification", errors)

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print("iOS Windows parity runtime validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
