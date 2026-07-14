import SwiftUI

struct VolunteerHomeView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var learningRepository: LearningRepositoryStore
    @State private var showsAccountData = false

    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VolunteerHeaderCard()
                        if let reviewState = appState.volunteerApplicationReviewState,
                           reviewState.status == .approved,
                           let note = reviewState.normalizedReviewNote {
                            VolunteerApprovalNoteCard(note: note, reviewedAt: reviewState.reviewedAt)
                        }
                        if appState.currentProfile?.activeClassId == nil {
                            VolunteerNoActiveServiceCard()
                        } else {
                            VolunteerMetricStrip()

                            if let firstRequest = learningRepository.volunteerQueue.first {
                                NavigationLink {
                                    StaffSupportDetailView(initialRequest: firstRequest, role: .volunteer)
                                } label: {
                                    StaffSupportQueueRow(request: firstRequest)
                                }
                                .buttonStyle(.plain)
                            } else {
                                VolunteerEmptyQueueCard()
                            }
                        }
                    }
                    .padding(EPTheme.pagePadding)
                }
            }
            .navigationTitle("志工工作台")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showsAccountData = true
                        } label: {
                            Label("帳號與資料", systemImage: "person.text.rectangle")
                        }

                        Button(role: .destructive) {
                            appState.signOut()
                        } label: {
                            Label("登出", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Label("帳號", systemImage: "person.crop.circle")
                    }
                }
            }
            .sheet(isPresented: $showsAccountData) {
                AccountDataView()
            }
        }
    }
}

