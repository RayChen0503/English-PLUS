import SwiftUI

struct SupportView: View {
    private let supportOptions = SeedData.supportOptions

    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    Text("需要一點幫忙嗎？")
                        .font(.title.bold())
                        .foregroundStyle(EPTheme.ink)

                    ForEach(supportOptions) { option in
                        supportRow(
                            title: option.reason,
                            subtitle: option.platformAction,
                            icon: iconName(for: option.route)
                        )
                    }

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

    private func iconName(for route: SupportRoute) -> String {
        switch route {
        case .aiCoach:
            return "lightbulb"
        case .humanHandoff:
            return "person.2"
        case .readingBreakdown:
            return "doc.text.magnifyingglass"
        case .recovery:
            return "heart"
        }
    }
}
