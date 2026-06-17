import SwiftUI

struct SupportView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var learningRepository: MockLearningRepository

    private let supportOptions = SeedData.supportOptions

    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("需要一點幫忙嗎？")
                            .font(.title.bold())
                            .foregroundStyle(EPTheme.ink)

                        VStack(spacing: 10) {
                            ForEach(supportOptions) { option in
                                supportRow(option)
                            }
                        }

                        studentRequestsSection
                    }
                    .padding(EPTheme.pagePadding)
                }
            }
            .navigationTitle("支持")
        }
    }

    private var studentRequestsSection: some View {
        let requests = learningRepository.supportRequests(forStudentUid: appState.currentUser?.id)

        return VStack(alignment: .leading, spacing: 10) {
            Text("我的求助")
                .font(.headline)

            if requests.isEmpty {
                Text("需要時可以從上方送出，老師或志工回覆後會出現在這裡。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
            } else {
                ForEach(requests) { request in
                    StudentRequestCard(request: request)
                }
            }
        }
    }

    private func supportRow(_ option: SupportOption) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: iconName(for: option.route))
                    .frame(width: 32, height: 32)
                    .foregroundStyle(EPTheme.support)
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.reason)
                        .font(.headline)
                    Text(option.platformAction)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Button(actionTitle(for: option.route)) {
                learningRepository.sendSupportRequest(
                    from: appState.currentUser,
                    profile: appState.currentProfile,
                    option: option
                )
            }
            .buttonStyle(PrimaryActionButtonStyle())
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private func actionTitle(for route: SupportRoute) -> String {
        switch route {
        case .aiCoach:
            return "取得提示"
        case .humanHandoff:
            return "送給老師或志工"
        case .readingBreakdown:
            return "拆解閱讀題"
        case .recovery:
            return "切換成小任務"
        }
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

private struct StudentRequestCard: View {
    let request: StudentSupportRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(request.status.uiTitle)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                Spacer()
                if let moodScore = request.moodScore {
                    Text("心情 \(moodScore)/5")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(request.studentMessage)
                .font(.subheadline)
                .foregroundStyle(EPTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            if request.replies.isEmpty {
                Text("已排入待回應清單。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(request.replies.filter(\.visibleToStudent)) { reply in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(reply.authorName)
                            .font(.caption.bold())
                            .foregroundStyle(EPTheme.support)
                        Text(reply.body)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
                }
            }
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private var statusColor: Color {
        switch request.status {
        case .open, .waitingForStaff:
            return EPTheme.warning
        case .replied, .readByStudent:
            return EPTheme.support
        case .closed:
            return .secondary
        }
    }
}
