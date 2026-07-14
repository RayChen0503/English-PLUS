import SwiftUI

struct StudentLearningMapView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

    let onOpenHome: () -> Void

    init(onOpenHome: @escaping () -> Void = {}) {
        self.onOpenHome = onOpenHome
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        headerCard
                        if learningRepository.masterySummary.trackedSkillCount > 0 {
                            masteryCard
                        }
                        if allLearningMapNodesCompleted {
                            todayCompleteCard
                        }
                        flowActionCard
                        todayRouteCard
                    }
                    .padding(EPTheme.pagePadding)
                }
            }
            .navigationTitle("學習地圖")
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("今日路線")
                .font(.title.bold())
                .foregroundStyle(EPTheme.ink)

            Text(headerSubtitle)
                .font(.subheadline)
                .foregroundStyle(EPTheme.secondaryInk)

            if let progress = learningRepository.progressSnapshot {
                ProgressView(value: progress.progressFraction)
                    .tint(trackColor)
                HStack {
                    Text(progress.progressText)
                    Spacer()
                    Text(progress.status == .completed ? "完成" : "進行中")
                }
                .font(.caption.bold())
                .foregroundStyle(progress.status == .completed ? EPTheme.support : EPTheme.primary)
            } else {
                ProgressView(value: 0)
                    .tint(EPTheme.primary)
                Text("完成心情檢測後，這裡會只追蹤今日題目任務。")
                    .font(.caption)
                    .foregroundStyle(EPTheme.secondaryInk)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private var todayCompleteCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("今天的任務完成了", systemImage: "checkmark.seal.fill")
                .font(.title3.bold())
                .foregroundStyle(EPTheme.support)

            Text("心情檢測、今日題目、低壓修復、自由練習和支持回覆都已整理好。你可以休息，也可以繼續自由練習。")
                .font(.subheadline)
                .foregroundStyle(EPTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.support.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private var masteryCard: some View {
        let summary = learningRepository.masterySummary
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title2)
                    .foregroundStyle(EPTheme.support)
                VStack(alignment: .leading, spacing: 4) {
                    Text("長期學習進度")
                        .font(.headline)
                        .foregroundStyle(EPTheme.ink)
                    Text(summary.dueReviewCount > 0
                        ? "有 \(summary.dueReviewCount) 個能力到了適合複習的時間，可到練習中心開始。"
                        : "目前複習節奏穩定，繼續照今日路線前進。")
                        .font(.subheadline)
                        .foregroundStyle(EPTheme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                masteryMetric(title: "已追蹤", value: "\(summary.trackedSkillCount)")
                masteryMetric(title: "表現穩定", value: "\(summary.strongSkillCount)")
                masteryMetric(title: "整體熟練", value: "\(summary.averageScore)%")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private func masteryMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(EPTheme.secondaryInk)
                .lineLimit(1)
            Text(value)
                .font(.title3.bold())
                .monospacedDigit()
                .foregroundStyle(EPTheme.ink)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.secondarySurface)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private var flowActionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(flowStageTitle)
                        .font(.headline)
                        .foregroundStyle(EPTheme.ink)
                    Text(flowStageDetail)
                        .font(.subheadline)
                        .foregroundStyle(EPTheme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Text("第 \(learningRepository.learningFlow.roundNumber) 輪")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .foregroundStyle(trackColor)
                    .background(trackColor.opacity(0.12))
                    .clipShape(Capsule())
            }

            Button {
                learningRepository.startNewLearningRound(
                    for: appState.currentUser,
                    profile: appState.currentProfile
                )
                onOpenHome()
            } label: {
                Label("重新檢測", systemImage: "checklist")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryActionButtonStyle())
        }
        .padding(16)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private var todayRouteCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("路線節點")
                        .font(.headline)
                        .foregroundStyle(EPTheme.ink)
                    Text(routeSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(EPTheme.secondaryInk)
                }
                Spacer()
                Text(trackBadgeTitle)
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .foregroundStyle(trackColor)
                    .background(trackColor.opacity(0.12))
                    .clipShape(Capsule())
            }

            ForEach(learningMapNodes) { node in
                LearningMapNodeRow(node: node)
            }
        }
        .padding(16)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private var headerSubtitle: String {
        guard let currentMission = learningRepository.currentMission else {
            return "先完成四題心情檢測，English+ 會把今天的任務切成做得到的小路線。"
        }
        if currentMission.status == .completed {
            return "今天的指定題目任務已完成，可以休息，也可以到練習中心自由挑戰。"
        }
        return "今天先完成 \(currentMission.targetCorrectCount) 題正確答案；答錯不扣分，只保留提示。"
    }

    private var activeFlowStage: LearningFlowStage {
        learningRepository.learningFlow.stage
    }

    private var flowStageTitle: String {
        switch activeFlowStage {
        case .needsCheckIn:
            return "先做心情檢測"
        case .missionActive:
            return "今日任務進行中"
        case .missionCompleted:
            return "今日任務已完成"
        case .freePractice:
            return "正在自由練習"
        }
    }

    private var flowStageDetail: String {
        switch activeFlowStage {
        case .needsCheckIn:
            if let continuation = learningRepository.learningFlow.continuation {
                return "可以重新開始，也可以延續上一輪：\(continuation.progressText)。"
            }
            return "完成四題檢測後，地圖會安排今日任務。"
        case .missionActive:
            return "照著今日任務走，答對才會推進進度。"
        case .missionCompleted:
            return "可以自由練習，也可以再跑一輪新的任務。"
        case .freePractice:
            return "自由練習不會改變今日任務完成度。"
        }
    }

    private var routeSubtitle: String {
        guard learningRepository.currentMission != nil else {
            return "還沒產生今日任務，先回首頁做心情檢測。"
        }
        return "一個節點接一個節點，不同功能不混在同一張卡裡。"
    }

    private var learningMapNodes: [LearningMapNode] {
        let hasCheckIn = learningRepository.currentCheckIn != nil
        let currentMission = learningRepository.currentMission
        let progress = learningRepository.progressSnapshot
        let isComplete = progress?.status == .completed
        let missionTitle = currentMission?.track.uiTitle ?? "等待產生任務"

        return [
            LearningMapNode(
                title: "心情檢測",
                detail: hasCheckIn ? "已完成，系統已知道今天的時間、心情與題型偏好。" : "先回答四題，讓今日任務不要太重。",
                state: hasCheckIn ? .done : .current,
                icon: "checklist"
            ),
            LearningMapNode(
                title: "今日題目任務",
                detail: missionDetail,
                state: currentMission == nil ? .locked : (isComplete ? .done : .current),
                icon: "target"
            ),
            LearningMapNode(
                title: missionTitle,
                detail: trackDetail,
                state: currentMission == nil ? .locked : (isComplete ? .done : .current),
                icon: trackIcon
            ),
            LearningMapNode(
                title: "自由練習",
                detail: freePracticeDetail,
                state: freePracticeNodeState,
                icon: "pencil.and.list.clipboard"
            ),
            LearningMapNode(
                title: "支持回覆",
                detail: supportReplyDetail,
                state: supportReplyNodeState,
                icon: "heart"
            ),
        ]
    }

    private var allLearningMapNodesCompleted: Bool {
        !learningMapNodes.isEmpty && learningMapNodes.allSatisfy { $0.state == .done }
    }

    private var hasCompletedFreePracticeSession: Bool {
        learningRepository.hasCompletedFreePracticeSession
    }

    private var freePracticeNodeState: LearningMapNode.State {
        if hasCompletedFreePracticeSession {
            return .done
        }
        if learningRepository.progressSnapshot?.status == .completed {
            return .current
        }
        return .available
    }

    private var freePracticeDetail: String {
        if hasCompletedFreePracticeSession {
            return "已完成至少一組自由練習，之後可以繼續挑戰。"
        }
        return "完成今日任務後可以自己挑戰，不會改變今日任務進度。"
    }

    private var pendingSupportRequests: [StudentSupportRequest] {
        studentSupportRequests.filter(\.isPendingOnStudentLearningMap)
    }

    private var unreadSupportReplyCount: Int {
        pendingSupportRequests.filter(\.hasStudentUnreadReply).count
    }

    private var supportRepliesCleared: Bool {
        pendingSupportRequests.isEmpty
    }

    private var supportReplyNodeState: LearningMapNode.State {
        supportRepliesCleared ? .done : .current
    }

    private var supportReplyDetail: String {
        if supportRepliesCleared {
            if studentSupportRequests.isEmpty {
                return "目前沒有待處理回覆。"
            }
            return "所有回覆都已看完或收起。"
        }
        if unreadSupportReplyCount > 0 {
            return "有 \(unreadSupportReplyCount) 則新回覆待查看。"
        }
        return "有 \(pendingSupportRequests.count) 則求助正在等待老師或志工。"
    }

    private var missionDetail: String {
        guard let currentMission = learningRepository.currentMission else {
            return "尚未開始。"
        }
        if let progress = learningRepository.progressSnapshot {
            return "已答對 \(progress.correctCount)/\(progress.targetCorrectCount) 題，約 \(currentMission.recommendedMinutes) 分鐘。"
        }
        return "約 \(currentMission.recommendedMinutes) 分鐘。"
    }

    private var trackBadgeTitle: String {
        guard let track = learningRepository.currentMission?.track else {
            return "待安排"
        }
        switch track {
        case .repair:
            return "修復"
        case .steady:
            return "穩定"
        case .challenge:
            return "挑戰"
        }
    }

    private var trackDetail: String {
        guard let track = learningRepository.currentMission?.track else {
            return "完成檢測後，這裡會顯示今天是修復、穩定，還是挑戰路線。"
        }
        switch track {
        case .repair:
            return "今天先修復一個斷點，任務短一點也算完成。"
        case .steady:
            return "今天照穩定節奏完成指定題數，先建立連續感。"
        case .challenge:
            return "今天可以加入較難題型，完成後再自由練習。"
        }
    }

    private var trackIcon: String {
        switch learningRepository.currentMission?.track {
        case .repair:
            return "bandage"
        case .steady:
            return "figure.walk"
        case .challenge:
            return "flame"
        case nil:
            return "map"
        }
    }

    private var trackColor: Color {
        switch learningRepository.currentMission?.track {
        case .repair:
            return EPTheme.warning
        case .steady:
            return EPTheme.primary
        case .challenge:
            return EPTheme.support
        case nil:
            return EPTheme.primary
        }
    }

    private var studentSupportRequests: [StudentSupportRequest] {
        learningRepository.supportRequests(forStudentUid: appState.currentUser?.id)
    }
}

