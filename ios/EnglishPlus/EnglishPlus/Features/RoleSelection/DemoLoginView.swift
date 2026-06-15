import SwiftUI

struct DemoLoginView: View {
    @EnvironmentObject private var appState: AppState
    let role: UserRole

    var body: some View {
        ZStack {
            EPTheme.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 24) {
                Button {
                    appState.signOut()
                } label: {
                    Label("返回", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)
                .foregroundStyle(EPTheme.primary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("\(role.title)入口")
                        .font(.largeTitle.bold())
                        .foregroundStyle(EPTheme.ink)
                    Text(role.shortPurpose)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("內測展示帳號")
                        .font(.headline)
                    Text("先用展示流程進入，之後會接上正式帳號與同意流程。")
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))

                Spacer()

                Button("進入\(role.title)端") {
                    appState.signInForSelectedRole()
                }
                .buttonStyle(PrimaryActionButtonStyle())
            }
            .padding(EPTheme.pagePadding)
        }
    }
}