private struct VolunteerApprovalNoteCard: View {
    let note: String
    let reviewedAt: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("志工資格已通過", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(EPTheme.support)
            Text(note)
                .font(.subheadline)
                .foregroundStyle(EPTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let reviewedAt {
                Text("審核時間：\(reviewedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(EPTheme.secondaryInk)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.support.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

struct VolunteerServiceClassesView: View {
    @EnvironmentObject private var appState: AppState
    @State private var inviteCode = ""
    @State private var classPendingLeave: VolunteerServiceSummary?

    private var activeServices: [VolunteerServiceSummary] {
        appState.volunteerServices.filter { $0.status == .active }
    }

    private var pendingServices: [VolunteerServiceSummary] {
        appState.volunteerServices.filter { $0.status == .pendingApproval }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        serviceScopeCard
                        joinCard

                        if appState.isLoadingVolunteerServices && appState.volunteerServices.isEmpty {
                            EPContentStateView(
                                state: .loading(
                                    title: "正在載入服務班級",
                                    detail: "你仍可留在此頁，完成後會自動更新。"
                                )
                            )
                        }

                        if !pendingServices.isEmpty {
                            serviceSection(title: "等待老師核准", services: pendingServices)
                        }

                        if let error = appState.volunteerServiceErrorMessage,
                           activeServices.isEmpty,
                           pendingServices.isEmpty,
                           !appState.isLoadingVolunteerServices {
                            EPContentStateView(
                                state: .failure(title: "服務班級尚未載入", detail: error),
                                onRetry: {
                                    Task { await appState.loadVolunteerServices() }
                                }
                            )
                        } else if activeServices.isEmpty && pendingServices.isEmpty && !appState.isLoadingVolunteerServices {
                            EPContentStateView(
                                state: .empty(
                                    systemImage: "person.3",
                                    title: "目前沒有服務班級",
                                    detail: "在老師核准前，接力頁不會顯示任何學生資料。"
                                )
                            )
                        } else if !activeServices.isEmpty {
                            serviceSection(title: "我服務的班級", services: activeServices)
                        }

                        if let notice = appState.volunteerServiceNoticeMessage {
                            VolunteerServiceMessage(text: notice, isError: false)
                        }
                        if let error = appState.volunteerServiceErrorMessage,
                           !activeServices.isEmpty || !pendingServices.isEmpty {
                            VolunteerServiceMessage(text: error, isError: true)
                        }
                    }
                    .padding(EPTheme.pagePadding)
                }
                .refreshable { await appState.loadVolunteerServices() }
            }
            .navigationTitle("服務班級")
            .task { await appState.loadVolunteerServices() }
            .alert(
                classPendingLeave?.status == .pendingApproval
                    ? "撤回「\(classPendingLeave?.className ?? "班級")」的申請？"
                    : "離開「\(classPendingLeave?.className ?? "班級")」？",
                isPresented: Binding(
                    get: { classPendingLeave != nil },
                    set: { if !$0 { classPendingLeave = nil } }
                )
            ) {
                Button("取消", role: .cancel) { classPendingLeave = nil }
                Button(
                    classPendingLeave?.status == .pendingApproval ? "撤回申請" : "離開班級",
                    role: .destructive
                ) {
                    guard let service = classPendingLeave else { return }
                    classPendingLeave = nil
                    Task { _ = await appState.leaveVolunteerService(classId: service.classId) }
                }
            } message: {
                Text(
                    classPendingLeave?.status == .pendingApproval
                        ? "撤回後老師不會再看到這筆待核准申請；需要時可重新輸入邀請碼。"
                        : "離開後會立即停止接收這個班級的學生求助，且不能再查看原有接力內容。"
                )
            }
        }
    }

    private var serviceScopeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("先加入服務班級，再開始接力", systemImage: "person.badge.key")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)
            Text("加入並經老師核准後，只會看到該班學生主動送出的求助。")
                .font(.subheadline)
                .foregroundStyle(EPTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private var joinCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("加入新的服務班級")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)
            TextField("輸入老師提供的 8 碼志工邀請碼", text: $inviteCode)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding(12)
                .background(EPTheme.secondarySurface)
                .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))

            Button {
                Task {
                    if await appState.requestVolunteerService(code: inviteCode) {
                        inviteCode = ""
                    }
                }
            } label: {
                if appState.isManagingVolunteerService {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 44)
                } else {
                    Label("送出加入申請", systemImage: "paperplane.fill")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(normalizedInviteCode.count != 8 || appState.isManagingVolunteerService)
            .opacity(normalizedInviteCode.count == 8 && !appState.isManagingVolunteerService ? 1 : 0.45)
        }
        .padding(16)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private func serviceSection(title: String, services: [VolunteerServiceSummary]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(EPTheme.ink)
            ForEach(services) { service in
                VolunteerServiceRow(
                    service: service,
                    isCurrent: appState.currentProfile?.activeClassId == service.classId,
                    isBusy: appState.isManagingVolunteerService,
                    select: {
                        Task { await appState.selectActiveClass(service.classId) }
                    },
                    leave: { classPendingLeave = service }
                )
            }
        }
    }

    private var normalizedInviteCode: String {
        inviteCode.uppercased().filter { $0.isLetter || $0.isNumber }
    }
}

