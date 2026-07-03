import SwiftUI

struct SupportView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

    let onOpenPractice: () -> Void
    let onOpenHome: () -> Void

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
                        SupportInboxHeaderCard(
                            onOpenPractice: openPracticeFromSupport,
                            onOpenHome: openHomeFromSupport
                        )

                        SupportMoodAICard(
                            response: latestSupportAIResponse,
                            isLoading: isLoadingSupportAI,
                            onAskAI: sendEmotionalSupportRequest,
                            onOpenPractice: openPracticeFromSupport,
                            onOpenHome: openHomeFromSupport
                        )

                        supportInboxSection
                    }
                    .padding(EPTheme.pagePadding)
                }
            }
            .navigationTitle("支持")
        }
    }

    private var supportInboxSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("回覆中心")
                    .font(.title3.bold())
                    .foregroundStyle(EPTheme.ink)
                Text("練習題送出後，老師、志工或 AI 的回覆都會集中在這裡。看懂後可以收起，列表就不會越堆越亂。")
                    .font(.subheadline)
                    .foregroundStyle(EPTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            SupportReplyCenterSummaryCard(
                waitingCount: waitingRequestCount,
                unreadCount: unreadReplyCount,
                answeredCount: answeredRequestCount
            )

            if studentRequests.isEmpty {
                SupportEmptyStateCard(onOpenPractice: openPracticeFromSupport)
            } else {
                ForEach(studentRequests) { request in
                    SupportRequestInboxCard(
                        request: request,
                        onOpenPractice: openPracticeFromSupport,
                        onArchive: {
                            learningRepository.archiveSupportThreadForStudent(request.id)
                        }
                    )
                }
            }
        }
    }

    private var studentRequests: [StudentSupportRequest] {
        learningRepository.supportRequests(forStudentUid: appState.currentUser?.id)
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var waitingRequestCount: Int {
        studentRequests.filter { $0.status == .open || $0.status == .waitingForStaff }.count
    }

    private var unreadReplyCount: Int {
        studentRequests.filter(\.hasStudentUnreadReply).count
    }

    private var answeredRequestCount: Int {
        studentRequests.filter { request in
            request.status == .replied
                || request.status == .readByStudent
                || !request.replies.filter(\.visibleToStudent).isEmpty
        }.count
    }

    private func sendEmotionalSupportRequest() {
        let option = SeedData.supportOptions.first { $0.route == .recovery }
            ?? SupportOption(
                id: "student-emotional-support",
                reason: "情緒支持",
                studentText: "我現在有點卡住，想先整理情緒再繼續英文。",
                platformAction: "先用 AI 幫學生穩定狀態，再回到任務或練習。",
                route: .recovery
            )

        learningRepository.sendSupportRequest(
            from: appState.currentUser,
            profile: appState.currentProfile,
            option: option,
            message: "我現在有點卡住，想先整理情緒再繼續英文。"
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
}

private struct SupportInboxHeaderCard: View {
    let onOpenPractice: () -> Void
    let onOpenHome: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.title2)
                    .foregroundStyle(EPTheme.support)
                    .frame(width: 36, height: 36)
                    .background(EPTheme.support.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Text("支持中心")
                        .font(.title.bold())
                        .foregroundStyle(EPTheme.ink)
                    Text("這裡不是任務入口，是你和 AI、老師、志工的支援紀錄。")
                        .font(.subheadline)
                        .foregroundStyle(EPTheme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                Button(action: onOpenPractice) {
                    Label("去練習", systemImage: "pencil.and.list.clipboard")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(PrimaryActionButtonStyle())

                Button(action: onOpenHome) {
                    Label("回今日任務", systemImage: "target")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct SupportMoodAICard: View {
    let response: AiProxyResponse?
    let isLoading: Bool
    let onAskAI: () -> Void
    let onOpenPractice: () -> Void
    let onOpenHome: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "sparkles")
                    .foregroundStyle(EPTheme.primary)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text("先讓 AI 幫你整理一下")
                        .font(.headline)
                        .foregroundStyle(EPTheme.ink)
                    Text("如果只是心情卡住，可以先請 AI 幫你把下一步變小。題目卡住時，回到練習題下方送給老師或志工。")
                        .font(.subheadline)
                        .foregroundStyle(EPTheme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button(action: onAskAI) {
                Label(isLoading ? "AI 正在整理..." : "請 AI 陪我整理一下", systemImage: "wand.and.stars")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(isLoading)

            if isLoading {
                ProgressView()
                    .tint(EPTheme.primary)
            }

            if let response {
                SupportAIResponseCard(response: response)
                SupportAIActionCard(
                    response: response,
                    onOpenPractice: onOpenPractice,
                    onOpenHome: onOpenHome
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.support.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct SupportAIActionCard: View {
    let response: AiProxyResponse
    let onOpenPractice: () -> Void
    let onOpenHome: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("接下來可以做這個")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)

            Text(actionHint)
                .font(.subheadline)
                .foregroundStyle(EPTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button(action: onOpenPractice) {
                    Label("去練習", systemImage: "target")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(PrimaryActionButtonStyle())

                Button(action: onOpenHome) {
                    Label("回今日任務", systemImage: "house")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private var actionHint: String {
        if response.output.staffEscalationNeeded == true {
            return "如果 AI 判斷需要真人協助，先去練習題目下方把那一題送給老師或志工。"
        }
        return "先做一小步就好，可以回今日任務，也可以去練習中心挑短題組。"
    }
}

private struct SupportAIResponseCard: View {
    let response: AiProxyResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(response.fallbackUsed ? "先用內建建議" : "AI 已整理", systemImage: response.fallbackUsed ? "exclamationmark.triangle.fill" : "sparkles")
                .font(.subheadline.bold())
                .foregroundStyle(response.fallbackUsed ? EPTheme.warning : EPTheme.support)

            if let summary = response.output.summary, !summary.isEmpty {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(EPTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let nextAction = response.output.recommendedNextAction, !nextAction.isEmpty {
                Text(nextAction)
                    .font(.footnote.bold())
                    .foregroundStyle(EPTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct SupportEmptyStateCard: View {
    let onOpenPractice: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("目前沒有求助紀錄", systemImage: "tray")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)

            Text("開始練習後，如果某一題看不懂，可以在題目下方直接問 AI，或把那一題送給老師/志工。")
                .font(.subheadline)
                .foregroundStyle(EPTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onOpenPractice) {
                Label("去練習中心", systemImage: "arrow.right.circle.fill")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(PrimaryActionButtonStyle())
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct SupportReplyCenterSummaryCard: View {
    let waitingCount: Int
    let unreadCount: Int
    let answeredCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("回覆中心狀態", systemImage: "tray.full")
                    .font(.headline)
                    .foregroundStyle(EPTheme.ink)
                Spacer()
                if unreadCount > 0 {
                    Text("\(unreadCount) 則新回覆")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(EPTheme.primary)
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: 8) {
                SupportInboxMetricPill(title: "待回覆", value: "\(waitingCount)", tint: EPTheme.warning)
                SupportInboxMetricPill(title: "新回覆", value: "\(unreadCount)", tint: EPTheme.primary)
                SupportInboxMetricPill(title: "已回覆", value: "\(answeredCount)", tint: EPTheme.support)
            }

            Text("有新回覆時先看解析；看懂後可以把那筆收起，之後仍會保留在後端紀錄。")
                .font(.caption)
                .foregroundStyle(EPTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct SupportInboxMetricPill: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(EPTheme.secondaryInk)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct SupportRequestInboxCard: View {
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

    let request: StudentSupportRequest
    let onOpenPractice: () -> Void
    let onArchive: () -> Void

    private var visibleReplies: [SupportReply] {
        request.replies.filter(\.visibleToStudent)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(routeTitle)
                        .font(.headline)
                        .foregroundStyle(EPTheme.ink)

                    Text(request.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(EPTheme.secondaryInk)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    if request.hasStudentUnreadReply {
                        Text("新回覆")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(EPTheme.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Text(statusTitle)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(statusColor)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            if let snapshot = request.questionSnapshot {
                SupportQuestionSnapshotCard(
                    snapshot: snapshot,
                    title: "你送出的題目",
                    showsExplanation: true
                )
            } else if request.latestQuestionId?.isEmpty == false {
                Label("這筆求助有題目紀錄，但目前缺少完整題目快照。", systemImage: "doc.text")
                    .font(.caption.bold())
                    .foregroundStyle(EPTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(10)
                    .background(EPTheme.secondarySurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Text(request.studentMessage)
                .font(.subheadline)
                .foregroundStyle(EPTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            if visibleReplies.isEmpty {
                SupportWaitingReplyCard(route: request.route)
            } else {
                SupportReplyTimeline(replies: visibleReplies)
                SupportThreadActionRow(
                    onArchive: onArchive,
                    onOpenPractice: onOpenPractice
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
        .onAppear {
            if request.status == .replied {
                learningRepository.markSupportThreadReadByStudent(request.id)
            }
        }
    }

    private var routeTitle: String {
        switch request.route {
        case .aiCoach:
            return "AI 解題紀錄"
        case .humanHandoff:
            return "老師協助"
        case .readingBreakdown:
            return "志工陪伴"
        case .recovery:
            return "情緒支持"
        }
    }

    private var statusTitle: String {
        switch request.status {
        case .open, .waitingForStaff:
            return "等待回覆"
        case .replied:
            return "有新回覆"
        case .readByStudent:
            return "已讀"
        case .staffHandledNoReply:
            return "已處理"
        case .archived:
            return "已歸檔"
        case .closed:
            return "已結束"
        }
    }

    private var statusColor: Color {
        switch request.status {
        case .open, .waitingForStaff:
            return EPTheme.warning
        case .replied:
            return EPTheme.primary
        case .readByStudent:
            return EPTheme.support
        case .staffHandledNoReply:
            return EPTheme.support
        case .archived:
            return EPTheme.secondaryInk
        case .closed:
            return EPTheme.secondaryInk
        }
    }
}

private struct SupportThreadActionRow: View {
    let onArchive: () -> Void
    let onOpenPractice: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("看完回覆後的下一步", systemImage: "checkmark.seal.fill")
                .font(.subheadline.bold())
                .foregroundStyle(EPTheme.support)

            Text("收起後不會刪除資料，只是不再顯示在你的回覆中心；如果還想練同類題，可以直接回練習中心。")
                .font(.footnote)
                .foregroundStyle(EPTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button(action: onArchive) {
                    Label("我看懂了，收起這筆", systemImage: "archivebox")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(SecondaryActionButtonStyle())

                Button(action: onOpenPractice) {
                    Label("回練習中心", systemImage: "target")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(PrimaryActionButtonStyle())
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.support.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct SupportWaitingReplyCard: View {
    let route: SupportRoute

    var body: some View {
        Label(waitingText, systemImage: "clock")
            .font(.footnote)
            .foregroundStyle(EPTheme.secondaryInk)
            .fixedSize(horizontal: false, vertical: true)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EPTheme.secondarySurface)
            .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private var waitingText: String {
        switch route {
        case .humanHandoff:
            return "已送給老師，回覆後會出現在這裡。"
        case .readingBreakdown:
            return "已送給志工，回覆後會出現在這裡。"
        case .aiCoach:
            return "AI 建議會顯示在這裡。"
        case .recovery:
            return "先休息一下，AI 或老師回覆後會出現在這裡。"
        }
    }
}

private struct SupportReplyTimeline: View {
    let replies: [SupportReply]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("老師/志工回覆")
                .font(.caption.bold())
                .foregroundStyle(EPTheme.secondaryInk)

            ForEach(replies) { reply in
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(reply.authorName)
                            .font(.caption.bold())
                            .foregroundStyle(EPTheme.support)
                        Spacer()
                        Text(reply.createdAt.formatted(date: .omitted, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(EPTheme.secondaryInk)
                    }

                    Text(reply.body)
                        .font(.footnote)
                        .foregroundStyle(EPTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(EPTheme.secondarySurface)
                .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
            }
        }
    }
}
