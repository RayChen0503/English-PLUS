import SwiftUI

struct SupportView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    Text("需要一點幫忙嗎？")
                        .font(.title.bold())
                        .foregroundStyle(EPTheme.ink)

                    supportRow(title: "先看提示", subtitle: "用一句話提醒自己卡在哪裡", icon: "lightbulb")
                    supportRow(title: "請老師協助", subtitle: "把題目和你的想法送給老師看", icon: "person.2")
                    supportRow(title: "請志工陪伴", subtitle: "需要鼓勵或陪你整理下一步時使用", icon: "heart")

                    Spacer()
                }
                .padding(EPTheme.pagePadding)
            }
            .navigationTitle("支持")
        }
    }

    private func supportRow(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .frame(width: 32, height: 32)
                .foregroundStyle(EPTheme.support)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}