private struct VolunteerServiceRow: View {
    let service: VolunteerServiceSummary
    let isCurrent: Bool
    let isBusy: Bool
    let select: () -> Void
    let leave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(service.className)
                        .font(.headline)
                        .foregroundStyle(EPTheme.ink)
                    Text(service.status.title)
                        .font(.caption.bold())
                        .foregroundStyle(service.status == .active ? EPTheme.support : EPTheme.warning)
                }
                Spacer()
                if isCurrent {
                    Label("目前", systemImage: "checkmark.circle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(EPTheme.support)
                }
            }

            if service.status == .active {
                HStack(spacing: 8) {
                    if !isCurrent {
                        Button("切換到這個班級", action: select)
                            .buttonStyle(PrimaryActionButtonStyle())
                    }
                    Button("離開", role: .destructive, action: leave)
                        .buttonStyle(SecondaryActionButtonStyle())
                }
                .disabled(isBusy)
            } else {
                HStack(alignment: .center, spacing: 8) {
                    Text("老師核准後，這裡會出現切換班級與接力入口。")
                        .font(.footnote)
                        .foregroundStyle(EPTheme.secondaryInk)
                    Spacer()
                    Button("撤回申請", role: .destructive, action: leave)
                        .font(.footnote.bold())
                }
                .disabled(isBusy)
            }
        }
        .padding(16)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct VolunteerServiceMessage: View {
    let text: String
    let isError: Bool

    var body: some View {
        Label(text, systemImage: isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
            .font(.footnote)
            .foregroundStyle(isError ? EPTheme.warning : EPTheme.support)
            .fixedSize(horizontal: false, vertical: true)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background((isError ? EPTheme.warning : EPTheme.support).opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct VolunteerHandoffWorkspaceView: View {
    @EnvironmentObject private var appState: AppState
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

                        Text("先選一筆待辦，再進入題目與回覆畫面。高優先求助會排在前面。")
                            .font(.subheadline)
                            .foregroundStyle(EPTheme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)

                        if appState.currentProfile?.activeClassId == nil {
                            VolunteerNoActiveServiceCard()
                        } else {
                            StaffSupportQueueHeaderCard(
                                title: "待回覆接力",
                                subtitle: "只顯示目前服務班級中，學生主動送出的求助。老師或志工任一方回覆後，雙方提醒會同步更新。",
                                waitingCount: learningRepository.volunteerDashboardMetrics.waitingCount,
                                highPriorityCount: learningRepository.volunteerQueue.filter { $0.priority == .high }.count,
                                handledCount: learningRepository.volunteerDashboardMetrics.repliedByVolunteerCount,
                                tint: EPTheme.primary
                            )

                            if learningRepository.volunteerQueue.isEmpty {
                                VolunteerEmptyQueueCard()
                            } else {
                                LazyVStack(spacing: 10) {
                                    ForEach(learningRepository.volunteerQueue) { request in
                                        NavigationLink {
                                            StaffSupportDetailView(initialRequest: request, role: .volunteer)
                                        } label: {
                                            StaffSupportQueueRow(request: request)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityIdentifier("volunteer.handoff.request.\(request.id)")
                                    }
                                }
                            }
                        }
                    }
                    .padding(EPTheme.pagePadding)
                }
            }
            .navigationTitle("接力")
        }
    }
}

private struct VolunteerNoActiveServiceCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("尚未選擇服務班級", systemImage: "person.3")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)
            Text("請先到「班級」輸入老師提供的志工邀請碼。經老師核准並選擇服務班級後，這裡才會顯示學生主動送出的求助。")
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

private struct VolunteerSupportRequestCard: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var learningRepository: LearningRepositoryStore
    let request: StudentSupportRequest

    @State private var replyDraft = ""
    @State private var isDraftingWithAI = false
    @State private var aiDraftResponse: AiProxyResponse?

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
            } else if request.hasActionableHumanSupportContext {
                StaffHumanSupportRequestCard(message: request.studentMessage)
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

            if let aiDraftResponse {
                StaffAIDraftCard(
                    response: aiDraftResponse,
                    roleTitle: "志工",
                    onApply: {
                        if let draft = aiDraftResponse.output.studentFacingFeedback,
                           !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            replyDraft = draft
                        }
                    }
                )
            }

            StaffSupportActionBar(
                canReply: canReply,
                isProcessing: learningRepository.isSupportActionPending(for: request.id),
                sendReply: {
                    Task {
                        if await learningRepository.addVolunteerReply(to: request.id, body: replyDraft) {
                            replyDraft = ""
                            aiDraftResponse = nil
                        }
                    }
                },
                archiveThread: {
                    Task {
                        _ = await learningRepository.archiveSupportThreadForStaff(request.id, by: appState.currentUser)
                    }
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
        aiDraftResponse = response
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
            } else if request.hasActionableHumanSupportContext {
                StaffHumanSupportRequestCard(message: request.studentMessage)
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
    @State private var isExpanded = false

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

            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 10) {
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
                .padding(.top, 8)
            } label: {
                Label(isExpanded ? "收起紀錄" : "查看題目與回覆", systemImage: "text.magnifyingglass")
                    .font(.subheadline.bold())
                    .foregroundStyle(EPTheme.primary)
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
