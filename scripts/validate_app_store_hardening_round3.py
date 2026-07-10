from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def main() -> int:
    errors: list[str] = []
    auth_contract = read("ios/EnglishPlus/EnglishPlus/Services/AuthService.swift")
    firebase_auth = read("ios/EnglishPlus/EnglishPlus/Services/FirebaseAuthService.swift")
    app_state = read("ios/EnglishPlus/EnglishPlus/App/AppState.swift")
    login = read("ios/EnglishPlus/EnglishPlus/Features/RoleSelection/DemoLoginView.swift")
    root_view = read("ios/EnglishPlus/EnglishPlus/App/RootView.swift")
    schema = read("ios/EnglishPlus/EnglishPlus/Models/FirestoreSchema.swift")
    rules = read("docs/ios-testflight/firebase/firestore.rules.draft")

    require("enum AccountCreationOutcome" in auth_contract,
            "Account creation must represent verification-required state.", errors)
    require("func sendPasswordReset(email:" in auth_contract,
            "Auth contract must support password reset.", errors)
    require("func resendVerification(email:" in auth_contract,
            "Auth contract must support resending verification.", errors)
    require("case staffSelfServiceUnavailable" in auth_contract,
            "Staff self-service registration must be rejected explicitly.", errors)

    for marker in (
        "sendPasswordReset(withEmail:",
        "sendEmailVerification",
        "isEmailVerified",
        '"emailVerificationRequired": true',
        '"provisioningSource": "selfServiceStudent"',
        "AuthErrorCode(rawValue:",
    ):
        require(marker in firebase_auth, f"Missing Firebase auth marker: {marker}", errors)

    require("guard role == .student" in firebase_auth,
            "Only students may use self-service account creation.", errors)
    require("try? Auth.auth().signOut()" in firebase_auth,
            "Rejected or unverified sessions must be signed out.", errors)

    for marker in (
        "func sendPasswordReset(email:",
        "func resendVerification(email:",
        "authNoticeMessage",
        "verificationEmailAddress",
        "userMessage(for error:",
    ):
        require(marker in app_state, f"Missing AppState auth UX marker: {marker}", errors)

    require('_email = State(initialValue: "")' in login,
            "Release login must not prefill a demo email.", errors)
    require('_password = State(initialValue: "")' in login,
            "Release login must not prefill a demo password.", errors)
    require("忘記密碼？" in login and "重新寄送驗證信" in login,
            "Login UI must expose account recovery actions.", errors)
    require("老師與志工帳號由管理者核發" in login,
            "Staff provisioning copy must be user-facing and explicit.", errors)
    require("Firebase" not in login and "測試帳號" not in login,
            "Role-facing login UI must not expose implementation/test language.", errors)
    require("password.count < 8" in login,
            "New student password validation must use the Round 3 minimum.", errors)

    require("restoreSessionIfPossible" not in root_view,
            "Cold launch must keep explicit role selection and sign-in.", errors)
    require("enum AccountProvisioningStatus" in schema,
            "Firestore schema must model account provisioning status.", errors)
    require("struct FirestoreStaffInvitationDocument" in schema,
            "Firestore schema must define server-managed staff invitations.", errors)
    require("match /staffInvitations/{invitationId}" in rules,
            "Rules must include the staff invitation boundary.", errors)
    require("allow read, write: if false;" in rules,
            "Staff invitations must remain server-only.", errors)
    require("emailVerificationRequired == true" in rules,
            "Self-service student profiles must require verified email.", errors)
    require('request.resource.data.keys().hasOnly([' in rules,
            "Self-service profiles must use an explicit field allowlist.", errors)
    update_marker = "allow update: if hasAccountAccess(uid)"
    user_update_section = ""
    if update_marker in rules:
        user_update_section = rules.split(update_marker, 1)[1].split(
            "allow delete: if false;", 1
        )[0]
    require(update_marker in rules and '"active"' not in user_update_section,
            "Users must not be able to reactivate their own accounts.", errors)
    require("hasAccountAccess" in rules and "email_verified" in rules,
            "Protected data must require an active, verified account.", errors)

    if errors:
        print("Round 3 hardening validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("Round 3 hardening validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
