import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var learningRepository: LearningRepositoryStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if appState.runtimeDiagnostics.backendMode == .configurationError {
                ServiceConfigurationUnavailableView()
            } else {
                diagnosticsContent
            }
        }
            .alert("同步未完成", isPresented: supportErrorIsPresented) {
                Button("好") {
                    learningRepository.dismissSupportActionError()
                }
            } message: {
                Text(learningRepository.supportActionErrorMessage ?? "請稍後再試一次。")
            }
    }

    private var diagnosticsContent: some View {
        accountDiagnosticsContent
            .onChange(of: appState.classroomRosterErrorMessage) { _, message in
                recordIfPresent(message, category: .roster)
            }
            .onChange(of: appState.volunteerServiceErrorMessage) { _, message in
                recordIfPresent(message, category: .volunteerService)
            }
            .onChange(of: appState.volunteerReviewErrorMessage) { _, message in
                recordIfPresent(message, category: .volunteerReview)
            }
    }

    private var accountDiagnosticsContent: some View {
        repositoryDiagnosticsContent
            .onChange(of: appState.signInErrorMessage) { _, message in
                recordIfPresent(message, category: .authentication)
            }
            .onChange(of: appState.consentErrorMessage) { _, message in
                recordIfPresent(message, category: .consent)
            }
            .onChange(of: appState.classroomErrorMessage) { _, message in
                recordIfPresent(message, category: .classroom)
            }
    }

    private var repositoryDiagnosticsContent: some View {
        lifecycleContent
            .onChange(of: learningRepository.supportActionErrorMessage) { _, message in
                recordIfPresent(message, category: .supportMutation)
            }
            .onChange(of: learningRepository.assignmentActionErrorMessage) { _, message in
                recordIfPresent(message, category: .assignmentMutation)
            }
    }

    private var lifecycleContent: some View {
        realtimeLifecycleContent
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 0.18),
                value: learningRepository.syncStatus
            )
            .onChange(of: learningRepository.syncStatus) { _, status in
                recordSyncStatus(status)
            }
    }

    private var realtimeLifecycleContent: some View {
        routeLifecycleContent
            .onChange(of: appState.currentProfile?.activeClassId) { _, _ in
                startRealtimeSyncIfNeeded()
            }
            .onChange(of: appState.currentUser?.id) { _, _ in
                startRealtimeSyncIfNeeded()
            }
            .onChange(of: appState.currentProfile?.id) { _, _ in
                startRealtimeSyncIfNeeded()
            }
            .overlay(alignment: .top) {
                RepositorySyncBanner(
                    status: learningRepository.syncStatus,
                    lastSuccessfulSyncAt: learningRepository.lastSuccessfulSyncAt,
                    onRetry: learningRepository.retryRealtimeSync
                )
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .zIndex(20)
            }
    }

    private var routeLifecycleContent: some View {
        routeContent
            .tint(EPTheme.primary)
            .background(EPTheme.background.ignoresSafeArea())
            .onAppear(perform: handleRouteContext)
            .onChange(of: appState.route) { _, _ in
                handleRouteContext()
            }
    }

    @ViewBuilder
    private var routeContent: some View {
        Group {
            switch appState.route {
            case .roleSelection:
                RoleSelectionView()
            case .demoLogin(let role):
                DemoLoginView(role: role)
            case .volunteerApplication:
                VolunteerApplicationView()
            case .privacyConsent(let role):
                ConsentView(role: role)
            case .home(let role):
                switch role {
                case .student:
                    StudentShellView()
                case .teacher:
                    TeacherShellView()
                case .volunteer:
                    VolunteerShellView()
                }
            }
        }
    }

    private var supportErrorIsPresented: Binding<Bool> {
        Binding(
            get: { learningRepository.supportActionErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    learningRepository.dismissSupportActionError()
                }
            }
        )
    }

    private func handleRouteContext() {
        AppDiagnostics.shared.configure()
        AppDiagnostics.shared.updateContext(
            route: appState.route,
            role: appState.currentProfile?.role ?? appState.currentUser?.role
        )
        startRealtimeSyncIfNeeded()
    }

    private func recordIfPresent(_ message: String?, category: AppDiagnosticCategory) {
        guard message != nil else { return }
        AppDiagnostics.shared.record(category)
    }

    private func recordSyncStatus(_ status: LearningRepositorySyncStatus) {
        switch status {
        case .listening:
            AppDiagnostics.shared.log(.realtimeSyncConnected)
        case .offlineFallback:
            AppDiagnostics.shared.log(.realtimeSyncOffline)
        case .syncIssue:
            AppDiagnostics.shared.log(.realtimeSyncIssue)
        default:
            break
        }
    }

    private func startRealtimeSyncIfNeeded() {
        guard case .home = appState.route,
              let currentProfile = appState.currentProfile
        else {
            learningRepository.stopRealtimeSync()
            return
        }

        learningRepository.startRealtimeSync(
            classId: currentProfile.classId,
            user: appState.currentUser,
            profile: currentProfile
        )
    }
}

private struct ServiceConfigurationUnavailableView: View {
    var body: some View {
        ZStack {
            EPTheme.background.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(EPTheme.primary)

                Text("服務設定尚未完成")
                    .font(.title2.bold())
                    .foregroundStyle(EPTheme.ink)

                Text("這個版本目前無法安全連線。請更新 App，或聯絡 englishplus.tw@gmail.com。")
                    .font(.body)
                    .foregroundStyle(EPTheme.secondaryInk)
                    .multilineTextAlignment(.center)
            }
            .padding(28)
            .frame(maxWidth: 420)
        }
    }
}
