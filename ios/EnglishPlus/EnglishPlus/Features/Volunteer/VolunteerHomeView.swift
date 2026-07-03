import SwiftUI

struct VolunteerHomeView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VolunteerHeaderCard()
                        VolunteerMetricStrip()

                        if let firstRequest = learningRepository.volunteerQueue.first {
                            VolunteerTodayPriorityCard(request: firstRequest)
                        } else {
                            VolunteerEmptyQueueCard()
                        }

                        VolunteerCompanionScriptCard(compact: true)
                    }
                    .padding(EPTheme.pagePadding)
                }
            }
            .navigationTitle("志工工作台")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        appState.signOut()
                    } label: {
                        Label("登出", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
        }
    }
}

struct VolunteerHandoffWorkspaceView: View {
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

    @State private var selectedRequestId: String?

    private var selectedRequest: StudentSupportRequest? {
        if let selectedRequestId,
           let request = learningRepository.volunteerQueue.first(where: { $0.id == selectedRequestId }) {
            return request
        }
        return learningRepository.volunteerQueue.first
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("接力學生")
                            .font(.title.bold())
                            .foregroundStyle(EPTheme.ink)

                        Text("先接住，再陪一題。志工只需要看卡住原因、題目脈絡，留下學生看得懂的一段回覆。")
                            .font(.subheadline)
                            .foregroundStyle(EPTheme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)

                        StaffSupportQueueHeaderCard(
                            title: "待接力",
                            subtitle: "學生需要陪伴、閱讀提示或題目拆解時會出現在這裡。未處理紅點代表待接力數，回覆、已讀不回或收起後會從待辦移除。",
                            waitingCount: learningRepository.volunteerQueue.count,
                            highPriorityCount: learningRepository.volunteerQueue.filter { $0.priority == .high }.count,
                            handledCount: learningRepository.volunteerDashboardMetrics.repliedByVolunteerCount,
                            tint: EPTheme.support
                        )

                        VolunteerQueuePickerCard(
                            requests: learningRepository.volunteerQueue,
                            selectedRequestId: $selectedRequestId
                        )

                        if let selectedRequest {
                            VolunteerSelectedSupportPanel(request: selectedRequest)
                            VolunteerQuestionContextCard(request: selectedRequest)
                            VolunteerCompanionScriptCard(compact: false)
                            VolunteerStaffReplyComposerCard(request: selectedRequest)
                        } else {
                            VolunteerEmptyQueueCard()
                        }
                    }
                    .padding(EPTheme.pagePadding)
                }
            }
            .navigationTitle("接力")
        }
    }
}

private struct VolunteerStaffReplyComposerCard: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

    let request: StudentSupportRequest

    @State private var replyDraft = ""
    @State private var isDraftingWithAI = false
    @State private var confirmationText: String?

    private var canReply: Bool {
        !replyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("4. 回覆或處理")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)

            Text("志工可以先用 AI 整理陪伴語氣，再送出給學生；如果這筆已經不需要回覆，也可以標記已讀不回或收起。")
                .font(.subheadline)
                .foregroundStyle(EPTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            TextField("輸入陪伴回覆，例如：你已經抓到問題了，我們先把主詞和動詞分開看。", text: $replyDraft, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)

            Button(isDraftingWithAI ? "AI 正在整理建議" : "用 AI 產生陪伴草稿") {
                Task {
                    await fillVolunteerDraftWithAI()
                }
            }
            .buttonStyle(SecondaryActionButtonStyle())
            .disabled(isDraftingWithAI)

            StaffSupportActionBar(
                canReply: canReply,
                sendReply: {
                    learningRepository.addVolunteerReply(to: request.id, body: replyDraft)
                    replyDraft = ""
                    confirmationText = "已送出給學生，待接力數會同步更新。"
                },
                markHandledWithoutReply: {
                    learningRepository.markSupportThreadHandledWithoutReply(request.id, by: appState.currentUser)
                    confirmationText = "已標記為已讀不回。"
                },
                archiveThread: {
                    learningRepository.archiveSupportThreadForStaff(request.id, by: appState.currentUser)
                    confirmationText = "已從待接力列表收起。"
                }
            )

            if let confirmationText {
                Label(confirmationText, systemImage: "checkmark.circle.fill")
                    .font(.footnote.bold())
                    .foregroundStyle(EPTheme.support)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
        .onChange(of: request.id) { _, _ in
            replyDraft = ""
            confirmationText = nil
        }
    }

    private func fillVolunteerDraftWithAI() async {
        isDraftingWithAI = true
        let response = await appState.coachVolunteerReplyWithAI(context: SupportAIContext(request: request))
        replyDraft = response.output.studentFacingFeedback
            ?? response.output.recommendedNextAction
            ?? response.output.summary
            ?? replyDraft
        isDraftingWithAI = false
    }
}

struct VolunteerRecordView: View {
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

