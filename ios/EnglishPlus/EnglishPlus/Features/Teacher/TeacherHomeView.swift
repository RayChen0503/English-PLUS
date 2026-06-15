import SwiftUI

struct TeacherHomeView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    Text("今日需要先接住誰")
                        .font(.title.bold())
                        .foregroundStyle(EPTheme.ink)

                    VStack(alignment: .leading, spacing: 10) {
                        Label("2 位學生需要回應", systemImage: "exclamationmark.circle")
                            .font(.headline)
                            .foregroundStyle(EPTheme.warning)
                        Text("先處理高風險與待回應求助，再查看班級整體狀態。")
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))

                    Spacer()
                }
                .padding(EPTheme.pagePadding)
            }
            .navigationTitle("教師工作台")
        }
    }
}
