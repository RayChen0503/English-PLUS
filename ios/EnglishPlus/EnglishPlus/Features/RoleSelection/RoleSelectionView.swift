import SwiftUI

struct RoleSelectionView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("English+")
                            .font(.largeTitle.bold())
                            .foregroundStyle(EPTheme.ink)
                        Text("今天你要用哪一端？")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 12) {
                        ForEach(UserRole.allCases) { role in
                            Button {
                                appState.chooseRole(role)
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

                    Spacer()
                }
                .padding(EPTheme.pagePadding)
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
