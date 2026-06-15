import SwiftUI

struct StudentHomeView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("早安，\(appState.currentUser?.displayName ?? "同學")")
                            .font(.title.bold())
                            .foregroundStyle(EPTheme.ink)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("今日任務")
                                .font(.headline)
                            Text("先完成簡短心情檢測，再產生適合今天的英文練習。")
                                .foregroundStyle(.secondary)
                            Button("開始心情檢測") { }
                                .buttonStyle(PrimaryActionButtonStyle())
                        }
                        .padding(16)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))

                        VStack(alignment: .leading, spacing: 10) {
                            Text("自由練習")
                                .font(.headline)
                            Text("也可以直接進入練習中心，不會影響今日任務進度。")
                                .foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
                    }
                    .padding(EPTheme.pagePadding)
                }
            }
        }
    }
}
