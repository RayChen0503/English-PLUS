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

    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("接力優先序")
                            .font(.title.bold())
                            .foregroundStyle(EPTheme.ink)

                        Text("排序規則：學生主動求助、高風險心情、閱讀卡點會先排在前面。")
                            .font(.subheadline)
                            .foregroundStyle(EPTheme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)

                        StaffSupportQueueHeaderCard(
                            title: "待回覆接力",
                            subtitle: "學生把卡住的題目送出後，老師與志工都會收到同一筆接力。任何一端回覆都會消除雙方紅點；收起只影響自己的待辦。",
                            waitingCount: learningRepository.volunteerDashboardMetrics.waitingCount,
                            highPriorityCount: learningRepository.volunteerQueue.filter { $0.priority == .high }.count,
                            handledCount: learningRepository.volunteerDashboardMetrics.repliedByVolunteerCount,
                            tint: EPTheme.primary
                        )

                        VolunteerHandoffSummaryCard()

                        ForEach(learningRepository.volunteerQueue) { request in
                            VolunteerSupportRequestCard(request: request)
                        }
                    }
                    .padding(EPTheme.pagePadding)
                }
            }
            .navigationTitle("接力")
        }
    }
}

private struct VolunteerSupportRequestCard: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var learningRepository: LearningRepositoryStore
    let request: StudentSupportRequest

    @State private var replyDraft = ""
    @State private var isDraftingWithAI = false

    private var canReply: Bool {
        !replyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var staffReplies: [SupportReply] {
        request.staffReplies
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(request.studentName)
                        .font(.headline)
                        .foregroundStyle(EPTheme.ink)
                    Text("\(request.classCode) · \(request.status.uiTitle)")
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
                    .clipShape(Capsule())
            }

            if let snapshot = request.questionSnapshot {
                SupportQuestionSnapshotCard(
                    snapshot: snapshot,
                    title: "學生卡住的題目",
                    showsExplanation: true
                )
            } else {
                VolunteerMissingQuestionSnapshotLabel()
            }

            if let moodScore = request.moodScore {
                Label("今日心情 \(moodScore)/5", systemImage: "heart.text.square")
                    .font(.caption)
                    .foregroundStyle(EPTheme.secondaryInk)
            }

            if !staffReplies.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("已有回覆")
                        .font(.caption.bold())
                        .foregroundStyle(EPTheme.secondaryInk)
                    ForEach(staffReplies) { reply in
                        Text("\(reply.authorName)：\(reply.body)")
                            .font(.footnote)
                            .foregroundStyle(EPTheme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            TextField("輸入給學生的回覆，例如：你卡住的是 be 動詞主詞對應，我幫你拆一步。", text: $replyDraft, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)

            Button(isDraftingWithAI ? "AI 正在整理建議" : "用 AI 產生回覆草稿") {
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
                },
                markHandledWithoutReply: {
                    learningRepository.markSupportThreadHandledWithoutReply(request.id, by: appState.currentUser)
                },
                archiveThread: {
                    learningRepository.archiveSupportThreadForStaff(request.id, by: appState.currentUser)
                }
            )
        }
        .padding(16)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    @MainActor
    private func fillVolunteerDraftWithAI() async {
        isDraftingWithAI = true
        defer { isDraftingWithAI = false }

        let response = await appState.coachVolunteerReplyWithAI(context: SupportAIContext(request: request))
        replyDraft = response.output.studentFacingFeedback
            ?? response.output.recommendedNextAction
            ?? response.output.teacherSummary
            ?? response.output.summary
            ?? replyDraft
    }
}

private struct VolunteerHandoffSummaryCard: View {
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("學生資料與真人接力分開處理", systemImage: "arrow.triangle.branch")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)

            Text("老師先看求助與風險，再決定要直接回覆、消除提醒或收起；志工端仍可獨立補充陪伴。")
                .font(.subheadline)
                .foregroundStyle(EPTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                VolunteerHandoffStatusTile(
                    title: "學生",
                    value: "\(learningRepository.staffDashboardMetrics.studentCount)",
                    color: EPTheme.primary
                )
                VolunteerHandoffStatusTile(
                    title: "平均心情",
                    value: learningRepository.staffDashboardMetrics.averageMoodText,
                    color: EPTheme.support
                )
            }
        }
        .padding(16)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct VolunteerHandoffStatusTile: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(color)
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

            if let snapshot = request.questionSnapshot {
                Text(snapshot.prompt)
                    .font(.subheadline.bold())
                    .foregroundStyle(EPTheme.ink)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VolunteerMissingQuestionSnapshotLabel()
            }

            Text("到「接力」頁面後，只看題目卡與卡點，再送出學生看得懂的回覆。")
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

private struct VolunteerMissingQuestionSnapshotLabel: View {
    var body: some View {
        Label("這筆接力缺少完整題目快照，請優先處理有題目卡的求助。", systemImage: "doc.text.magnifyingglass")
            .font(.caption.bold())
            .foregroundStyle(EPTheme.secondaryInk)
            .fixedSize(horizontal: false, vertical: true)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EPTheme.secondarySurface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
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

            if let snapshot = request.questionSnapshot {
                SupportQuestionSnapshotCard(
                    snapshot: snapshot,
                    title: "已處理題目",
                    showsExplanation: true
                )
            } else {
                VolunteerMissingQuestionSnapshotLabel()
            }

            ForEach(request.staffReplies.filter { $0.authorRole == .volunteer }) { reply in
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
