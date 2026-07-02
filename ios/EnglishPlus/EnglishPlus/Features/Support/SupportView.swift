import SwiftUI

struct SupportView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

    let onOpenPractice: () -> Void
    let onOpenHome: () -> Void

    private let supportOptions = SeedData.supportOptions
    @State private var latestSupportAIResponse: AiProxyResponse?
    @State private var isLoadingSupportAI = false

    init(
        onOpenPractice: @escaping () -> Void = {},
        onOpenHome: @escaping () -> Void = {}
    ) {
        self.onOpenPractice = onOpenPractice
        self.onOpenHome = onOpenHome
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("支持")
                                .font(.title.bold())
                                .foregroundStyle(EPTheme.ink)
                            Text("如果題目卡住、心情低落，或想要人陪你看一題，可以從這裡求助。")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        VStack(spacing: 10) {
                            ForEach(supportOptions) { option in
                                supportRow(option)
                            }
                        }

                        if isLoadingSupportAI {
                            Label("AI 正在先給一段可以立刻使用的支持建議...", systemImage: "sparkles")
                                .font(.footnote)
                                .foregroundStyle(EPTheme.primary)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
                        }

                        if let latestSupportAIResponse {
                            SupportAIResponseCard(response: latestSupportAIResponse)
                            SupportAIActionCard(
                                response: latestSupportAIResponse,
                                onOpenPractice: openPracticeFromSupport,
                                onOpenHome: openHomeFromSupport
                            )
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
            Text("我的求助紀錄")
                .font(.headline)

            if requests.isEmpty {
                Text("目前還沒有求助紀錄。需要時可以先看 AI 建議，也可以交給老師或志工接力。")
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
                    Text(displayReason(for: option))
                        .font(.headline)
                    Text(displayAction(for: option))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }

            Button(actionTitle(for: option.route)) {
                sendSupportRequestWithAI(option: option)
            }
            .buttonStyle(PrimaryActionButtonStyle())
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private func displayReason(for option: SupportOption) -> String {
        switch option.route {
        case .aiCoach:
            return "請 AI 先提示我"
        case .humanHandoff:
            return "請老師或志工陪我"
        case .readingBreakdown:
            return "閱讀題卡住了"
        case .recovery:
            return "我需要先穩一下"
        }
    }

    private func displayAction(for option: SupportOption) -> String {
        switch option.route {
        case .aiCoach:
            return "適合想先自己再試一次的時候。"
        case .humanHandoff:
            return "適合已經試過提示，但仍需要真人陪伴。"
        case .readingBreakdown:
            return "適合文章或長句看不懂的時候。"
        case .recovery:
            return "適合今天壓力太大，需要先降低任務量。"
        }
    }

    private func actionTitle(for route: SupportRoute) -> String {
        switch route {
        case .aiCoach:
            return "請 AI 陪我看"
        case .humanHandoff:
            return "送給老師或志工"
        case .readingBreakdown:
            return "拆解閱讀題"
        case .recovery:
            return "取得低壓建議"
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

    private func sendSupportRequestWithAI(option: SupportOption) {
        learningRepository.sendSupportRequest(
            from: appState.currentUser,
            profile: appState.currentProfile,
            option: option,
            message: studentMessage(for: option)
        )
        guard let request = learningRepository.supportRequests(forStudentUid: appState.currentUser?.id).first else {
            return
        }

        isLoadingSupportAI = true
        Task {
            latestSupportAIResponse = await appState.provideEmotionalSupportWithAI(
                context: SupportAIContext(request: request)
            )
            isLoadingSupportAI = false
        }
    }

    private func openPracticeFromSupport() {
        learningRepository.enterFreePracticeMode()
        onOpenPractice()
    }

    private func openHomeFromSupport() {
        learningRepository.returnToMissionFlow()
        onOpenHome()
    }

    private func studentMessage(for option: SupportOption) -> String {
        switch option.route {
        case .aiCoach:
            return "我想先看一個提示，再自己試一次。"
        case .humanHandoff:
            return "我已經試過提示了，想請老師或志工陪我看。"
        case .readingBreakdown:
            return "我卡在閱讀題或長句，想先拆解句子。"
        case .recovery:
            return "我今天狀態比較低，想先做低壓任務。"
        }
    }
}

private struct SupportAIActionCard: View {
    let response: AiProxyResponse
    let onOpenPractice: () -> Void
    let onOpenHome: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("接下來可以做這一步")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)

            Text(actionHint)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button {
                    onOpenPractice()
                } label: {
                    Label("去練類似題", systemImage: "target")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(PrimaryActionButtonStyle())

                Button {
                    onOpenHome()
                } label: {
                    Label("回今日任務", systemImage: "house")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private var actionHint: String {
        if response.output.staffEscalationNeeded == true {
            return "這次求助已經留給老師或志工。你可以先練同類題，或回首頁看今日任務狀態。"
        }
        return "如果這段提示有幫助，先去練同類題；如果想照原本節奏走，就回今日任務。"
    }
}

private struct SupportAIResponseCard: View {
    let response: AiProxyResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(response.fallbackUsed ? "內建支持提示" : "AI 支持回覆", systemImage: response.fallbackUsed ? "exclamationmark.triangle.fill" : "sparkles")
                .font(.headline)
                .foregroundStyle(response.fallbackUsed ? EPTheme.warning : EPTheme.support)

            Text(response.fallbackUsed
                ? "目前沒有連到線上 AI。"
                : "線上 AI 已回應")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let summary = response.output.summary {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(EPTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let nextAction = response.output.recommendedNextAction {
                Text(nextAction)
                    .font(.footnote.bold())
                    .foregroundStyle(EPTheme.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if response.output.staffEscalationNeeded == true {
                Text("系統也會把這次求助留給老師或志工接力。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.support.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct StudentRequestCard: View {
    @EnvironmentObject private var learningRepository: LearningRepositoryStore
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
                Text("目前還沒有真人回覆。你可以先看上方 AI 支持建議。")
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
        .onAppear {
            if request.status == .replied {
                learningRepository.markSupportThreadReadByStudent(request.id)
            }
        }
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
