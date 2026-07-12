#!/usr/bin/env python3
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def require_markers(
    content: str,
    markers: tuple[str, ...],
    label: str,
    errors: list[str],
) -> None:
    for marker in markers:
        require(marker in content, f"{label} missing marker: {marker}", errors)


def main() -> int:
    errors: list[str] = []
    project = read("ios/EnglishPlus/EnglishPlus.xcodeproj/project.pbxproj")
    entitlements = read("ios/EnglishPlus/EnglishPlus/EnglishPlus.entitlements")
    login = read("ios/EnglishPlus/EnglishPlus/Features/RoleSelection/DemoLoginView.swift")
    institution_picker = read(
        "ios/EnglishPlus/EnglishPlus/Features/RoleSelection/InstitutionPickerView.swift"
    )
    application_view = read(
        "ios/EnglishPlus/EnglishPlus/Features/Volunteer/VolunteerApplicationView.swift"
    )
    review_view = read(
        "ios/EnglishPlus/EnglishPlus/Features/Teacher/VolunteerReviewView.swift"
    )
    coordinator = read(
        "ios/EnglishPlus/EnglishPlus/Services/FederatedSignInCoordinator.swift"
    )
    firebase_auth = read(
        "ios/EnglishPlus/EnglishPlus/Services/FirebaseAuthService.swift"
    )
    evidence_service = read(
        "ios/EnglishPlus/EnglishPlus/Services/EvidenceUploadService.swift"
    )
    review_service = read(
        "ios/EnglishPlus/EnglishPlus/Services/VolunteerReviewService.swift"
    )
    app_state = read("ios/EnglishPlus/EnglishPlus/App/AppState.swift")
    teacher_shell = read(
        "ios/EnglishPlus/EnglishPlus/Features/Teacher/TeacherShellView.swift"
    )
    worker = read("workers/englishplus-ai-proxy/src/index.js")
    wrangler = read("workers/englishplus-ai-proxy/wrangler.toml")
    worker_package = json.loads(read("workers/englishplus-ai-proxy/package.json"))
    package_resolved = json.loads(
        read(
            "ios/EnglishPlus/EnglishPlus.xcodeproj/project.xcworkspace/"
            "xcshareddata/swiftpm/Package.resolved"
        )
    )
    rules = read("docs/ios-testflight/firebase/firestore.rules.draft")
    root_ci = read("ci_scripts/ci_post_clone.sh")
    ios_ci = read("ios/EnglishPlus/ci_scripts/ci_post_clone.sh")
    state = read("docs/app-store-hardening/CURRENT_STATE.md")
    decisions = read("docs/app-store-hardening/DECISIONS.md")
    report = read(
        "docs/app-store-hardening/round-04-provider-ui-private-volunteer-review.md"
    )
    manifest = json.loads(
        read("ios/EnglishPlus/EnglishPlus/Resources/SeedData/seed_manifest.json")
    )
    catalog = json.loads(
        read(
            "ios/EnglishPlus/EnglishPlus/Resources/SeedData/education_institutions_seed.json"
        )
    )

    require_markers(
        project,
        (
            'repositoryURL = "https://github.com/google/GoogleSignIn-iOS";',
            "minimumVersion = 9.1.0;",
            "GoogleSignIn in Frameworks",
            "GoogleSignInSwift in Frameworks",
            "CODE_SIGN_ENTITLEMENTS = EnglishPlus/EnglishPlus.entitlements;",
            "com.apple.SignInWithApple",
            "FederatedSignInCoordinator.swift in Sources",
            "InstitutionPickerView.swift in Sources",
            "VolunteerApplicationView.swift in Sources",
            "VolunteerReviewView.swift in Sources",
        ),
        "Xcode project",
        errors,
    )
    require("com.apple.developer.applesignin" in entitlements, "Apple sign-in entitlement missing.", errors)

    package_pins = {
        pin.get("identity"): pin.get("state", {})
        for pin in package_resolved.get("pins", [])
    }
    expected_provider_pins = {
        "appauth-ios": "2.0.0",
        "googlesignin-ios": "9.1.0",
        "gtmappauth": "5.0.0",
        "gtm-session-fetcher": "3.5.0",
    }
    for identity, version in expected_provider_pins.items():
        require(
            package_pins.get(identity, {}).get("version") == version,
            f"Package.resolved missing compatible {identity} {version} pin.",
            errors,
        )

    require_markers(
        coordinator,
        (
            "GIDSignIn.sharedInstance.signIn",
            "ASAuthorizationAppleIDCredential",
            "request.nonce = sha256(nonce)",
            "SecRandomCopyBytes",
        ),
        "Federated sign-in coordinator",
        errors,
    )
    require_markers(
        login,
        (
            "GoogleSignInButton(",
            "SignInWithAppleButton(",
            "InstitutionPickerView(selection:",
            "volunteer-conduct-v1",
            "LoginMode.register",
            '"建立\\(role.title)帳號"',
        ),
        "Role onboarding UI",
        errors,
    )
    require_markers(
        app_state + firebase_auth,
        (
            "pendingIdentityCredential",
            "authService.linkIdentity(",
            "FieldValue.arrayUnion",
            "case .pendingApplication:",
            "currentUserIsAdministrator",
        ),
        "Account linking and role gating",
        errors,
    )

    institutions = catalog.get("institutions", [])
    require(len(institutions) >= 3_500, "Institution catalog is not nationwide-sized.", errors)
    require(
        len({item.get("id") for item in institutions}) == len(institutions),
        "Institution IDs are not unique.",
        errors,
    )
    require(
        all(item.get("source") == "ministryOfEducation" for item in institutions),
        "Generated official catalog contains an unlabelled source.",
        errors,
    )
    require_markers(
        institution_picker + login,
        (
            "SeedData.educationInstitutions",
            "limit: 10",
            "source: .userSubmitted",
            "claimStatus",
        ),
        "Institution picker",
        errors,
    )
    require(
        "education_institutions_seed.json" in json.dumps(manifest),
        "Institution catalog is missing from the seed manifest.",
        errors,
    )

    require_markers(
        application_view + evidence_service + worker,
        (
            ".fileImporter(",
            "application/pdf",
            "image/jpeg",
            "image/png",
            "10 * 1024 * 1024",
            "submitVolunteerApplication",
            "evidence/upload-ticket",
            "evidence.count < 5",
            "totalEvidenceBytes < 25 * 1024 * 1024",
            "deletingEvidenceID",
            "核准、拒絕或停權後 30 天會自動刪除",
        ),
        "Volunteer evidence flow",
        errors,
    )
    require_markers(
        review_view + review_service + teacher_shell,
        (
            "appState.isAdministrator",
            "VolunteerReviewView()",
            "admin/volunteer-applications",
            "admin/volunteer-review",
            "admin/evidence",
            ".quickLookPreview",
            "evidenceErrorMessage",
            "等待申請者補件並重新送出後",
            "FileManager.default.removeItem",
        ),
        "Administrator review flow",
        errors,
    )

    require_markers(
        worker,
        (
            "await requireFirebaseUser(request, env);",
            "/evidence/upload-ticket",
            "/admin/volunteer-review/",
            "verifyFirebaseIdToken",
            "verifyUploadTicket",
            'allowedStatuses = ["pendingApplication", "pendingApproval"]',
            'await requireVolunteerApplicant(user, env, ["pendingApplication"]);',
            '"X-Content-Type-Options": "nosniff"',
            "while (pageToken);",
            "MAX_EVIDENCE_FILES_PER_APPLICANT = 5",
            "MAX_EVIDENCE_TOTAL_BYTES = 25 * 1024 * 1024",
            "reserveEvidenceUpload",
            "UPLOAD_RESERVATION_INVALID",
            "cleanupExpiredReviewedEvidence",
            "REVIEW_EVIDENCE_RETENTION_DAYS = 30",
            "reviewTransitionAllowed",
            "REVIEW_STATE_CONFLICT",
            "currentDocument: application.updateTime",
        ),
        "Private Worker boundary",
        errors,
    )
    require("VOLUNTEER_EVIDENCE" in wrangler, "R2 binding missing.", errors)
    require("[observability]" in wrangler, "Worker observability missing.", errors)
    require('crons = [ "17 3 * * *" ]' in wrangler,
            "Daily evidence-retention Cron is missing.", errors)
    require(
        worker_package.get("scripts", {}).get("test") == "node --test test/*.test.js",
        "Worker security test command missing.",
        errors,
    )
    for forbidden in ("GROQ_API_KEY =", "FIREBASE_SERVICE_ACCOUNT_PRIVATE_KEY ="):
        require(forbidden not in wrangler, f"Secret appears hard-coded: {forbidden}", errors)

    require_markers(
        rules,
        (
            "validIdentityProviderUpdate(uid)",
            'profile.accountStatus in ["pendingApplication", "pendingApproval"]',
            'nextProfile.accountStatus == "pendingApproval"',
            'application.status == "pendingReview"',
            "application.evidence.size() > 0",
        ),
        "Firestore security rules",
        errors,
    )

    for ci_script in (root_ci, ios_ci):
        require("GOOGLE_SERVICE_INFO_PLIST_BASE64" in ci_script, "CI plist restore missing.", errors)
        require("REVERSED_CLIENT_ID" in ci_script, "Google URL scheme restore missing.", errors)
        require("CFBundleURLTypes" in ci_script, "CI URL type injection missing.", errors)

    require("4/20" in state and "4/20" in report, "Round 4 progress is not documented.", errors)
    require("D-13" in decisions and "private Cloudflare R2" in decisions,
            "Private evidence-storage decision is not registered.", errors)
    require("D-14" in decisions and "five files and 25 MB" in decisions,
            "Evidence quota and retention decision is not registered.", errors)
    require("64 passed, 0 failed" in report,
            "Round 4 full-audit result is not recorded.", errors)
    require("five-file and 25 MB" in report and "final-review evidence after 30 days" in report,
            "Round 4 evidence quota/retention update is not documented.", errors)

    if errors:
        print("Round 4 provider UI and private review validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print(
        "Round 4 provider UI and private review validation passed: "
        f"{len(institutions)} institutions"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
