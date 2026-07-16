from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative_path: str) -> str:
    return (ROOT / relative_path).read_text(encoding="utf-8")


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def main() -> int:
    errors: list[str] = []

    auth_contract = read("ios/EnglishPlus/EnglishPlus/Services/AuthService.swift")
    firebase_auth = read("ios/EnglishPlus/EnglishPlus/Services/FirebaseAuthService.swift")
    coordinator = read("ios/EnglishPlus/EnglishPlus/Services/FederatedSignInCoordinator.swift")
    account_view = read("ios/EnglishPlus/EnglishPlus/Features/Shared/AccountDataView.swift")
    repository_contracts = read(
        "ios/EnglishPlus/EnglishPlus/Services/LearningRepositoryContracts.swift"
    )
    repository_store = read(
        "ios/EnglishPlus/EnglishPlus/Services/LearningRepositoryStore.swift"
    )
    firebase_repository = read(
        "ios/EnglishPlus/EnglishPlus/Services/FirebaseLearningRepository.swift"
    )
    support_view = read("ios/EnglishPlus/EnglishPlus/Features/Support/SupportView.swift")
    root_view = read("ios/EnglishPlus/EnglishPlus/App/RootView.swift")

    require(
        "reauthenticateAndRevokeAppleToken" in auth_contract,
        "AuthService must expose Apple deletion reauthentication/revocation",
        errors,
    )
    require(
        "Auth.auth().revokeToken(" in firebase_auth
        and "withAuthorizationCode: credential.authorizationCode" in firebase_auth,
        "FirebaseAuthService must revoke the Apple authorization code",
        errors,
    )
    require(
        "authorizationCode" in coordinator and "appleAccountDeletionCredential" in coordinator,
        "Apple deletion credential must retain the authorization code",
        errors,
    )
    require(
        "SignInWithAppleButton" in account_view
        and "hasRevokedAppleAuthorization" in account_view,
        "Apple-linked deletion must be gated by in-app reauthentication",
        errors,
    )

    require(
        "enum SupportContentPolicy" in repository_contracts
        and "maximumCharacterCount = 1_200" in repository_contracts,
        "Support content must have a centralized length/safety policy",
        errors,
    )
    for operation in (
        "sendSupportRequest",
        "sendQuestionSupportRequest",
        "addTeacherReply",
        "addVolunteerReply",
    ):
        require(
            operation in repository_store and operation in firebase_repository,
            f"{operation} must exist in both store and Firebase boundary",
            errors,
        )
    require(
        "validatedRequired" in repository_store
        and "validatedRequired" in firebase_repository,
        "Support content policy must be enforced in the store and Firebase boundary",
        errors,
    )
    require(
        "檢舉這則回覆" in support_view and "封鎖這位回覆者" in support_view,
        "Student support replies must expose report and block controls",
        errors,
    )
    require(
        ".overlay(alignment: .top)" in root_view
        and ".safeAreaInset(edge: .top" not in root_view,
        "Sync status must not resize the active screen",
        errors,
    )

    if errors:
        print("App Store account deletion / UGC gate failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("App Store account deletion / UGC gate passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
