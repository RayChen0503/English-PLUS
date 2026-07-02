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
                        Text("今日接力任務")
                            .font(.title.bold())
                            .foregroundStyle(EPTheme.ink)

                        VolunteerMetricStrip()

                        VStack(alignment: .leading, spacing: 10) {
                            Label("\(learningRepository.volunteerQueue.count) 位學生等待陪伴", systemImage: "heart")
                                .font(.headline)
                                .foregroundStyle(EPTheme.support)
                            Text("只看必要摘要，留下鼓勵或陪伴回覆。")
                                .foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))

                        if learningRepository.volunteerQueue.isEmpty {
                            VolunteerEmptyQueueCard()
                        } else {
                            ForEach(learningRepository.volunteerQueue.prefix(3)) { request in
                                VolunteerTaskCard(request: request)
                            }
                        }

                        VolunteerScriptPreviewCard()
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

private struct VolunteerEmptyQueueCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("目前沒有等待接力的學生", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(EPTheme.support)
            Text("如果稍後有學生求助，這裡會顯示最需要陪伴的一小步。現在可以先看陪伴話術或學生摘要。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

struct VolunteerHandoffView: View {
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("接力學生")
                            .font(.title.bold())
                            .foregroundStyle(EPTheme.ink)

                        Text("只做下一小步：先接住情緒，再陪一個卡點，不新增額外壓力。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        ForEach(learningRepository.volunteerQueue) { request in
                            VolunteerTaskCard(request: request)
                        }
                    }
                    .padding(EPTheme.pagePadding)
                }
            }
            .navigationTitle("接力")
        }
    }
}

struct VolunteerStudentBriefsView: View {
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("學生摘要")
                            .font(.title.bold())
                            .foregroundStyle(EPTheme.ink)

                        Text("志工端只顯示陪伴所需資訊，不顯示老師的班級管理與評分資料。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        ForEach(learningRepository.staffStudentSummaries) { summary in
                            VolunteerStudentBriefCard(summary: summary)
                        }
                    }
                    .padding(EPTheme.pagePadding)
                }
            }
            .navigationTitle("學生")
        }
    }
}

struct VolunteerRecordView: View {
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

    private var repliedRequests: [StudentSupportRequest] {
        learningRepository.supportRequests.filter { request in
            request.replies.contains { $0.authorRole == .volunteer }
        }
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

                        Text("回顧已送出的陪伴回覆，確認哪些學生已經有人接住。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        VolunteerRecordStatusCard()

                        if repliedRequests.isEmpty {
                            EmptyRecordCard()
                        }

                        ForEach(repliedRequests) { request in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(request.studentName)
                                    .font(.headline)
                                ForEach(request.replies.filter { $0.authorRole == .volunteer }) { reply in
                                    Text(reply.body)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(16)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
                        }
                    }
                    .padding(EPTheme.pagePadding)
                }
            }
            .navigationTitle("紀錄")
        }
    }
}

struct VolunteerScriptView: View {
    private let templates = VolunteerScriptTemplate.defaults

    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("陪伴腳本")
                            .font(.title.bold())
                            .foregroundStyle(EPTheme.ink)

                        Text("可以直接照著說，也可以改成自己的語氣。重點是降低壓力、只陪一個卡點。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        ForEach(templates) { template in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(template.title)
                                    .font(.headline)
                                    .foregroundStyle(EPTheme.ink)
                                Text(template.body)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(16)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
                        }
                    }
                    .padding(EPTheme.pagePadding)
                }
            }
            .navigationTitle("腳本")
        }
    }
}

struct VolunteerTaskCard: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var learningRepository: LearningRepositoryStore
    let request: StudentSupportRequest

    @State private var replyDraft = ""
    @State private var isDraftingWithAI = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(request.studentName)
                        .font(.headline)
                    Text(statusSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(request.priority.uiTitle)
                    .font(.caption.bold())
                    .foregroundStyle(request.priority == .high ? EPTheme.warning : EPTheme.support)
            }

            Text(request.studentMessage)
                .font(.subheadline)
                .foregroundStyle(EPTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(nextStep)
                .font(.footnote)
                .foregroundStyle(EPTheme.support)
                .fixedSize(horizontal: false, vertical: true)

            TextField("留下鼓勵或陪伴回覆", text: $replyDraft, axis: .vertical)
                .textFieldStyle(.roundedBorder)

            Button(isDraftingWithAI ? "正在產生陪伴草稿" : "AI 產生陪伴草稿") {
                Task {
                    await fillVolunteerDraftWithAI()
                }
            }
            .buttonStyle(.bordered)
            .disabled(isDraftingWithAI)

            Button("送出陪伴回覆") {
                learningRepository.addVolunteerReply(to: request.id, body: replyDraft)
                replyDraft = ""
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(replyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(replyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
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

    private var statusSummary: String {
        if let moodScore = request.moodScore {
            return "心情 \(moodScore)/5 · \(request.status.uiTitle)"
        }
        return request.status.uiTitle
    }

    private var nextStep: String {
        switch request.reason {
        case .readingHelp:
            return "下一步：請學生先圈出看不懂的句子，再陪他拆主詞與動詞。"
        case .emotionalSupport:
            return "下一步：先肯定今天願意打開 App，再陪一題低壓題。"
        case .teacherRequested:
            return "下一步：依老師交代陪同一個概念，不追加新的作業。"
        case .stuckOnQuestion:
            return "下一步：請學生說出卡住的選項，再用提示帶他重試。"
        }
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
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct VolunteerScriptPreviewCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("只做下一小步", systemImage: "figure.walk")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)
            Text("陪伴順序：先肯定卡住很正常，再問學生想先看提示還是先重試，最後留下接力紀錄。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct VolunteerStudentBriefCard: View {
    let summary: StaffStudentSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(summary.studentName)
                    .font(.headline)
                    .foregroundStyle(EPTheme.ink)
                Spacer()
                Text(summary.riskLevel.uiTitle)
                    .font(.caption.bold())
                    .foregroundStyle(summary.riskLevel == .high ? EPTheme.warning : EPTheme.support)
            }
            Text(summary.classCode)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(summary.nextAction)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
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
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.white)
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
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
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
            title: "學生說自己不會",
            body: "你不是完全不會，是卡在其中一小段。我們先只看這一句，不急著做完全部。"
        ),
        VolunteerScriptTemplate(
            id: "retry",
            title: "答錯後重試",
            body: "剛剛那題錯得有線索。你先告訴我你排除了哪個選項，我們再一起看剩下的。"
        ),
        VolunteerScriptTemplate(
            id: "finish",
            title: "結束接力",
            body: "今天先到這裡就很好。你已經完成一小步，我會把下一步留給老師接續。"
        ),
    ]
}
