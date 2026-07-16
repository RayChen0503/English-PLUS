import SwiftUI

struct RuntimeDiagnosticsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var learningRepository: LearningRepositoryStore
    @Environment(\.dismiss) private var dismiss

    private var diagnostics: RuntimeDiagnosticsSnapshot {
        appState.runtimeDiagnostics
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        diagnosticsSection(
                            title: "Runtime",
                            rows: [
                                ("Backend", diagnostics.backendMode.label),
                                ("App config", diagnostics.hasFirebaseConfig ? "present" : "missing"),
                                ("Auth", diagnostics.authProvider),
                                ("Cloud data", diagnostics.firestoreProvider),
                                ("Learning", diagnostics.learningProvider),
                                ("AI", diagnostics.aiProvider),
                                ("AI endpoint", diagnostics.aiProxyEndpoint ?? "missing"),
                            ]
                        )

                        diagnosticsSection(
                            title: "Session",
                            rows: [
                                ("UID", diagnostics.signedInUserId ?? "not signed in"),
                                ("Role", diagnostics.signedInRole?.title ?? "none"),
                                ("Class", diagnostics.signedInClassId ?? "none"),
                                ("Sync", syncStatusText),
                            ]
                        )

                        diagnosticsSection(
                            title: "Last AI Call",
                            rows: aiRows
                        )
                    }
                    .padding(EPTheme.pagePadding)
                }
            }
            .navigationTitle("Runtime Check")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var aiRows: [(String, String)] {
        guard let lastAIStatus = diagnostics.lastAIStatus else {
            return [
                ("Status", "not called"),
                ("Fallback", "unknown"),
            ]
        }

        return [
            ("Status", lastAIStatus.ok ? "ok" : "failed"),
            ("Fallback", lastAIStatus.fallbackUsed ? "yes" : "no"),
            ("Task", lastAIStatus.taskType),
            ("Provider", lastAIStatus.provider),
            ("Model", lastAIStatus.modelUsed),
            ("Error", lastAIStatus.errorCode ?? "none"),
        ]
    }

    private var syncStatusText: String {
        switch learningRepository.syncStatus {
        case .idle:
            return "idle"
        case .connecting(let classId):
            return "connecting \(classId)"
        case .listening(let classId):
            return "listening \(classId)"
        case .retrying(let classId, let attempt):
            return "retrying \(classId) attempt \(attempt)"
        case .offlineFallback(let reason):
            return "fallback \(reason)"
        case .syncIssue(let reason, let retryAvailable):
            return "sync issue retry=\(retryAvailable) \(reason)"
        }
    }

    private func diagnosticsSection(
        title: String,
        rows: [(String, String)]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(EPTheme.ink)

            ForEach(rows, id: \.0) { row in
                HStack(alignment: .top, spacing: 12) {
                    Text(row.0)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(EPTheme.secondaryInk)
                        .frame(width: 92, alignment: .leading)
                    Text(row.1)
                        .font(.caption.monospaced())
                        .foregroundStyle(EPTheme.ink)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private extension EnglishPlusBackendMode {
    var label: String {
        switch self {
        case .mock:
            return "mock"
        case .firebase:
            return "firebase"
        case .configurationError:
            return "configuration-error"
        }
    }
}
