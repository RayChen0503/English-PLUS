import SwiftUI

struct StudentLearningMapView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

    private let questionBankItems = SeedData.approvedQuestionBankItems

    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        headerCard
                        flowActionCard
                        todayRouteCard
                        questionBankCard
                        supportTimelineCard
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
                .foregroundStyle(.secondary)

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
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
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
                        .foregroundStyle(.secondary)
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

            HStack(spacing: 10) {
                Button {
                    learningRepository.startNewLearningRound(
                        for: appState.currentUser,
                        profile: appState.currentProfile
                    )
                } label: {
                    Label("重新檢測", systemImage: "checklist")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryActionButtonStyle())

                Button {
                    if learningRepository.learningFlow.canContinuePreviousProgress {
                        learningRepository.continueLearningFlow()
                    } else {
                        learningRepository.enterFreePracticeMode()
                    }
                } label: {
                    Label(
                        learningRepository.learningFlow.canContinuePreviousProgress ? "延續進度" : "自由練習",
                        systemImage: learningRepository.learningFlow.canContinuePreviousProgress ? "arrow.clockwise.circle" : "pencil.and.list.clipboard"
                    )
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .background(.white)
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
                        .foregroundStyle(.secondary)
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
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private var questionBankCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("可用題庫")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)

            Text("自由練習與每日任務會從不同題型抽題，完成今日任務後也可以再挑戰。")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 126), spacing: 8)], spacing: 8) {
                ForEach(QuestionType.allCases) { type in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(type.title)
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text("\(count(for: type)) 題")
                            .font(.headline)
                            .foregroundStyle(EPTheme.ink)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
                }
            }
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private var supportTimelineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("支持時間線")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)

            if studentSupportRequests.isEmpty {
                Text("目前沒有新的求助紀錄。卡住時可以到支持頁請老師或志工陪你。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(studentSupportRequests.prefix(3)) { request in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(request.reason.uiTitle)
                                .font(.subheadline.bold())
                            Spacer()
                            Text(request.status.uiTitle)
                                .font(.caption.bold())
                                .foregroundStyle(request.status == .replied ? EPTheme.support : EPTheme.warning)
                        }
                        Text(request.studentMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
                }
            }
        }
        .padding(16)
        .background(.white)
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
                detail: "完成今日任務後可以自己挑戰，不會改變今日任務進度。",
                state: isComplete ? .current : .available,
                icon: "pencil.and.list.clipboard"
            ),
            LearningMapNode(
                title: "支持回覆",
                detail: studentSupportRequests.isEmpty ? "卡住時可以求助；老師或志工的回覆會留在這裡。" : "已有 \(studentSupportRequests.count) 則求助或回覆紀錄。",
                state: studentSupportRequests.isEmpty ? .available : .current,
                icon: "heart"
            ),
        ]
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

    private func count(for type: QuestionType) -> Int {
        questionBankItems.filter { $0.question.type == type }.count
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
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(node.state == .current ? stateColor.opacity(0.08) : Color(.systemGray6))
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
            return .secondary
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
