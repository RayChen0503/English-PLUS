#!/usr/bin/env python3
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
IOS_ROOT = ROOT / "ios" / "EnglishPlus" / "EnglishPlus"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def main() -> int:
    errors: list[str] = []
    diagnostics = IOS_ROOT / "Models" / "RuntimeDiagnostics.swift"
    diagnostics_view = IOS_ROOT / "Features" / "Diagnostics" / "RuntimeDiagnosticsView.swift"
    factory = IOS_ROOT / "Services" / "FirebaseAppConfigurator.swift"
    app_state = IOS_ROOT / "App" / "AppState.swift"
    app = IOS_ROOT / "App" / "EnglishPlusApp.swift"
    role_selection = IOS_ROOT / "Features" / "RoleSelection" / "RoleSelectionView.swift"

    for path in [diagnostics, diagnostics_view, factory, app_state, app, role_selection]:
        require(path.exists(), f"missing {path.relative_to(ROOT)}", errors)
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    diagnostics_text = read(diagnostics)
    factory_text = read(factory)
    app_state_text = read(app_state)
    app_text = read(app)
    diagnostics_view_text = read(diagnostics_view)
    role_selection_text = read(role_selection)

    for token in [
        "struct RuntimeDiagnosticsSnapshot",
        "struct RuntimeAIStatus",
        "backendMode: EnglishPlusBackendMode",
        "hasFirebaseConfig: Bool",
        "authProvider: String",
        "firestoreProvider: String",
        "learningProvider: String",
        "aiProvider: String",
        "aiProxyEndpoint: String?",
        "signedInUserId: String?",
        "signedInRole: UserRole?",
        "lastAIStatus: RuntimeAIStatus?",
        "func withSession",
        "func clearingSession",
        "func recordingAIResponse",
    ]:
        require(token in diagnostics_text, f"RuntimeDiagnostics.swift missing {token}", errors)

    require(
        "let runtimeDiagnostics: RuntimeDiagnosticsSnapshot" in factory_text,
        "EnglishPlusServiceBundle must carry runtimeDiagnostics",
        errors,
    )
    require(
        "RuntimeDiagnosticsSnapshot(" in factory_text,
        "Service factory must create runtime diagnostics",
        errors,
    )
    for token in [
        "backendMode: .firebase",
        "backendMode: .mock",
        "hasFirebaseConfig: FirebaseAppConfigurator.hasBundledConfig",
        "aiProxyEndpoint: EnglishPlusAIProxyConfig.workerEndpoint?.absoluteString",
        "RemoteAIService",
        "MockAIService",
        "FirebaseLearningRepository",
        "MockLearningRepository",
    ]:
        require(token in factory_text, f"Service factory diagnostics missing {token}", errors)

    for token in [
        "@Published private(set) var runtimeDiagnostics",
        "runtimeDiagnostics: RuntimeDiagnosticsSnapshot",
        "self.runtimeDiagnostics = runtimeDiagnostics",
        "runtimeDiagnostics.withSession",
        "runtimeDiagnostics.clearingSession",
        "recordAIResponse",
        "runtimeDiagnostics.recordingAIResponse",
    ]:
        require(token in app_state_text, f"AppState diagnostics missing {token}", errors)

    require(
        "runtimeDiagnostics: services.runtimeDiagnostics" in app_text,
        "EnglishPlusApp must inject service runtimeDiagnostics into AppState",
        errors,
    )

    for token in [
        "struct RuntimeDiagnosticsView",
        "@EnvironmentObject private var appState: AppState",
        "@EnvironmentObject private var learningRepository: LearningRepositoryStore",
        "appState.runtimeDiagnostics",
        "learningRepository.syncStatus",
        "lastAIStatus",
        "fallbackUsed",
        "aiProxyEndpoint",
    ]:
        require(token in diagnostics_view_text, f"RuntimeDiagnosticsView missing {token}", errors)

    for token in [
        "@State private var showingRuntimeDiagnostics",
        ".onTapGesture(count: 5)",
        ".sheet(isPresented: $showingRuntimeDiagnostics)",
        "RuntimeDiagnosticsView()",
    ]:
        require(token in role_selection_text, f"RoleSelection hidden diagnostics entry missing {token}", errors)

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print("Runtime truth gate validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