private struct LearningMapNode: Identifiable {
    enum State {
        case done
        case current
        case available
        case locked
    }

    let id = UUID()
    let title: String
    let detail: String
    let state: State
    let icon: String
}

private struct LearningMapNodeRow: View {
    let node: LearningMapNode

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(stateColor.opacity(node.state == .locked ? 0.10 : 0.16))
                    .frame(width: 44, height: 44)
                Image(systemName: node.icon)
                    .font(.headline)
                    .foregroundStyle(stateColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(node.title)
                        .font(.headline)
                        .foregroundStyle(EPTheme.ink)
                    Spacer()
                    Text(stateTitle)
                        .font(.caption.bold())
                        .foregroundStyle(stateColor)
                }

                Text(node.detail)
                    .font(.subheadline)
                    .foregroundStyle(EPTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(node.state == .current ? stateColor.opacity(0.08) : EPTheme.secondarySurface)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private var stateTitle: String {
        switch node.state {
        case .done:
            return "完成"
        case .current:
            return "現在"
        case .available:
            return "可用"
        case .locked:
            return "稍後"
        }
    }

    private var stateColor: Color {
        switch node.state {
        case .done:
            return EPTheme.support
        case .current:
            return EPTheme.primary
        case .available:
            return EPTheme.warning
        case .locked:
            return EPTheme.secondaryInk
        }
    }
}

private extension SupportReason {
    var uiTitle: String {
        switch self {
        case .stuckOnQuestion:
            return "題目卡住"
        case .emotionalSupport:
            return "情緒支持"
        case .readingHelp:
            return "閱讀拆解"
        case .teacherRequested:
            return "請老師陪我"
        }
    }
}
