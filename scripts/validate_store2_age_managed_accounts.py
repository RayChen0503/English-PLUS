from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(path: str, snippets: list[str]) -> list[str]:
    content = read(path)
    return [f"{path}: missing {snippet}" for snippet in snippets if snippet not in content]


errors: list[str] = []
errors += require(
    "ios/EnglishPlus/EnglishPlus/Models/IdentityModels.swift",
    [
        "case managedStudent",
        "enum StudentAccountAccessPath",
        "case age13OrOlder",
        "case schoolOrGuardianManaged",
        "case under13NeedsManagedAccount",
        "studentAccessPath == .age13OrOlder",
    ],
)
errors += require(
    "ios/EnglishPlus/EnglishPlus/Features/RoleSelection/DemoLoginView.swift",
    [
        "學生帳號使用資格",
        "未滿 13 歲不可自行建立公開帳號",
        "auth.student.ageEligibility",
        "studentRegistrationEligibility?.accessPath",
        "studentAccessPath: profile.studentAccessPath",
    ],
)
errors += require(
    "ios/EnglishPlus/EnglishPlus/Services/FirebaseAuthService.swift",
    [
        '"studentAccessPath": profile.studentAccessPath.rawValue',
        'userData["studentAccessPath"]',
    ],
)
errors += require(
    "ios/EnglishPlus/EnglishPlus/Models/PrivacyConsent.swift",
    [
        'currentVersion = "privacy-v3-2026-07-16"',
        "let studentAccessPath: StudentAccountAccessPath",
    ],
)
errors += require(
    "docs/ios-testflight/firebase/firestore.rules.draft",
    [
        'profile.studentAccessPath == "age13OrOlder"',
        'profile.provisioningSource == "managedStudent"',
        "validConsentRecord(uid, request.resource.data)",
    ],
)
errors += require(
    "firebase-tests/test/round8-firestore-contract.test.js",
    [
        "public student registration enforces the 13+ path and rejects managed forgery",
        "consent access path must match the authenticated profile",
    ],
)
errors += require(
    "docs/app-store-release/store-2-age-managed-accounts.md",
    ["Full Firestore suite: `40/40`", "No remote deployment"],
)

if errors:
    raise SystemExit("\n".join(f"ERROR: {error}" for error in errors))

print("STORE-2 age and managed-account gate passed")
