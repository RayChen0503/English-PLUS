#!/usr/bin/env python3
import importlib.util
import json
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def validate_catalog_builder(errors: list[str]) -> None:
    script_path = ROOT / "scripts/build_taiwan_education_institution_catalog.py"
    spec = importlib.util.spec_from_file_location("institution_catalog", script_path)
    if spec is None or spec.loader is None:
        errors.append("Institution catalog builder cannot be imported.")
        return
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)

    with tempfile.TemporaryDirectory() as directory:
        source_path = Path(directory) / "schools.csv"
        source_path.write_text(
            "代碼,學校名稱,縣市名稱,行政區\n"
            "014501,English Plus Junior High,宜蘭縣,宜蘭市\n",
            encoding="utf-8-sig",
        )
        source = module.SourceSpec("juniorHigh", source_path, "6088", "114")
        catalog = module.build_catalog([source])
        require(len(catalog) == 1, "Catalog builder did not emit one school.", errors)
        if catalog:
            require(catalog[0]["id"] == "moe-014501", "School ID is not stable.", errors)
            require(
                catalog[0]["source"] == "ministryOfEducation",
                "Official school source was not preserved.",
                errors,
            )


def main() -> int:
    errors: list[str] = []
    identity = read("ios/EnglishPlus/EnglishPlus/Models/IdentityModels.swift")
    auth_contract = read("ios/EnglishPlus/EnglishPlus/Services/AuthService.swift")
    firebase_auth = read("ios/EnglishPlus/EnglishPlus/Services/FirebaseAuthService.swift")
    mock_auth = read("ios/EnglishPlus/EnglishPlus/Services/MockAuthService.swift")
    app_state = read("ios/EnglishPlus/EnglishPlus/App/AppState.swift")
    schema = read("ios/EnglishPlus/EnglishPlus/Models/FirestoreSchema.swift")
    paths = read("ios/EnglishPlus/EnglishPlus/Data/FirestorePath.swift")
    rules = read("docs/ios-testflight/firebase/firestore.rules.draft")
    project = read("ios/EnglishPlus/EnglishPlus.xcodeproj/project.pbxproj")
    decisions = read("docs/app-store-hardening/DECISIONS.md")
    state = read("docs/app-store-hardening/CURRENT_STATE.md")
    report = read("docs/app-store-hardening/round-03-multi-provider-role-onboarding.md")
    sources = json.loads(
        read("docs/app-store-hardening/education-institution-sources.json")
    )

    for marker in (
        "case emailPassword",
        "case google",
        "case apple",
        "struct AccountRegistration",
        "struct RoleOnboardingProfile",
        "struct TeacherAffiliation",
        "case selfDeclared",
        "struct VolunteerApplicationInput",
        "case pendingReview",
        "confirmsAge18OrOlder",
        "struct EducationInstitutionDirectory",
        "normalizedText.count >= 2",
        "prefix(limit)",
    ):
        require(marker in identity, f"Identity domain missing marker: {marker}", errors)

    for marker in (
        "func createAccount(_ registration: AccountRegistration)",
        "with credential: FederatedIdentityCredential",
        "profile: RoleOnboardingProfile",
        "func linkIdentity(",
        "case approvalPending",
        "case missingTeacherAffiliation",
        "case invalidVolunteerApplication",
    ):
        require(marker in auth_contract, f"Auth contract missing marker: {marker}", errors)

    for marker in (
        "registration.hasRequiredRoleDetails",
        "case .teacher:",
        "case .volunteer:",
        "? .pendingApproval",
        "provisioningSource = .selfServiceTeacher",
        "provisioningSource = .selfServiceVolunteer",
        "FirestorePath.teacherProfile(uid: uid)",
        "FirestorePath.volunteerApplication(uid: uid)",
        "VolunteerApplicationStatus.pendingReview.rawValue",
        "let batch = firestore.batch()",
        "try await commit(batch)",
    ):
        require(marker in firebase_auth, f"Firebase registration missing: {marker}", errors)
    require(
        "guard role == .student" not in firebase_auth,
        "Firebase registration still blocks all teacher and volunteer applications.",
        errors,
    )
    require(
        "registration.role == .volunteer" in mock_auth
        and ".approvalPending(email: cleanedEmail, role: .volunteer)" in mock_auth,
        "Fallback auth does not preserve volunteer pending state.",
        errors,
    )
    require(
        "func createAccount(_ registration: AccountRegistration)" in app_state,
        "AppState has no full registration entry point for Round 4 UI.",
        errors,
    )

    for marker in (
        "FirestoreTeacherProfileDocument",
        "FirestoreVolunteerApplicationDocument",
        "identityProviders: [AccountIdentityProvider]",
        "provisioningSource: AccountProvisioningSource",
    ):
        require(marker in schema, f"Firestore schema missing marker: {marker}", errors)
    for marker in (
        "educationInstitution(institutionId:",
        "teacherProfile(uid:",
        "volunteerApplication(uid:",
    ):
        require(marker in paths, f"Firestore path missing marker: {marker}", errors)

    for marker in (
        "validSelfServiceProfile(profile)",
        'profile.provisioningSource == "selfServiceStudent"',
        'profile.provisioningSource == "selfServiceTeacher"',
        'profile.provisioningSource == "selfServiceVolunteer"',
        'profile.accountStatus in ["pendingApplication", "pendingApproval"]',
        "match /educationInstitutions/{institutionId}",
        "match /teacherProfiles/{uid}",
        'request.resource.data.claimStatus == "selfDeclared"',
        "match /volunteerApplications/{uid}",
        'request.resource.data.status == "pendingReview"',
        "request.resource.data.confirmsAge18OrOlder == true",
        '"identityProviders"',
    ):
        require(marker in rules, f"Firestore rules missing marker: {marker}", errors)
    require(
        'profile.primaryRole == "volunteer"\n          && profile.active == false'
        in rules,
        "A self-service volunteer can become active without review.",
        errors,
    )

    require(
        project.count("IdentityModels.swift") >= 3,
        "IdentityModels.swift is not fully included in the Xcode project.",
        errors,
    )
    require(
        {item["datasetId"] for item in sources["sources"]}
        >= {"6087", "6088", "6089", "162568"},
        "Official school source register is incomplete.",
        errors,
    )

    for marker in (
        "Google + Apple + Email/password",
        "Teacher self-registration",
        "Volunteer self-application",
        "3/20",
    ):
        require(
            marker in decisions + state + report,
            f"Round 3 documentation missing marker: {marker}",
            errors,
        )
    require(
        "Production identity uses email/password only in Round 3. Superseded by D-09."
        in decisions,
        "The historical Email-only decision is not explicitly superseded.",
        errors,
    )

    validate_catalog_builder(errors)

    if errors:
        print("Round 3 multi-provider onboarding validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("Round 3 multi-provider onboarding validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
