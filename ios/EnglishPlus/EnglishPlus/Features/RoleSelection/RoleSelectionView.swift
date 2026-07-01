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
                        Text("你今天要用哪一端？")
                            .font(.title2.bold())
                            .foregroundStyle(EPTheme.ink)
                        Text("學生先完成心情檢測，再進入每日任務；老師與志工則先看需要接力的學生。")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: 12) {
                        ForEach(UserRole.allCases) { role in
                            Button {
                                appState.chooseRole(role)
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: iconName(for: role))
                                        .font(.title2)
                                        .frame(width: 38, height: 38)
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
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                }
                                .padding(16)
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
                            }
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
