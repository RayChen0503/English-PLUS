#!/usr/bin/env python3
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
IOS_ROOT = ROOT / "ios" / "EnglishPlus" / "EnglishPlus"


FILES = {
    "app_state": IOS_ROOT / "App" / "AppState.swift",
    "app_route": IOS_ROOT / "App" / "AppRoute.swift",
    "root_view": IOS_ROOT / "App" / "RootView.swift",
    "auth_service": IOS_ROOT / "Services" / "AuthService.swift",
    "mock_auth": IOS_ROOT / "Services" / "MockAuthService.swift",
    "firestore_service": IOS_ROOT / "Services" / "FirestoreService.swift",
    "mock_firestore": IOS_ROOT / "Services" / "MockFirestoreService.swift",
    "consent_model": IOS_ROOT / "Models" / "PrivacyConsent.swift",
    "consent_view": IOS_ROOT / "Features" / "Consent" / "ConsentView.swift",
    "firestore_path": IOS_ROOT / "Data" / "FirestorePath.swift",
    "firestore_schema": IOS_ROOT / "Models" / "FirestoreSchema.swift",
    "rules": ROOT / "docs" / "ios-testflight" / "firebase" / "firestore.rules.draft",
    "gitignore": ROOT / ".gitignore",
}


def require(condition, message, errors):
    if not condition:
        errors.append(message)


def text(key):
    return FILES[key].read_text(encoding="utf-8")


def validate_files(errors):
    for name, path in FILES.items():
        require(path.exists(), f"missing {name}: {path.relative_to(ROOT)}", errors)


def validate_auth_and_firestore_interfaces(errors):
    auth = text("auth_service")
    mock_auth = text("mock_auth")
    firestore = text("firestore_service")
    mock_firestore = text("mock_firestore")

    for token in ["AuthSession", "demoSession(for role: UserRole)", "AppUserProfile"]:
        require(token in auth, f"AuthService missing {token}", errors)
    for token in ["SeedData.demoAccount", "FirebaseBackendConfig.firstClassId"]:
        require(token in mock_auth, f"MockAuthService missing {token}", errors)
    for token in ["protocol FirestoreService", "saveConsent", "consentRecord", "hasAcceptedRequiredConsent"]:
        require(token in firestore, f"FirestoreService missing {token}", errors)
    for token in ["PrivacyConsentRecord", "currentVersion", "consentRecords"]:
        require(token in mock_firestore, f"MockFirestoreService missing {token}", errors)


def validate_consent_flow(errors):
    app_state = text("app_state")
    app_route = text("app_route")
    root_view = text("root_view")
    consent_model = text("consent_model")
    consent_view = text("consent_view")

    for token in [
        "case privacyConsent(UserRole)",
        "ConsentView(role: role)",
        "acceptPrivacyConsent",
        "firestoreService.hasAcceptedRequiredConsent",
        "PrivacyConsentRecord.accepted",
    ]:
        combined = "\n".join([app_state, app_route, root_view])
        require(token in combined, f"app consent routing missing {token}", errors)

    save_index = app_state.find("try await firestoreService.saveConsent(record)")
    accept_index = app_state.find("hasAcceptedConsent = true", save_index)
    route_index = app_state.find("route = .home(currentUser.role)", accept_index)
    require(
        -1 < save_index < accept_index < route_index,
        "consent acceptance should move to home only after confirmed saving",
        errors,
    )
    require("hasAcceptedConsent = true\n        route = .home(selectedRole)" not in app_state, "demo login must not auto-accept consent", errors)
    for token in [
        "PrivacyConsentCategory",
        "currentVersion = \"privacy-v3-2026-07-16\"",
        "GuardianConsentStatus",
        "ConsentSource",
        "primaryAgreement",
        "aiAgreement(for role:",
    ]:
        require(token in consent_model, f"PrivacyConsent model missing {token}", errors)
    for token in ["acceptsPrivacy", "acceptsMoodAndAi", "我了解並繼續", "checkmark.square.fill"]:
        require(token in consent_view, f"ConsentView missing {token}", errors)


def validate_firestore_contract(errors):
    path = text("firestore_path")
    schema = text("firestore_schema")
    rules = text("rules")

    for token in [
        "userConsent(uid:",
        "studentConsent(classId:",
        "deletionRequest(classId:",
        "privacyAuditLog(classId:",
    ]:
        require(token in path, f"FirestorePath missing {token}", errors)

    for token in [
        "FirestoreConsentDocument",
        "FirestoreDeletionRequestDocument",
        "FirestorePrivacyAuditLogDocument",
        "DeletionRequestStatus",
        "DeletionRequestScope",
    ]:
        require(token in schema, f"FirestoreSchema missing {token}", errors)

    for token in [
        "match /consents/{consentVersion}",
        "match /deletionRequests/{requestId}",
        "match /aiUsage/{usageId}",
        "match /aiEvents/{eventId}",
        "match /privacyAuditLogs/{eventId}",
        "validConsentRecord(uid, request.resource.data)",
        "request.resource.data.status == \"requested\"",
    ]:
        require(token in rules, f"firestore rules missing {token}", errors)


def validate_config_safety(errors):
    gitignore = text("gitignore")
    require("ios/**/GoogleService-Info.plist" in gitignore, ".gitignore must protect GoogleService-Info.plist", errors)
    require(not list(ROOT.glob("**/GoogleService-Info.plist")), "GoogleService-Info.plist must not be committed yet", errors)


def main():
    errors = []
    validate_files(errors)
    if not errors:
        validate_auth_and_firestore_interfaces(errors)
        validate_consent_flow(errors)
        validate_firestore_contract(errors)
        validate_config_safety(errors)

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print("Round 6 Firebase privacy contract validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
