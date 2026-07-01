import SwiftUI

struct RoleSelectionView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showingRuntimeDiagnostics = false

    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("English+")
                            .font(.largeTitle.bold())
                            .foregroundStyle(EPTheme.ink)
                            .onTapGesture(count: 5) {
                                showingRuntimeDiagnostics = true
                            }
                        Text("偏鄉學生雙軌學習平台")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 12) {
                        ForEach(UserRole.allCases) { role in
                            Button {
                                Task {
                                    await appState.signIn(role: role)
                                }
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: iconName(for: role))
                                        .font(.title2)
                                        .frame(width: 36, height: 36)
                                        .foregroundStyle(EPTheme.primary)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(role.title)
                                            .font(.headline)
                                            .foregroundStyle(EPTheme.ink)
                                        Text(role.shortPurpose)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .multilineTextAlignment(.leading)
                                    }
                                    Spacer()
                                    if appState.signingInRole == role {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(16)
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
                            }
                            .disabled(appState.signingInRole != nil)
                            .buttonStyle(.plain)
                        }
                    }

                    if let message = appState.signInErrorMessage {
                        Text(message)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()
                }
                .padding(EPTheme.pagePadding)
            }
            .sheet(isPresented: $showingRuntimeDiagnostics) {
                RuntimeDiagnosticsView()
            }
        }
    }

    private func iconName(for role: UserRole) -> String {
        switch role {
        case .student:
            return "book.closed"
        case .teacher:
            return "person.2"
        case .volunteer:
            return "heart"
        }
    }
}