    private var repliedRequests: [StudentSupportRequest] {
        learningRepository.supportRequests
            .filter { request in
                request.replies.contains { $0.authorRole == .volunteer }
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("接力紀錄")
                            .font(.title.bold())
                            .foregroundStyle(EPTheme.ink)

                        Text("這裡保留已送出的志工回覆，方便下一位老師或志工接續。")
                            .font(.subheadline)
                            .foregroundStyle(EPTheme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)

                        VolunteerRecordStatusCard()

                        if repliedRequests.isEmpty {
                            EmptyRecordCard()
                        } else {
                            ForEach(repliedRequests) { request in
                                VolunteerRecordRequestCard(request: request)
                            }
                        }
                    }
                    .padding(EPTheme.pagePadding)
                }
            }
            .navigationTitle("紀錄")
        }
    }
}

private struct VolunteerHeaderCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("English+")
                        .font(.headline)
                    Text("偏鄉學生雙軌學習平台")
                        .font(.subheadline.bold())
                }
                Spacer()
                Text("接力陪伴")
                    .font(.caption.bold())
                    .foregroundStyle(EPTheme.support)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(EPTheme.support.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Text("今天先接住誰？")
                .font(.title2.bold())
                .foregroundStyle(EPTheme.ink)

            Text("只處理已送出的求助，不看老師管理資訊；每次回覆都會回到學生支援紀錄。")
                .font(.subheadline)
                .foregroundStyle(EPTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct VolunteerMetricStrip: View {
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

    var body: some View {
        HStack(spacing: 10) {
            VolunteerMetricTile(
                title: "待接力",
                value: "\(learningRepository.volunteerDashboardMetrics.waitingCount)",
                tint: EPTheme.primary
            )
            VolunteerMetricTile(
                title: "優先",
                value: "\(learningRepository.volunteerDashboardMetrics.highPriorityCount)",
                tint: EPTheme.warning
            )
            VolunteerMetricTile(
                title: "已回覆",
                value: "\(learningRepository.volunteerDashboardMetrics.repliedByVolunteerCount)",
                tint: EPTheme.support
            )
        }
    }
}

private struct VolunteerMetricTile: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(tint)
            Text(title)
                .font(.caption)
                .foregroundStyle(EPTheme.secondaryInk)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct VolunteerTodayPriorityCard: View {
    let request: StudentSupportRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("第一優先接力", systemImage: "flag.fill")
                .font(.headline)
                .foregroundStyle(EPTheme.support)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(request.studentName)
                        .font(.title3.bold())
                        .foregroundStyle(EPTheme.ink)
                    Text(statusSummary)
                        .font(.caption)
                        .foregroundStyle(EPTheme.secondaryInk)
                }
                Spacer()
                Text(request.priority.uiTitle)
                    .font(.caption.bold())
                    .foregroundStyle(request.priority == .high ? EPTheme.warning : EPTheme.support)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background((request.priority == .high ? EPTheme.warning : EPTheme.support).opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Text(request.studentMessage)
                .font(.subheadline)
                .foregroundStyle(EPTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("到「接力」頁面後，可以用 AI 產生草稿，再送出學生看得到的回覆。")
                .font(.footnote)
                .foregroundStyle(EPTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private var statusSummary: String {
        if let moodScore = request.moodScore {
            return "\(request.classCode) · 心情 \(moodScore)/5 · \(request.status.uiTitle)"
        }
        return "\(request.classCode) · \(request.status.uiTitle)"
    }
}

private struct VolunteerQueuePickerCard: View {
    let requests: [StudentSupportRequest]
    @Binding var selectedRequestId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("1. 選擇要接住的學生")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)

            if requests.isEmpty {
                Text("目前沒有等待志工接力的學生。")
                    .font(.subheadline)
                    .foregroundStyle(EPTheme.secondaryInk)
            } else {
                ForEach(requests) { request in
                    Button {
                        selectedRequestId = request.id
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(request.studentName)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(EPTheme.ink)
                                Text(queueSubtitle(for: request))
                                    .font(.caption)
                                    .foregroundStyle(EPTheme.secondaryInk)
                            }
                            Spacer()
                            Text(request.priority.uiTitle)
                                .font(.caption.bold())
                                .foregroundStyle(request.priority == .high ? EPTheme.warning : EPTheme.support)
                        }
                        .padding(12)
                        .background(isSelected(request) ? EPTheme.support.opacity(0.12) : EPTheme.secondarySurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected(request) ? EPTheme.support : Color.clear, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private func isSelected(_ request: StudentSupportRequest) -> Bool {
        selectedRequestId == request.id || (selectedRequestId == nil && requests.first?.id == request.id)
    }

    private func queueSubtitle(for request: StudentSupportRequest) -> String {
        if let moodScore = request.moodScore {
            return "\(request.classCode) · 心情 \(moodScore)/5"
        }
        return request.classCode
    }
}

private struct VolunteerSelectedSupportPanel: View {
    let request: StudentSupportRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("2. 看懂卡點")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)

            HStack(spacing: 10) {
                VolunteerStatusTile(title: "學生", value: request.studentName)
                VolunteerStatusTile(title: "狀態", value: request.status.uiTitle)
                VolunteerStatusTile(title: "路線", value: reasonTitle)
            }

            Text(request.studentMessage)
                .font(.subheadline)
                .foregroundStyle(EPTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(nextStep)
                .font(.footnote.bold())
                .foregroundStyle(EPTheme.support)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private var reasonTitle: String {
        switch request.reason {
        case .readingHelp:
            return "閱讀"
        case .emotionalSupport:
            return "情緒"
        case .teacherRequested:
            return "老師"
        case .stuckOnQuestion:
            return "錯題"
        }
    }

    private var nextStep: String {
        switch request.reason {
        case .readingHelp:
            return "下一步：先讓學生指出句子裡看不懂的位置，再陪他找主詞和動詞。"
        case .emotionalSupport:
            return "下一步：先肯定他願意求助，再陪一個低壓題，不追加任務。"
        case .teacherRequested:
            return "下一步：依老師交代陪同一個概念，回覆時保留可接續的線索。"
        case .stuckOnQuestion:
            return "下一步：先看他選了什麼，再給一個提示讓他能重試。"
        }
    }
}

private struct VolunteerQuestionContextCard: View {
    let request: StudentSupportRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("3. 題目脈絡")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)

            if let snapshot = request.questionSnapshot {
                Text("先看學生答案與正解，再回一個能讓學生重試的小提示。")
                    .font(.subheadline)
                    .foregroundStyle(EPTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                SupportQuestionSnapshotCard(
                    snapshot: snapshot,
                    title: "學生答案與正解",
                    showsExplanation: true
                )
            } else if request.latestQuestionId?.isEmpty == false {
                Label("這筆求助有題目紀錄，但目前缺少完整題目快照。", systemImage: "doc.text.magnifyingglass")
                    .font(.subheadline.bold())
                    .foregroundStyle(EPTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Label("這次求助沒有綁定單一題目", systemImage: "text.bubble")
                    .font(.subheadline.bold())
                    .foregroundStyle(EPTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("回覆時不要直接給長篇答案，先給一個能讓學生重試的提示。送出後學生會在支援紀錄看到這段回覆。")
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

private struct VolunteerCompanionScriptCard: View {
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("陪伴順序", systemImage: "text.bubble")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)

            ForEach(VolunteerScriptTemplate.defaults.prefix(compact ? 2 : 3)) { template in
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(EPTheme.ink)
                    Text(template.body)
                        .font(.footnote)
                        .foregroundStyle(EPTheme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(EPTheme.secondarySurface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct VolunteerStatusTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(EPTheme.secondaryInk)
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(EPTheme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.secondarySurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct VolunteerRecordStatusCard: View {
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("接力紀錄已保存", systemImage: "checkmark.circle")
                .font(.headline)
                .foregroundStyle(EPTheme.support)
            Text("已累積 \(learningRepository.volunteerDashboardMetrics.syncRecordCount) 筆陪伴回覆與追蹤紀錄。")
                .font(.subheadline)
                .foregroundStyle(EPTheme.secondaryInk)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct VolunteerRecordRequestCard: View {
    let request: StudentSupportRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(request.studentName)
                        .font(.headline)
                        .foregroundStyle(EPTheme.ink)
                    Text(request.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(EPTheme.secondaryInk)
                }
                Spacer()
                Text(request.status.uiTitle)
                    .font(.caption.bold())
                    .foregroundStyle(EPTheme.support)
            }

            Text(request.studentMessage)
                .font(.footnote)
                .foregroundStyle(EPTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(request.replies.filter { $0.authorRole == .volunteer }) { reply in
                Text(reply.body)
                    .font(.subheadline)
                    .foregroundStyle(EPTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(EPTheme.secondarySurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct VolunteerEmptyQueueCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("目前沒有等待接力的學生", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(EPTheme.support)
            Text("學生從練習題送出求助後，這裡會出現最需要陪伴的一小步。")
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

private struct EmptyRecordCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("目前沒有志工回覆紀錄", systemImage: "tray")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)
            Text("接力學生後，回覆內容會留在這裡，方便下一位老師或志工接續。")
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

struct VolunteerScriptTemplate: Identifiable {
    let id: String
    let title: String
    let body: String

    static let defaults = [
        VolunteerScriptTemplate(
            id: "affirm",
            title: "先接住情緒",
            body: "你不是完全不會，是卡在其中一小段。我們先只看這一句，不急著做完全部。"
        ),
        VolunteerScriptTemplate(
            id: "retry",
            title: "再陪一個卡點",
            body: "剛剛那題錯得有線索。你先告訴我你排除了哪個選項，我們再一起看剩下的。"
        ),
        VolunteerScriptTemplate(
            id: "finish",
            title: "最後留下接續線索",
            body: "今天先到這裡就很好。你已經完成一小步，我會把下一步留給老師接續。"
        ),
    ]
}
