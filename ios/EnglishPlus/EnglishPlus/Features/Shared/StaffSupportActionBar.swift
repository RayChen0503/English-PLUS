import SwiftUI

enum StaffSupportWorkspaceRole {
    case teacher
    case volunteer

    var title: String {
        switch self {
        case .teacher: return "老師"
        case .volunteer: return "志工"
        }
    }
}

struct StaffSupportQueueHeaderCard: View {
    let title: String
    let subtitle: String
    let waitingCount: Int
    let highPriorityCount: Int
    let handledCount: Int
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "bell.badge")
                    .font(.title3.bold())
                    .foregroundStyle(tint)
                    .frame(width: 40, height: 40)
                    .background(tint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(EPTheme.ink)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(EPTheme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if waitingCount > 0 {
                    Text("\(waitingCount)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .frame(minWidth: 28, minHeight: 28)
                        .padding(.horizontal, 2)
                        .background(EPTheme.warning)
                        .clipShape(Capsule())
                        .accessibilityLabel("未處理 \(waitingCount) 件")
                }
            }

            HStack(spacing: 10) {
                StaffSupportMetricPill(title: "未處理", value: "\(waitingCount)", tint: EPTheme.warning)
                StaffSupportMetricPill(title: "高優先", value: "\(highPriorityCount)", tint: EPTheme.primary)
                StaffSupportMetricPill(title: "已處理", value: "\(handledCount)", tint: EPTheme.support)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct StaffSupportMetricPill: View {
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
                .monospacedDigit()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct StaffSupportActionBar: View {
    let canReply: Bool
    let isProcessing: Bool
    let sendReply: () -> Void
    let archiveThread: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("處理這筆求助")
                .font(.subheadline.bold())
                .foregroundStyle(EPTheme.ink)

            Button(action: sendReply) {
                Label(isProcessing ? "正在同步" : "送出回覆", systemImage: "paperplane.fill")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(!canReply || isProcessing)
            .opacity(canReply && !isProcessing ? 1 : 0.45)

            Button(action: archiveThread) {
                Label("收起", systemImage: "archivebox")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(SecondaryActionButtonStyle())
            .disabled(isProcessing)

            Text("收起只會從你的待辦移除，不會刪除學生資料；另一端仍可看見並選擇是否補充回覆。")
                .font(.caption)
                .foregroundStyle(EPTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(EPTheme.support.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct StaffSupportQueueRow: View {
    let request: StudentSupportRequest

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: request.priority == .high ? "exclamationmark.bubble.fill" : "bubble.left.and.text.bubble.right")
                .font(.headline)
                .foregroundStyle(request.priority == .high ? EPTheme.warning : EPTheme.primary)
                .frame(width: 40, height: 40)
                .background((request.priority == .high ? EPTheme.warning : EPTheme.primary).opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(request.studentName)
                        .font(.headline)
                        .foregroundStyle(EPTheme.ink)
                    Text(request.priority.uiTitle)
                        .font(.caption.bold())
                        .foregroundStyle(request.priority == .high ? EPTheme.warning : EPTheme.support)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(EPTheme.secondaryInk)
                }

                Text(requestSummary)
                    .font(.subheadline)
                    .foregroundStyle(EPTheme.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 3) {
                    Label(request.classCode, systemImage: "person.3")
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        Text(request.updatedAt.formatted(date: .omitted, time: .shortened))
                    if !request.staffReplies.isEmpty {
                        Label("已有 \(request.staffReplies.count) 則回覆", systemImage: "checkmark.circle")
                    }
                    }
                }
                .font(.caption)
                .foregroundStyle(EPTheme.secondaryInk)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(request.studentName)，\(request.priority.uiTitle)，\(requestSummary)")
        .accessibilityHint("點兩下查看題目並回覆")
    }

    private var requestSummary: String {
        if let snapshot = request.questionSnapshot {
            return snapshot.prompt
        }
        if request.hasActionableHumanSupportContext {
            return request.studentMessage
        }
        return "需要查看這筆求助"
    }
}

struct StaffSupportDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

    let initialRequest: StudentSupportRequest
    let role: StaffSupportWorkspaceRole

    @State private var replyDraft = ""
    @State private var isDraftingWithAI = false
    @State private var aiDraftResponse: AiProxyResponse?
    @State private var completionMessage: String?

    private var request: StudentSupportRequest {
        learningRepository.supportRequests.first { $0.id == initialRequest.id } ?? initialRequest
    }

    private var canReply: Bool {
        !replyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            EPTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    requestHeader

                    if let snapshot = request.questionSnapshot {
                        SupportQuestionSnapshotCard(
                            snapshot: snapshot,
                            title: "學生卡住的題目",
                            showsExplanation: true
                        )
                    } else if request.hasActionableHumanSupportContext {
                        StaffHumanSupportRequestCard(message: request.studentMessage)
                    } else {
                        missingContextLabel
                    }

                    if !request.staffReplies.isEmpty {
                        replyHistory
                    }

                    responseComposer

                    if let completionMessage {
                        Label(completionMessage, systemImage: "checkmark.circle.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(EPTheme.support)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(EPTheme.support.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
                    }

                    StaffSupportActionBar(
                        canReply: canReply,
                        isProcessing: learningRepository.isSupportActionPending(for: request.id),
                        sendReply: sendReply,
                        archiveThread: archiveThread
                    )
                }
                .padding(EPTheme.pagePadding)
            }
        }
        .navigationTitle(request.studentName)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("staff.handoff.detail")
    }

    private var requestHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Text(request.priority.uiTitle)
                    .font(.caption.bold())
                    .foregroundStyle(request.priority == .high ? EPTheme.warning : EPTheme.support)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background((request.priority == .high ? EPTheme.warning : EPTheme.support).opacity(0.10))
                    .clipShape(Capsule())
                Text(request.status.uiTitle)
                    .font(.caption.bold())
                    .foregroundStyle(EPTheme.secondaryInk)
                Spacer()
            }

            Text("\(request.classCode) · \(request.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundStyle(EPTheme.secondaryInk)

            if let moodScore = request.moodScore {
                Label("學生今日自評心情 \(moodScore)/5", systemImage: "heart.text.square")
                    .font(.caption)
                    .foregroundStyle(EPTheme.secondaryInk)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var replyHistory: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("老師與志工的回覆")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)

            ForEach(request.staffReplies) { reply in
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(reply.authorName)
                            .font(.subheadline.bold())
                            .foregroundStyle(EPTheme.support)
                        Spacer()
                        Text(reply.createdAt.formatted(date: .omitted, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(EPTheme.secondaryInk)
                    }
                    Text(reply.body)
                        .font(.subheadline)
                        .foregroundStyle(EPTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(EPTheme.secondarySurface)
                .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
            }
        }
    }

    private var responseComposer: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("回覆學生")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)

            TextField("寫下學生下一步做得到的提示", text: $replyDraft, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("staff.handoff.reply")

            Button(isDraftingWithAI ? "AI 正在整理草稿" : "用 AI 協助起草") {
                Task { await fillDraftWithAI() }
            }
            .buttonStyle(SecondaryActionButtonStyle())
            .disabled(isDraftingWithAI)

            if let aiDraftResponse {
                StaffAIDraftCard(
                    response: aiDraftResponse,
                    roleTitle: role.title,
                    onApply: {
                        if let draft = aiDraftResponse.output.studentFacingFeedback,
                           !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            replyDraft = draft
                        }
                    }
                )
            }
        }
        .accessibilityIdentifier("staff.handoff.composer")
    }

    private var missingContextLabel: some View {
        Label("這筆接力缺少可回覆的題目或訊息。", systemImage: "doc.text.magnifyingglass")
            .font(.subheadline)
            .foregroundStyle(EPTheme.secondaryInk)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EPTheme.secondarySurface)
            .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private func sendReply() {
        Task {
            let succeeded: Bool
            switch role {
            case .teacher:
                succeeded = await learningRepository.addTeacherReply(to: request.id, body: replyDraft)
            case .volunteer:
                succeeded = await learningRepository.addVolunteerReply(to: request.id, body: replyDraft)
            }
            if succeeded {
                replyDraft = ""
                aiDraftResponse = nil
                completionMessage = "回覆已同步給學生。"
            }
        }
    }

    private func archiveThread() {
        Task {
            if await learningRepository.archiveSupportThreadForStaff(request.id, by: appState.currentUser) {
                dismiss()
            }
        }
    }

    @MainActor
    private func fillDraftWithAI() async {
        isDraftingWithAI = true
        defer { isDraftingWithAI = false }

        switch role {
        case .teacher:
            aiDraftResponse = await appState.draftTeacherFeedbackWithAI(
                context: SupportAIContext(request: request)
            )
        case .volunteer:
            aiDraftResponse = await appState.coachVolunteerReplyWithAI(
                context: SupportAIContext(request: request)
            )
        }
    }
}
