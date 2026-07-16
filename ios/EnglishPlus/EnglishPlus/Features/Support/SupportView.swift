import SwiftUI

struct SupportView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
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
                Text("練習題送出後，老師與志工的回覆會集中在這裡。看懂後可以收起，列表就不會越堆越亂。")
                    .font(.subheadline)
                    .foregroundStyle(EPTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if appState.currentProfile?.activeClassId == nil {
                PersonalSupportModeCard()
            } else if studentRequests.isEmpty {
                SupportEmptyStateCard()
            } else {
                SupportReplyCenterSummaryCard(
                    waitingCount: waitingRequestCount,
                    unreadCount: unreadReplyCount,
                    answeredCount: answeredRequestCount
                )

                ForEach(studentRequests) { request in
                    SupportRequestInboxCard(
                        request: request,
                        isProcessing: learningRepository.isSupportActionPending(for: request.id),
                        onArchive: {
                            Task {
                                _ = await learningRepository.archiveSupportThreadForStudent(request.id)
                            }
                        }
                    )
                }
            }
        }
        .accessibilityIdentifier("student.support.inbox")
    }

    private var studentRequests: [StudentSupportRequest] {
        learningRepository.supportRequests(forStudentUid: appState.currentUser?.id)
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var waitingRequestCount: Int {
        studentRequests.filter(\.isWaitingForStaffAction).count
    }

    private var unreadReplyCount: Int {
        studentRequests.filter(\.hasStudentUnreadReply).count
    }

    private var answeredRequestCount: Int {
        studentRequests.filter { !$0.visibleStaffRepliesToStudent.isEmpty }.count
    }

}

