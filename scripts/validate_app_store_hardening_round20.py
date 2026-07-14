from pathlib import Path
import json
import plistlib
import struct
import sys


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8-sig")


def token_is_debug_only(source: str, token: str) -> bool:
    debug_depth = 0
    token_seen = False
    for raw_line in source.splitlines():
        line = raw_line.strip()
        if line.startswith("#if"):
            if "DEBUG" in line or debug_depth > 0:
                debug_depth += 1
            continue
        if line.startswith("#endif"):
            debug_depth = max(0, debug_depth - 1)
            continue
        if token in raw_line:
            token_seen = True
            if debug_depth == 0:
                return False
    return token_seen


def png_metadata(path: Path) -> tuple[int, int, int, int]:
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        raise ValueError(f"Not a valid PNG with IHDR: {path}")
    width, height = struct.unpack(">II", data[16:24])
    return width, height, data[24], data[25]


def app_icons_are_store_ready() -> bool:
    icon_dir = ROOT / "ios/EnglishPlus/EnglishPlus/Assets.xcassets/AppIcon.appiconset"
    contents = json.loads((icon_dir / "Contents.json").read_text(encoding="utf-8"))
    images = contents.get("images", [])
    if not images or not any(image.get("idiom") == "ios-marketing" for image in images):
        return False
    for image in images:
        filename = image.get("filename")
        if not filename:
            return False
        size = float(image["size"].split("x")[0])
        scale = float(image["scale"].removesuffix("x"))
        expected = round(size * scale)
        width, height, bit_depth, color_type = png_metadata(icon_dir / filename)
        if (width, height, bit_depth, color_type) != (expected, expected, 8, 2):
            return False
    return True


role_source = read(
    "ios/EnglishPlus/EnglishPlus/Features/RoleSelection/RoleSelectionView.swift"
)
login_source = read(
    "ios/EnglishPlus/EnglishPlus/Features/RoleSelection/DemoLoginView.swift"
)
student_source = read(
    "ios/EnglishPlus/EnglishPlus/Features/Student/StudentHomeView.swift"
)
teacher_source = read(
    "ios/EnglishPlus/EnglishPlus/Features/Teacher/TeacherHomeView.swift"
)
volunteer_source = read(
    "ios/EnglishPlus/EnglishPlus/Features/Volunteer/VolunteerHomeView.swift"
)
diagnostics_source = read(
    "ios/EnglishPlus/EnglishPlus/Core/AppDiagnostics.swift"
)
ui_tests = read(
    "ios/EnglishPlus/EnglishPlusUITests/EnglishPlusCriticalFlowsUITests.swift"
)
project = read("ios/EnglishPlus/EnglishPlus.xcodeproj/project.pbxproj")
post_clone = read("ios/EnglishPlus/ci_scripts/ci_post_clone.sh")
workflow = read(".github/workflows/ios-hardening-build.yml")
launch_configuration = read(
    "ios/EnglishPlus/EnglishPlus/App/EnglishPlusLaunchConfiguration.swift"
)
service_factory = read(
    "ios/EnglishPlus/EnglishPlus/Services/FirebaseAppConfigurator.swift"
)
release_notes = read(
    "docs/ios-testflight/testflight/internal-build-release-notes.md"
)
test_info = read("docs/ios-testflight/testflight/app-store-connect-test-info.md")
manual_checklist = read(
    "docs/app-store-hardening/round-20-manual-testflight-checklist.md"
)
audit = read("docs/app-store-hardening/round-20-release-candidate-audit.md")

info = plistlib.loads(
    (ROOT / "ios/EnglishPlus/EnglishPlus/Info.plist").read_bytes()
)
privacy = plistlib.loads(
    (ROOT / "ios/EnglishPlus/EnglishPlus/PrivacyInfo.xcprivacy").read_bytes()
)
entitlements = plistlib.loads(
    (ROOT / "ios/EnglishPlus/EnglishPlus/EnglishPlus.entitlements").read_bytes()
)
export_options = plistlib.loads(
    (ROOT / "ios/EnglishPlus/Config/ExportOptions.TestFlight.plist").read_bytes()
)
firebase_config = json.loads(read("firebase.json"))
archived_functions_notice = read("functions/README.md")

