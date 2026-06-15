import SwiftUI

struct VolunteerHomeView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    Text("今日接力任務")
                        .font(.title.bold())
                        .foregroundStyle(EPTheme.ink)

                    VStack(alignment: .leading, spacing: 10) {
                        Label("1 位學生等待陪伴", systemImage: "heart")
                            .font(.headline)
                            .foregroundStyle(EPTheme.support)
                        Text("查看必要摘要，留下鼓勵或陪伴回覆。")
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
            .navigationTitle("志工工作台")
        }
    }
}