private struct PersonalSupportModeCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("目前是個人學習模式", systemImage: "person.crop.circle")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)

            Text("做題時仍可直接請 AI 換一種方式解釋。加入班級後，老師或志工的真人回覆才會出現在這裡。")
                .font(.subheadline)
                .foregroundStyle(EPTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct SupportEmptyStateCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("目前沒有求助紀錄", systemImage: "tray")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)

            Text("開始練習後，如果某一題看不懂，可以在題目下方直接問 AI，或把那一題送給老師與志工。")
                .font(.subheadline)
                .foregroundStyle(EPTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
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

private struct SupportOriginalStudentMessageCard: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("你的補充")
                .font(.caption.bold())
                .foregroundStyle(EPTheme.secondaryInk)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(EPTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.secondarySurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct SupportRequestInboxCard: View {
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

    @State private var replyPendingReport: SupportReply?
    @State private var replyPendingBlock: SupportReply?
    @State private var safetyNotice: String?
    @State private var showsSafetyNotice = false

    let request: StudentSupportRequest
    let isProcessing: Bool
    let onArchive: () -> Void

    private var visibleReplies: [SupportReply] {
        request.visibleStaffRepliesToStudent
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
            } else if request.latestQuestionId?.isEmpty == false
                        && !request.hasActionableHumanSupportContext {
                Label("這筆求助有題目紀錄，但目前缺少完整題目快照。", systemImage: "doc.text")
                    .font(.caption.bold())
                    .foregroundStyle(EPTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(10)
                    .background(EPTheme.secondarySurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if request.questionSnapshot == nil {
                SupportOriginalStudentMessageCard(message: request.studentMessage)
            }

            if visibleReplies.isEmpty {
                SupportWaitingReplyCard(route: request.route)
                if request.canStudentWithdrawBeforeReply {
                    SupportWithdrawRequestRow(
                        isProcessing: isProcessing,
                        onWithdraw: {
                            Task {
                                _ = await learningRepository.withdrawSupportRequest(request.id)
                            }
                        }
                    )
                } else if request.canStudentArchiveAfterStaffArchivedWithoutReply {
                    SupportThreadActionRow(
                        title: "這筆目前沒有回覆",
                        message: "老師與志工都已把這筆從待辦收起；你也可以把它收起，避免回覆中心一直累積。",
                        buttonTitle: "收起這筆",
                        systemImage: "archivebox",
                        isProcessing: isProcessing,
                        onArchive: onArchive
                    )
                }
            } else {
                SupportReplyTimeline(
                    replies: visibleReplies,
                    onReport: { replyPendingReport = $0 },
                    onBlock: { replyPendingBlock = $0 }
                )
                SupportThreadActionRow(
                    isProcessing: isProcessing,
                    onArchive: onArchive
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
        .onAppear {
            if request.hasStudentUnreadReply {
                Task {
                    _ = await learningRepository.markSupportThreadReadByStudent(request.id)
                }
            }
        }
        .confirmationDialog(
            "為什麼要檢舉這則回覆？",
            isPresented: reportDialogBinding,
            titleVisibility: .visible,
            presenting: replyPendingReport
        ) { reply in
            ForEach(SupportSafetyReportReason.allCases) { reason in
                Button(reason.title) {
                    submitReport(reply: reply, reason: reason)
                }
            }
            Button("取消", role: .cancel) {}
        } message: { _ in
            Text("檢舉會交由 English+ 管理者檢視，不會通知回覆者。")
        }
        .confirmationDialog(
            "封鎖這位回覆者？",
            isPresented: blockDialogBinding,
            titleVisibility: .visible,
            presenting: replyPendingBlock
        ) { reply in
            Button("封鎖並收起這筆", role: .destructive) {
                block(reply: reply)
            }
            Button("取消", role: .cancel) {}
        } message: { reply in
            Text("封鎖 \(reply.authorName) 後，對方將不能再回覆你的求助，這筆對話也會從回覆中心收起。")
        }
        .alert("處理結果", isPresented: $showsSafetyNotice) {
            Button("好", role: .cancel) {}
        } message: {
            Text(safetyNotice ?? "操作已完成。")
        }
    }

    private var reportDialogBinding: Binding<Bool> {
        Binding(
            get: { replyPendingReport != nil },
            set: { isPresented in
                if !isPresented { replyPendingReport = nil }
            }
        )
    }

    private var blockDialogBinding: Binding<Bool> {
        Binding(
            get: { replyPendingBlock != nil },
            set: { isPresented in
                if !isPresented { replyPendingBlock = nil }
            }
        )
    }

    private func submitReport(reply: SupportReply, reason: SupportSafetyReportReason) {
        Task {
            let didReport = await learningRepository.reportSupportReply(
                requestId: request.id,
                reply: reply,
                reason: reason
            )
            safetyNotice = didReport
                ? "已送出檢舉，管理者會依回覆內容與原因進行檢視。"
                : "目前無法送出檢舉，請稍後再試。"
            showsSafetyNotice = true
        }
    }

    private func block(reply: SupportReply) {
        Task {
            let didBlock = await learningRepository.blockSupportAuthor(reply, requestId: request.id)
            safetyNotice = didBlock
                ? "已封鎖這位回覆者，並收起目前對話。"
                : "目前無法完成封鎖，請稍後再試。"
            showsSafetyNotice = true
        }
    }

    private var routeTitle: String {
        switch request.route {
        case .aiCoach:
            return "AI 解題紀錄"
        case .humanHandoff:
            return "老師/志工協助"
        case .readingBreakdown:
            return "老師/志工協助"
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
    var title: String = "看完回覆後的下一步"
    var message: String = "收起後不會刪除資料，只是不再顯示在你的回覆中心。需要繼續練習時，直接用下方分頁切回練習中心。"
    var buttonTitle: String = "我看懂了，收起這筆"
    var systemImage: String = "archivebox"
    var isProcessing: Bool = false
    let onArchive: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: "checkmark.seal.fill")
                .font(.subheadline.bold())
                .foregroundStyle(EPTheme.support)

            Text(message)
                .font(.footnote)
                .foregroundStyle(EPTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onArchive) {
                Label(isProcessing ? "同步中" : buttonTitle, systemImage: systemImage)
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(SecondaryActionButtonStyle())
            .disabled(isProcessing)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.support.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct SupportWithdrawRequestRow: View {
    let isProcessing: Bool
    let onWithdraw: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("還沒有人回覆", systemImage: "arrow.uturn.backward.circle.fill")
                .font(.subheadline.bold())
                .foregroundStyle(EPTheme.warning)

            Text("如果這題已經不需要協助，可以先收回。收回後老師與志工端會同步消失，紅點提醒也會移除。")
                .font(.footnote)
                .foregroundStyle(EPTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onWithdraw) {
                Label(isProcessing ? "正在收回" : "收回這題", systemImage: "arrow.uturn.backward")
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(SecondaryActionButtonStyle())
            .disabled(isProcessing)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.warning.opacity(0.10))
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
            return "已送給老師與志工，回覆後會出現在這裡。"
        case .readingBreakdown:
            return "已送給老師與志工，回覆後會出現在這裡。"
        case .aiCoach:
            return "AI 建議會顯示在這裡。"
        case .recovery:
            return "你已主動送給老師與志工；有人回覆後會顯示在這裡。這不是即時緊急服務。"
        }
    }
}

private struct SupportReplyTimeline: View {
    let replies: [SupportReply]
    let onReport: (SupportReply) -> Void
    let onBlock: (SupportReply) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("老師/志工回覆")
                .font(.caption.bold())
                .foregroundStyle(EPTheme.secondaryInk)

            ForEach(replies) { reply in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(reply.authorName)
                            .font(.caption.bold())
                            .foregroundStyle(EPTheme.support)
                        Spacer()
                        Text(reply.createdAt.formatted(date: .omitted, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(EPTheme.secondaryInk)

                        Menu {
                            Button {
                                onReport(reply)
                            } label: {
                                Label("檢舉這則回覆", systemImage: "exclamationmark.bubble")
                            }

                            Button(role: .destructive) {
                                onBlock(reply)
                            } label: {
                                Label("封鎖這位回覆者", systemImage: "person.crop.circle.badge.xmark")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.body)
                                .foregroundStyle(EPTheme.secondaryInk)
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("回覆選項")
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