ios_source = "\n".join(
    path.read_text(encoding="utf-8-sig")
    for path in (ROOT / "ios/EnglishPlus/EnglishPlus").rglob("*")
    if path.suffix in {".swift", ".plist", ".entitlements"}
)

public_privacy = (
    "https://sites.google.com/view/englishplus-privacy/"
    "%E9%9A%B1%E7%A7%81%E6%94%BF%E7%AD%96"
)
public_support = (
    "https://sites.google.com/view/englishplus-privacy/"
    "%E6%94%AF%E6%8F%B4%E8%88%87%E8%81%AF%E7%B5%A1"
)

checks = {
    "release diagnostics are debug-only": all(
        token_is_debug_only(role_source, token)
        for token in [
            "showingRuntimeDiagnostics",
            ".onTapGesture(count: 5)",
            "RuntimeDiagnosticsView()",
        ]
    ),
    "human-help links avoid force unwrap": 'URL(string: "tel:\\(number)")!'
    not in student_source
    and "if let destination = URL(string:" in student_source,
    "diagnostic underlying errors compile with the local parameter name": all(
        token in diagnostics_source
        for token in [
            "underlying error: Error? = nil",
            "let errorType = error.map",
        ]
    )
    and "let errorType = underlying.map" not in diagnostics_source,
    "unit and UI tests cannot initialize production Firebase services": all(
        token in launch_configuration
        for token in [
            'environment["XCTestConfigurationFilePath"]',
            "static var shouldUseMockServices",
            "isUITesting || isUnitTesting",
        ]
    )
    and "EnglishPlusLaunchConfiguration.shouldUseMockServices" in service_factory
    and '"API_KEY": "A" + ("0" * 38)' in workflow,
    "large-text authentication keeps a keyboard-safe submit path": all(
        token in login_source
        for token in [
            ".scrollDismissesKeyboard(.interactively)",
            "ScrollViewReader",
            "scrollProxy.scrollTo(anchorID, anchor: .center)",
            'accessibilityIdentifier("auth.screen")',
            'accessibilityIdentifier("auth.keyboard.dismiss")',
            ".submitLabel(.go)",
            "performPrimaryAction()",
        ]
    )
    and 'app.buttons["auth.keyboard.dismiss"]' in ui_tests
    and 'emailField.typeText("\\n")' in ui_tests
    and 'scrollUntilHittable(emailField, in: authenticationScreen)' in ui_tests,
    "teacher primary workspaces are addressable": all(
        token in teacher_source
        for token in [
            "teacher.home.workspace",
            "teacher.class.workspace",
            "teacher.handoff.workspace",
            "teacher.report.workspace",
        ]
    ),
    "volunteer primary workspaces are addressable": all(
        token in volunteer_source
        for token in [
            "volunteer.home.workspace",
            "volunteer.service.workspace",
            "volunteer.handoff.workspace",
            "volunteer.records.workspace",
        ]
    ),
    "all-role route sweep is automated": all(
        token in ui_tests
        for token in [
            "testStudentEveryPrimaryWorkspaceHasAReachablePurpose",
            "testTeacherEveryPrimaryWorkspaceHasAReachablePurpose",
            "testVolunteerEveryPrimaryWorkspaceHasAReachablePurpose",
            "student.support.inbox",
            "teacher.handoff.workspace",
            "volunteer.service.workspace",
            'capture("student-05-map")',
            'capture("teacher-04-report")',
            'capture("volunteer-04-records")',
            "XCTAttachment(screenshot: XCUIScreen.main.screenshot())",
        ]
    ),
    "real connected-service notes replace obsolete mock notes": all(
        token in release_notes
        for token in [
            "Firebase Authentication and Firestore",
            "Cloudflare Worker and Groq",
            "synchronize through Firestore",
            "Volunteer access requires both platform approval",
        ]
    )
    and all(
        obsolete not in release_notes
        for obsolete in [
            "still run through replaceable mock services",
            "MockAIService by default",
            "Cloud Functions proxy",
        ]
    ),
    "Xcode Cloud owns the TestFlight build number": "Assigned automatically by Xcode Cloud"
    in test_info,
    "public policy and support metadata are aligned": all(
        value in test_info
        for value in [public_privacy, public_support, "englishplus.tw@gmail.com"]
    ),
    "real-device acceptance covers every governed role": all(
        heading in manual_checklist
        for heading in [
            "Student Personal Learning Journey",
            "Classroom And Assignment Journey",
            "Question-Specific Human Support",
            "Teacher Journey",
            "Volunteer And Administrator Journey",
            "Privacy, Data And Safety",
            "Appearance, Accessibility And Reliability",
            "Release Decision",
        ]
    ),
    "release audit is traceable to automated and manual gates": all(
        token in audit
        for token in [
            "Automated Acceptance Surface",
            "Round 20 Corrections",
            "Required Gates",
            "manual checklist",
        ]
    ),
    "production endpoints are HTTPS": info.get("ENGLISHPLUS_AI_PROXY_URL", "").startswith(
        "https://"
    )
    and info.get("ENGLISHPLUS_EVIDENCE_UPLOAD_URL", "").startswith("https://"),
    "no provider secret is bundled in iOS": all(
        token not in ios_source
        for token in ["GROQ_API_KEY", "OPENROUTER_API_KEY", "sk-or-v1-"]
    ),
    "obsolete OpenRouter Functions cannot be deployed accidentally": "functions"
    not in firebase_config
    and "must not be deployed" in archived_functions_notice
    and "workers/englishplus-ai-proxy" in archived_functions_notice,
    "crash diagnostics default off": info.get("FirebaseCrashlyticsCollectionEnabled")
    is False,
    "privacy manifest declares non-tracking collected data": bool(
        privacy.get("NSPrivacyCollectedDataTypes")
    )
    and privacy.get("NSPrivacyTracking") is False,
    "Apple sign-in entitlement is present": entitlements.get(
        "com.apple.developer.applesignin"
    )
    == ["Default"],
    "Google URL scheme is generated from protected config": all(
        token in post_clone
        for token in ["REVERSED_CLIENT_ID", "CFBundleURLTypes", "GoogleService-Info.plist"]
    ),
    "signing and device target are release-ready": all(
        token in project
        for token in [
            "CODE_SIGN_STYLE = Automatic;",
            "CODE_SIGN_ENTITLEMENTS = EnglishPlus/EnglishPlus.entitlements;",
            "DEVELOPMENT_TEAM = X7Y2V4D87G;",
            "IPHONEOS_DEPLOYMENT_TARGET = 17.0;",
            "PRODUCT_BUNDLE_IDENTIFIER = com.englishplus;",
            "TARGETED_DEVICE_FAMILY = 1;",
        ]
    ),
    "TestFlight export is App Store Connect automatic signing": export_options.get(
        "method"
    )
    == "app-store-connect"
    and export_options.get("signingStyle") == "automatic"
    and export_options.get("teamID") == "X7Y2V4D87G",
    "App Store icon set is complete RGB without alpha": app_icons_are_store_ready(),
    "CI runs Round 20 and complete role tests": all(
        token in workflow
        for token in [
            "validate_app_store_hardening_round20.py",
            "-only-testing:EnglishPlusUITests",
            "Run dark mode and Dynamic Type device matrix",
            "Validate Firestore rules and classroom lifecycle",
            "Validate Cloudflare AI gateway",
            "Validate administrator review portal",
        ]
    ),
}

failed = [name for name, passed in checks.items() if not passed]
for name, passed in checks.items():
    print(f"[{'PASS' if passed else 'FAIL'}] {name}")

if failed:
    print("Round 20 validation failed: " + ", ".join(failed), file=sys.stderr)
    sys.exit(1)

print("Round 20 release-candidate contracts passed.")
