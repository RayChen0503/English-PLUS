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
                SupportEmptyStateCard()
            } else {
                ForEach(studentRequests) { request in
                    SupportRequestInboxCard(
                        request: request,
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

}

private struct SupportEmptyStateCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("目前沒有求助紀錄", systemImage: "tray")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)

            Text("開始練習後，如果某一題看不懂，可以在題目下方直接問 AI，或把那一題送給老師/志工。")
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

private struct SupportRequestInboxCard: View {
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

    let request: StudentSupportRequest
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
                    onArchive: onArchive
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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("看完回覆後的下一步", systemImage: "checkmark.seal.fill")
                .font(.subheadline.bold())
                .foregroundStyle(EPTheme.support)

            Text("收起後不會刪除資料，只是不再顯示在你的回覆中心。需要繼續練習時，直接用下方分頁切回練習中心。")
                .font(.footnote)
                .foregroundStyle(EPTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onArchive) {
                Label("我看懂了，收起這筆", systemImage: "archivebox")
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(SecondaryActionButtonStyle())
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
