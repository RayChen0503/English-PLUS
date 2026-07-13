import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct TeacherHomeView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var learningRepository: LearningRepositoryStore
    @State private var showsAccountData = false

    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("今日需要先接住誰")
                            .font(.title.bold())
                            .foregroundStyle(EPTheme.ink)

                        TeacherStatusStrip()

                        VStack(alignment: .leading, spacing: 10) {
                            Text("優先處理")
                                .font(.headline)
                            if learningRepository.teacherQueue.isEmpty {
                                TeacherEmptyQueueCard()
                            } else {
                                ForEach(learningRepository.teacherQueue.prefix(3)) { request in
                                    TeacherSupportRequestCard(request: request)
                                }
                            }
                        }

                        TeacherClassSummary()
                    }
                    .padding(EPTheme.pagePadding)
                }
            }
            .navigationTitle("教師工作台")
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

struct TeacherHandoffView: View {
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

                        Text("排序規則：只顯示學生主動送出的求助；需要真人陪伴與閱讀卡點會優先排列。")
                            .font(.subheadline)
                            .foregroundStyle(EPTheme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)

                        StaffSupportQueueHeaderCard(
                            title: "待回覆接力",
                            subtitle: "學生把卡住的題目送出後，老師與志工都會收到同一筆接力。任何一端回覆都會消除雙方紅點；收起只影響自己的待辦。",
                            waitingCount: learningRepository.staffDashboardMetrics.waitingHelpCount,
                            highPriorityCount: learningRepository.teacherQueue.filter { $0.priority == .high }.count,
                            handledCount: learningRepository.staffDashboardMetrics.repliedCount,
                            tint: EPTheme.primary
                        )

                        TeacherHandoffSummaryCard()

                        ForEach(learningRepository.teacherQueue) { request in
                            TeacherSupportRequestCard(request: request)
                        }
                    }
                    .padding(EPTheme.pagePadding)
                }
            }
            .navigationTitle("接力")
        }
    }
}

struct TeacherSupportRequestCard: View {
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
                StaffMissingQuestionSnapshotLabel()
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
                    await fillTeacherDraftWithAI()
                }
            }
            .buttonStyle(SecondaryActionButtonStyle())
            .disabled(isDraftingWithAI)

            if let aiDraftResponse {
                StaffAIDraftCard(
                    response: aiDraftResponse,
                    roleTitle: "老師",
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
                        if await learningRepository.addTeacherReply(to: request.id, body: replyDraft) {
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
    private func fillTeacherDraftWithAI() async {
        isDraftingWithAI = true
        defer { isDraftingWithAI = false }

        let response = await appState.draftTeacherFeedbackWithAI(context: SupportAIContext(request: request))
        aiDraftResponse = response
    }
}

struct StaffAIDraftCard: View {
    let response: AiProxyResponse
    let roleTitle: String
    let onApply: () -> Void

    private var summary: String? {
        response.output.teacherSummary ?? response.output.summary
    }

    private var hasUsableDraft: Bool {
        guard let draft = response.output.studentFacingFeedback else { return false }
        return !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(response.fallbackUsed ? "內建草稿" : "AI 草稿預覽", systemImage: "sparkles")
                .font(.subheadline.bold())
                .foregroundStyle(response.fallbackUsed ? EPTheme.warning : EPTheme.primary)

            if let summary, !summary.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("卡點摘要")
                        .font(.caption.bold())
                        .foregroundStyle(EPTheme.secondaryInk)
                    Text(summary)
                        .font(.footnote)
                        .foregroundStyle(EPTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let draft = response.output.studentFacingFeedback, !draft.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("給學生的草稿")
                        .font(.caption.bold())
                        .foregroundStyle(EPTheme.secondaryInk)
                    Text(draft)
                        .font(.footnote)
                        .foregroundStyle(EPTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let nextAction = response.output.recommendedNextAction, !nextAction.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("建議下一步")
                        .font(.caption.bold())
                        .foregroundStyle(EPTheme.secondaryInk)
                    Text(nextAction)
                        .font(.footnote)
                        .foregroundStyle(EPTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button(action: onApply) {
                Label("採用並編輯這份\(roleTitle)回覆", systemImage: "square.and.pencil")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(!hasUsableDraft)
            .opacity(hasUsableDraft ? 1 : 0.45)

            Text("採用後仍可修改；只有按下回覆才會送給學生。")
                .font(.caption)
                .foregroundStyle(EPTheme.secondaryInk)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.primary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct StaffMissingQuestionSnapshotLabel: View {
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

struct TeacherReportView: View {
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

    var body: some View {
        let report = learningRepository.classroomReportExport

        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("班級週報")
                            .font(.title.bold())
                            .foregroundStyle(EPTheme.ink)

                        Text("用進步證據取代排名壓力，整理學生任務、求助與接力紀錄。")
                            .font(.subheadline)
                            .foregroundStyle(EPTheme.secondaryInk)

                        TeacherReportMetricGrid(report: report)
                        TeacherReportPrioritySection(report: report)
                        TeacherReportQuestionBankSection(report: report)
                        TeacherReportActionList(report: report)

                        ShareLink(item: report.shareText) {
                            Label("分享週報", systemImage: "square.and.arrow.up")
                        }
                            .buttonStyle(PrimaryActionButtonStyle())

                        TeacherReportPreviewCard(report: report)
                    }
                    .padding(EPTheme.pagePadding)
                }
            }
            .navigationTitle("報告")
        }
    }
}

private struct TeacherReportMetricGrid: View {
    let report: ClassroomReportExport

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(report.metrics) { metric in
                TeacherReportMetricTile(metric: metric)
            }
        }
    }
}

private struct TeacherReportMetricTile: View {
    let metric: ClassroomReportMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(metric.label)
                .font(.caption)
                .foregroundStyle(EPTheme.secondaryInk)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(metric.value)
                    .font(.title2.bold())
                    .foregroundStyle(EPTheme.ink)
                    .monospacedDigit()
                Text(metric.detail)
                    .font(.caption)
                    .foregroundStyle(EPTheme.secondaryInk)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct TeacherReportPrioritySection: View {
    let report: ClassroomReportExport

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("優先學生")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)

            if report.priorityStudents.isEmpty {
                Text("目前沒有待回應學生，可以先回顧本週已完成的支持紀錄。")
                    .font(.subheadline)
                    .foregroundStyle(EPTheme.secondaryInk)
            } else {
                ForEach(report.priorityStudents) { row in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(row.studentName)
                                .font(.subheadline.bold())
                            Spacer()
                            Text(row.priorityText)
                                .font(.caption.bold())
                                .foregroundStyle(row.priorityText == RiskLevel.high.uiTitle ? EPTheme.warning : EPTheme.support)
                        }
                        Text(row.summary)
                            .font(.caption)
                            .foregroundStyle(EPTheme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .background(EPTheme.secondarySurface)
                    .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
                }
            }
        }
        .padding(16)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct TeacherReportQuestionBankSection: View {
    let report: ClassroomReportExport

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("題庫狀態")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)

            ForEach(report.questionBankRows.prefix(4)) { row in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.typeTitle)
                            .font(.subheadline.bold())
                        Text(row.levelSummary)
                            .font(.caption)
                            .foregroundStyle(EPTheme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Text("\(row.totalCount) 題")
                        .font(.caption.bold())
                        .foregroundStyle(EPTheme.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(EPTheme.primary.opacity(0.08))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(16)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct TeacherReportActionList: View {
    let report: ClassroomReportExport

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("建議下一步")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)

            ForEach(Array(report.recommendedActions.enumerated()), id: \.offset) { index, action in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(EPTheme.primary)
                        .clipShape(Circle())
                    Text(action)
                        .font(.subheadline)
                        .foregroundStyle(EPTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct TeacherReportPreviewCard: View {
    let report: ClassroomReportExport

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("報告預覽", systemImage: "doc.plaintext")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)

            Text(report.shareText)
                .font(.caption)
                .foregroundStyle(EPTheme.secondaryInk)
                .lineLimit(10)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private enum TeacherAssignmentAudience: String, CaseIterable, Identifiable {
    case selectedStudent
    case entireClass

    var id: String { rawValue }

    var title: String {
        switch self {
        case .selectedStudent: return "目前學生"
        case .entireClass: return "全班"
        }
    }
}

struct TeacherClassAssignmentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var learningRepository: LearningRepositoryStore
    @State private var selectedStudentUid: String?
    @State private var selectedQuestionType: QuestionType?
    @State private var selectedLevel: QuestionLevel?
    @State private var selectedSkill: String?
    @State private var assignmentAudience: TeacherAssignmentAudience = .selectedStudent
    @State private var assignmentConfirmation: String?
    @State private var newClassroomName = ""
    @State private var editingClassroomName = ""
    @State private var showsCreateClassroom = false
    @State private var showsRenameClassroom = false
    @State private var classIdPendingCodeReset: String?
    @State private var classroomPendingDeletion: ClassroomSummary?
    @State private var copiedClassCode: String?

    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        teacherClassroomManagementCard

                        if appState.currentProfile?.activeClassId == nil {
                            TeacherNoActiveClassCard()
                        } else {
                            assignmentWorkspace
                        }
                    }
                    .padding(EPTheme.pagePadding)
                }
            }
            .navigationTitle("班級")
            .task {
                await appState.loadClassrooms()
                showsCreateClassroom = teacherClassrooms.isEmpty
                editingClassroomName = activeTeacherClassroom?.name ?? ""
            }
            .onChange(of: appState.currentProfile?.activeClassId) { _, _ in
                selectedStudentUid = nil
                selectedQuestionType = nil
                selectedLevel = nil
                selectedSkill = nil
                assignmentAudience = .selectedStudent
                assignmentConfirmation = nil
                copiedClassCode = nil
                showsRenameClassroom = false
                classroomPendingDeletion = nil
                editingClassroomName = activeTeacherClassroom?.name ?? ""
            }
            .alert(
                codeResetHasExistingCode ? "重設班級代碼？" : "建立班級代碼？",
                isPresented: Binding(
                    get: { classIdPendingCodeReset != nil },
                    set: { if !$0 { classIdPendingCodeReset = nil } }
                )
            ) {
                Button("取消", role: .cancel) {
                    classIdPendingCodeReset = nil
                }
                Button(codeResetHasExistingCode ? "重設代碼" : "建立代碼") {
                    guard let classId = classIdPendingCodeReset else { return }
                    classIdPendingCodeReset = nil
                    Task { await appState.resetClassroomCode(classId: classId) }
                }
            } message: {
                Text(codeResetHasExistingCode
                    ? "舊代碼會立即失效；已加入的學生不受影響。"
                    : "建立後，學生可以用這組 8 碼代碼加入班級。")
            }
            .alert(
                "刪除「\(classroomPendingDeletion?.name ?? "班級")」？",
                isPresented: Binding(
                    get: { classroomPendingDeletion != nil },
                    set: { if !$0 { classroomPendingDeletion = nil } }
                )
            ) {
                Button("取消", role: .cancel) {
                    classroomPendingDeletion = nil
                }
                Button("刪除班級", role: .destructive) {
                    guard let classroom = classroomPendingDeletion else { return }
                    classroomPendingDeletion = nil
                    Task {
                        let deleted = await appState.deleteClassroom(classId: classroom.classId)
                        if deleted {
                            showsRenameClassroom = false
                            editingClassroomName = ""
                            selectedStudentUid = nil
                            showsCreateClassroom = teacherClassrooms.isEmpty
                        }
                    }
                }
            } message: {
                Text("學生與志工會立即退出，未完成的班級任務也會停止。這個動作無法在 App 內復原；必要的稽核紀錄仍會保留。")
            }
        }
    }

    @ViewBuilder
    private var assignmentWorkspace: some View {
        TeacherClassAssignmentHeader(
            studentCount: activeClassStudents.count,
            waitingHelpCount: learningRepository.staffDashboardMetrics.waitingHelpCount,
            assignmentCount: learningRepository.assignedPracticeTasks.filter { $0.status != .withdrawn }.count
        )

        TeacherClassRosterSummaryCard(
            metrics: learningRepository.staffDashboardMetrics,
            students: activeClassStudents
        )

        if appState.isLoadingClassroomStudents {
            ProgressView("正在載入班級學生...")
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
        } else if let rosterError = appState.classroomRosterErrorMessage {
            TeacherClassroomMessage(text: rosterError, isError: true)
            Button {
                guard let classId = appState.currentProfile?.activeClassId else { return }
                Task { await appState.loadClassroomStudents(classId: classId) }
            } label: {
                Label("重新載入學生", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(SecondaryActionButtonStyle())
        }

        if !appState.isLoadingClassroomStudents && appState.classroomRosterErrorMessage == nil {
            TeacherStudentPickerCard(
                students: activeClassStudents,
                selectedStudentUid: $selectedStudentUid
            )

            if let selectedStudent {
                TeacherSelectedStudentPanel(
                student: selectedStudent,
                assignments: learningRepository.assignments(forStudentUid: selectedStudent.studentUid),
                missionAttempts: learningRepository.missionAttempts,
                questionBankItems: learningRepository.questionBankItems,
                recommendationText: recommendationText(for: selectedStudent)
                ) { assignment in
                    learningRepository.withdrawAssignedPracticeTask(assignment.id)
                    assignmentConfirmation = "已收回 \(selectedStudent.studentName) 的任務：\(assignment.setTitle)"
                }

                if let assignmentConfirmation {
                    TeacherAssignmentConfirmationCard(message: assignmentConfirmation)
                }

                TeacherPracticeSetCatalog(
                selectedStudent: selectedStudent,
                classStudentCount: activeClassStudents.count,
                assignmentAudience: $assignmentAudience,
                sets: learningRepository.questionPracticeSets,
                selectedQuestionType: $selectedQuestionType,
                selectedLevel: $selectedLevel,
                selectedSkill: $selectedSkill
                ) { set in
                    let recipients = assignmentAudience == .entireClass
                        ? activeClassStudents
                        : [selectedStudent]
                    recipients.forEach {
                        learningRepository.assignPracticeSet(set, to: $0, by: appState.currentUser)
                    }
                    assignmentConfirmation = assignmentAudience == .entireClass
                        ? "已將「\(set.title)」指派給全班 \(recipients.count) 位學生。"
                        : "已指派給 \(selectedStudent.studentName)：\(set.title)"
                }
            } else {
                TeacherClassEmptyStudentCard()
            }
        }
    }

    private var teacherClassroomManagementCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "person.3.sequence.fill")
                    .font(.title3)
                    .foregroundStyle(EPTheme.primary)
                    .frame(width: 40, height: 40)
                    .background(EPTheme.primary.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Text("班級控制台")
                        .font(.headline)
                        .foregroundStyle(EPTheme.ink)
                    Text(activeTeacherClassroom == nil
                        ? "先建立或選擇班級，再查看學生與指派任務。"
                        : "目前管理「\(activeTeacherClassroom?.name ?? "班級")」。學生用下方代碼加入。")
                        .font(.subheadline)
                        .foregroundStyle(EPTheme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if appState.isLoadingClassrooms {
                ProgressView("正在載入班級...")
                    .font(.footnote)
            }

            if !teacherClassrooms.isEmpty {
                Menu {
                    ForEach(teacherClassrooms) { classroom in
                        Button {
                            Task { await appState.selectActiveClass(classroom.classId) }
                        } label: {
                            Label(
                                classroom.name,
                                systemImage: classroom.classId == appState.currentProfile?.activeClassId
                                    ? "checkmark.circle.fill"
                                    : "circle"
                            )
                        }
                    }
                } label: {
                    HStack {
                        Label(activeTeacherClassroom?.name ?? "選擇班級", systemImage: "building.2")
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                    }
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.horizontal, 12)
                    .foregroundStyle(EPTheme.ink)
                    .background(EPTheme.secondarySurface)
                    .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
                }
            }

            if let classroom = activeTeacherClassroom {
                if showsRenameClassroom {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("班級名稱")
                            .font(.caption.bold())
                            .foregroundStyle(EPTheme.secondaryInk)
                        TextField("輸入班級名稱", text: $editingClassroomName)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .padding(12)
                            .background(EPTheme.secondarySurface)
                            .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))

                        HStack(spacing: 8) {
                            Button {
                                Task {
                                    let updated = await appState.updateClassroom(
                                        classId: classroom.classId,
                                        name: editingClassroomName
                                    )
                                    if updated { showsRenameClassroom = false }
                                }
                            } label: {
                                Label("儲存名稱", systemImage: "checkmark")
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .buttonStyle(PrimaryActionButtonStyle())
                            .disabled(trimmedEditingClassroomName.count < 2 || appState.isManagingClassroom)
                            .opacity(trimmedEditingClassroomName.count >= 2 && !appState.isManagingClassroom ? 1 : 0.45)

                            Button("取消") {
                                editingClassroomName = classroom.name
                                showsRenameClassroom = false
                            }
                            .buttonStyle(SecondaryActionButtonStyle())
                        }
                    }
                    .padding(12)
                    .background(EPTheme.secondarySurface)
                    .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
                } else {
                    Button {
                        editingClassroomName = classroom.name
                        showsRenameClassroom = true
                    } label: {
                        Label("編輯班級名稱", systemImage: "pencil")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }
            }

            if let classroom = activeTeacherClassroom,
               let displayCode = classroom.formattedJoinCode {
                VStack(alignment: .leading, spacing: 10) {
                    Text("學生加入代碼")
                        .font(.caption.bold())
                        .foregroundStyle(EPTheme.secondaryInk)
                    Text(displayCode)
                        .font(.title2.monospaced().bold())
                        .foregroundStyle(EPTheme.ink)
                        .textSelection(.enabled)

                    HStack(spacing: 8) {
                        Button {
                            #if canImport(UIKit)
                            UIPasteboard.general.string = classroom.joinCode
                            #endif
                            copiedClassCode = classroom.classId
                        } label: {
                            Label(
                                copiedClassCode == classroom.classId ? "已複製" : "複製代碼",
                                systemImage: copiedClassCode == classroom.classId ? "checkmark" : "doc.on.doc"
                            )
                            .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(PrimaryActionButtonStyle())

                        Button {
                            classIdPendingCodeReset = classroom.classId
                        } label: {
                            Label("重設", systemImage: "arrow.triangle.2.circlepath")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                        .disabled(appState.isManagingClassroom)
                    }
                }
                .padding(12)
                .background(EPTheme.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
            }

            if let classroom = activeTeacherClassroom, classroom.joinCode == nil {
                Button {
                    classIdPendingCodeReset = classroom.classId
                } label: {
                    Label("建立學生加入代碼", systemImage: "key.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(appState.isManagingClassroom)
            }

            if showsCreateClassroom || teacherClassrooms.isEmpty {
                createClassroomForm
            } else {
                Button {
                    showsCreateClassroom = true
                } label: {
                    Label("建立另一個班級", systemImage: "plus.circle")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }

            if let classroom = activeTeacherClassroom {
                Divider()
                    .overlay(EPTheme.hairline)

                Button(role: .destructive) {
                    classroomPendingDeletion = classroom
                } label: {
                    Label("刪除這個班級", systemImage: "trash")
                        .font(.subheadline.bold())
                        .foregroundStyle(EPTheme.warning)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .disabled(appState.isManagingClassroom)
            }

            if let notice = appState.classroomNoticeMessage {
                TeacherClassroomMessage(text: notice, isError: false)
            }
            if let error = appState.classroomErrorMessage {
                TeacherClassroomMessage(text: error, isError: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private var createClassroomForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("建立班級")
                .font(.subheadline.bold())
                .foregroundStyle(EPTheme.ink)
            TextField("例如：八年級英文 A 班", text: $newClassroomName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(12)
                .background(EPTheme.secondarySurface)
                .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))

            HStack(spacing: 8) {
                Button {
                    Task {
                        let created = await appState.createClassroom(name: newClassroomName)
                        if created {
                            newClassroomName = ""
                            showsCreateClassroom = false
                        }
                    }
                } label: {
                    if appState.isManagingClassroom {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 44)
                    } else {
                        Label("建立班級", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(trimmedClassroomName.count < 2 || appState.isManagingClassroom)
                .opacity(trimmedClassroomName.count >= 2 && !appState.isManagingClassroom ? 1 : 0.45)

                if !teacherClassrooms.isEmpty {
                    Button("取消") {
                        newClassroomName = ""
                        showsCreateClassroom = false
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }
            }
        }
    }

    private var teacherClassrooms: [ClassroomSummary] {
        appState.classrooms.filter { $0.role == .teacher && $0.status == .active }
    }

    private var activeTeacherClassroom: ClassroomSummary? {
        teacherClassrooms.first { $0.classId == appState.currentProfile?.activeClassId }
    }

    private var trimmedClassroomName: String {
        newClassroomName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedEditingClassroomName: String {
        editingClassroomName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var codeResetHasExistingCode: Bool {
        guard let classIdPendingCodeReset else { return false }
        return teacherClassrooms.first { $0.classId == classIdPendingCodeReset }?.joinCode != nil
    }

    private var selectedStudent: StaffStudentSummary? {
        activeClassStudents.first { $0.studentUid == selectedStudentUid }
            ?? activeClassStudents.first
    }

    private var activeClassStudents: [StaffStudentSummary] {
        let supportSummaries = Dictionary(
            learningRepository.staffStudentSummaries.map { ($0.studentUid, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return appState.classroomStudents.map { rosterStudent in
            guard let support = supportSummaries[rosterStudent.studentUid] else {
                return rosterStudent.staffSummary
            }
            return StaffStudentSummary(
                id: rosterStudent.studentUid,
                studentUid: rosterStudent.studentUid,
                studentName: rosterStudent.studentName,
                classCode: rosterStudent.classId,
                moodScore: support.moodScore ?? rosterStudent.moodScore,
                riskLevel: support.riskLevel,
                missionProgress: rosterStudent.staffSummary.missionProgress,
                nextAction: support.nextAction
            )
        }
    }

    private func recommendationText(for selectedStudent: StaffStudentSummary) -> String {
        switch selectedStudent.riskLevel {
        case .high:
            return "建議先給基礎或穩定題組，讓學生用 5 到 8 分鐘完成一個小成功。"
        case .medium:
            return "建議先給穩定題組，再視答題狀況補一組會考挑戰。"
        case .low:
            return "可以給會考挑戰或進階挑戰，讓學生維持成就感與挑戰感。"
        }
    }
}

private struct TeacherNoActiveClassCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("尚未選擇班級", systemImage: "person.3")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)
            Text("建立或選擇班級後，這裡才會顯示該班學生、任務與題組。")
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

private struct TeacherClassroomMessage: View {
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

private struct TeacherClassAssignmentHeader: View {
    let studentCount: Int
    let waitingHelpCount: Int
    let assignmentCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("班級學生與派題")
                    .font(.title.bold())
                    .foregroundStyle(EPTheme.ink)
                Text("先看班級狀態，再選學生指派每組 12 題內的小題組。題組已依題型、難度與技能整理，不需要老師從整份題庫慢慢找。")
                    .font(.subheadline)
                    .foregroundStyle(EPTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                TeacherStatusTile(title: "學生", value: "\(studentCount)", color: EPTheme.primary)
                TeacherStatusTile(title: "待接住", value: "\(waitingHelpCount)", color: EPTheme.warning)
                TeacherStatusTile(title: "已派題", value: "\(assignmentCount)", color: EPTheme.support)
            }
        }
    }
}

private struct TeacherClassRosterSummaryCard: View {
    let metrics: StaffDashboardMetrics
    let students: [StaffStudentSummary]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("班級概況", systemImage: "person.3.sequence.fill")
                        .font(.headline)
                        .foregroundStyle(EPTheme.ink)
                    Text("這裡是老師派任務前的總覽：先看學生主動送出的求助與任務狀態，再決定要派基礎修復、穩定練習或挑戰題。")
                        .font(.subheadline)
                        .foregroundStyle(EPTheme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            HStack(spacing: 10) {
                TeacherStatusTile(title: "優先回覆", value: "\(metrics.priorityHelpCount)", color: EPTheme.warning)
                TeacherStatusTile(title: "待回覆", value: "\(metrics.waitingHelpCount)", color: EPTheme.primary)
                TeacherStatusTile(title: "平均心情", value: metrics.averageMoodText, color: EPTheme.support)
            }

            if metrics.priorityHelpCount > 0,
               let firstPriority = students.sorted(by: prioritySort).first(where: { $0.riskLevel == .high }) {
                Text("建議先看 \(firstPriority.studentName)：\(firstPriority.nextAction)")
                    .font(.footnote)
                    .foregroundStyle(EPTheme.ink)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(EPTheme.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Text("目前沒有學生主動送出的優先求助，可依任務進度安排下一組練習。")
                    .font(.footnote)
                    .foregroundStyle(EPTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private func prioritySort(_ lhs: StaffStudentSummary, _ rhs: StaffStudentSummary) -> Bool {
        if riskScore(lhs.riskLevel) != riskScore(rhs.riskLevel) {
            return riskScore(lhs.riskLevel) > riskScore(rhs.riskLevel)
        }
        return lhs.studentName < rhs.studentName
    }

    private func riskScore(_ risk: RiskLevel) -> Int {
        switch risk {
        case .low:
            return 1
        case .medium:
            return 2
        case .high:
            return 3
        }
    }
}

private struct TeacherStudentPickerCard: View {
    let students: [StaffStudentSummary]
    @Binding var selectedStudentUid: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("1. 選班級學生", systemImage: "person.crop.circle.badge.checkmark")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)

            if students.isEmpty {
                Text("目前沒有學生資料。學生登入、送出求助或產生學習紀錄後，會出現在這裡。")
                    .font(.subheadline)
                    .foregroundStyle(EPTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(sortedStudents) { student in
                            studentButton(student)
                        }
                    }
                    .padding(.vertical, 2)
                }
                Text("先選學生，再查看未完成任務、完成紀錄與可指派題組。")
                    .font(.caption)
                    .foregroundStyle(EPTheme.secondaryInk)
            }
        }
        .padding(16)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
        .onAppear {
            if selectedStudentUid == nil {
                selectedStudentUid = sortedStudents.first?.studentUid
            }
        }
        .onChange(of: sortedStudents.map(\.studentUid)) { _, studentIds in
            guard !studentIds.isEmpty else {
                selectedStudentUid = nil
                return
            }
            if selectedStudentUid.map({ !studentIds.contains($0) }) ?? true {
                selectedStudentUid = studentIds.first
            }
        }
    }

    private var sortedStudents: [StaffStudentSummary] {
        students.sorted { lhs, rhs in
            if riskScore(lhs.riskLevel) != riskScore(rhs.riskLevel) {
                return riskScore(lhs.riskLevel) > riskScore(rhs.riskLevel)
            }
            return lhs.studentName < rhs.studentName
        }
    }

    private var selectedStudent: StaffStudentSummary? {
        sortedStudents.first { $0.studentUid == selectedStudentUid } ?? sortedStudents.first
    }

    private func studentButton(_ student: StaffStudentSummary) -> some View {
        let isSelected = selectedStudent?.studentUid == student.studentUid
        return Button {
            selectedStudentUid = student.studentUid
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Text(student.studentName)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                    Text(student.riskLevel.uiTitle)
                        .font(.caption2.bold())
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(isSelected ? .white.opacity(0.18) : riskColor(for: student.riskLevel).opacity(0.14))
                        .clipShape(Capsule())
                }

                Text(student.missionProgress)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .white.opacity(0.86) : EPTheme.secondaryInk)
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? .white : EPTheme.ink)
            .frame(width: 156, alignment: .leading)
            .padding(12)
            .background(isSelected ? EPTheme.primary : EPTheme.secondarySurface)
            .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
        }
        .buttonStyle(.plain)
    }

    private func riskScore(_ risk: RiskLevel) -> Int {
        switch risk {
        case .low:
            return 1
        case .medium:
            return 2
        case .high:
            return 3
        }
    }

    private func riskColor(for risk: RiskLevel) -> Color {
        switch risk {
        case .low:
            return EPTheme.support
        case .medium:
            return EPTheme.primary
        case .high:
            return EPTheme.warning
        }
    }
}

private struct TeacherSelectedStudentPanel: View {
    let student: StaffStudentSummary
    let assignments: [TeacherAssignedPracticeTask]
    let missionAttempts: [MissionAttempt]
    let questionBankItems: [QuestionBankItem]
    let recommendationText: String
    let withdrawAssignment: (TeacherAssignedPracticeTask) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("2. 看學生狀態與作業", systemImage: "list.clipboard")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)

            TeacherStudentMissionPanel(
                student: student,
                recommendationText: recommendationText
            )

            TeacherStudentAssignmentDashboard(
                assignments: assignments,
                missionAttempts: missionAttempts,
                questionBankItems: questionBankItems,
                withdrawAssignment: withdrawAssignment
            )
        }
        .padding(16)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct TeacherStudentAssignmentDashboard: View {
    let assignments: [TeacherAssignedPracticeTask]
    let missionAttempts: [MissionAttempt]
    let questionBankItems: [QuestionBankItem]
    let withdrawAssignment: (TeacherAssignedPracticeTask) -> Void
    @State private var collapsedAssignmentIds: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("作業紀錄")
                        .font(.subheadline.bold())
                        .foregroundStyle(EPTheme.ink)
                    Text("未完成任務、完成紀錄與每題對錯都會集中在這裡。")
                        .font(.caption)
                        .foregroundStyle(EPTheme.secondaryInk)
                }
                Spacer()
                Text("\(visibleAssignments.count) 筆")
                    .font(.caption.bold())
                    .foregroundStyle(EPTheme.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(EPTheme.primary.opacity(0.10))
                    .clipShape(Capsule())
            }

            if displayableAssignments.isEmpty {
                TeacherAssignmentEmptyCard(
                    title: "還沒有派發紀錄",
                    message: "下方指派題組後，這位學生的任務會先出現在未完成任務；完成後會移到完成紀錄。"
                )
            } else {
                TeacherAssignmentSection(
                    title: "未完成任務",
                    subtitle: "學生尚未完成的派發題組。",
                    assignments: activeAssignments,
                    attemptsByQuestionId: latestAttemptsByQuestionId,
                    questionsById: questionsById,
                    emptyTitle: "沒有未完成任務",
                    emptyMessage: "目前沒有等待學生完成的派發題組。",
                    collapseAssignment: collapseAssignment,
                    withdrawAssignment: withdrawAssignment
                )

                TeacherAssignmentSection(
                    title: "完成紀錄",
                    subtitle: "完成後可查看每題答對或答錯。",
                    assignments: completedAssignments,
                    attemptsByQuestionId: latestAttemptsByQuestionId,
                    questionsById: questionsById,
                    emptyTitle: "還沒有完成紀錄",
                    emptyMessage: "學生完成派發任務後，會在這裡留下結果。",
                    collapseAssignment: collapseAssignment,
                    withdrawAssignment: nil
                )

                if !collapsedAssignmentIds.isEmpty {
                    Button {
                        collapsedAssignmentIds.removeAll()
                    } label: {
                        Label("顯示已收起 \(collapsedAssignmentIds.count) 筆", systemImage: "tray.and.arrow.up")
                            .font(.caption.bold())
                            .frame(maxWidth: .infinity, minHeight: 40)
                    }
                    .buttonStyle(.bordered)
                    .tint(EPTheme.primary)
                }
            }
        }
    }

    private var visibleAssignments: [TeacherAssignedPracticeTask] {
        displayableAssignments.filter { !collapsedAssignmentIds.contains($0.id) }
    }

    private var displayableAssignments: [TeacherAssignedPracticeTask] {
        assignments.filter { $0.status != .withdrawn }
    }

    private var activeAssignments: [TeacherAssignedPracticeTask] {
        visibleAssignments.filter { $0.status == .pending || $0.status == .active }
    }

    private var completedAssignments: [TeacherAssignedPracticeTask] {
        visibleAssignments.filter { $0.status == .completed }
    }

    private var latestAttemptsByQuestionId: [String: MissionAttempt] {
        Dictionary(grouping: missionAttempts, by: \.questionId)
            .compactMapValues { attempts in
                attempts.max { $0.createdAt < $1.createdAt }
            }
    }

    private var questionsById: [String: QuestionBankItem] {
        Dictionary(questionBankItems.map { ($0.id, $0) }, uniquingKeysWith: { existing, _ in existing })
    }

    private func collapseAssignment(_ assignment: TeacherAssignedPracticeTask) {
        collapsedAssignmentIds.insert(assignment.id)
    }
}

private struct TeacherAssignmentSection: View {
    let title: String
    let subtitle: String
    let assignments: [TeacherAssignedPracticeTask]
    let attemptsByQuestionId: [String: MissionAttempt]
    let questionsById: [String: QuestionBankItem]
    let emptyTitle: String
    let emptyMessage: String
    let collapseAssignment: (TeacherAssignedPracticeTask) -> Void
    let withdrawAssignment: ((TeacherAssignedPracticeTask) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(EPTheme.ink)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(EPTheme.secondaryInk)
            }

            if assignments.isEmpty {
                TeacherAssignmentEmptyCard(title: emptyTitle, message: emptyMessage)
            } else {
                ForEach(assignments) { assignment in
                    TeacherAssignmentReviewCard(
                        assignment: assignment,
                        attemptsByQuestionId: attemptsByQuestionId,
                        questionsById: questionsById,
                        collapse: {
                            collapseAssignment(assignment)
                        },
                        withdraw: withdrawAssignment == nil ? nil : {
                            withdrawAssignment?(assignment)
                        }
                    )
                }
            }
        }
    }
}

private struct TeacherAssignmentReviewCard: View {
    let assignment: TeacherAssignedPracticeTask
    let attemptsByQuestionId: [String: MissionAttempt]
    let questionsById: [String: QuestionBankItem]
    let collapse: () -> Void
    let withdraw: (() -> Void)?
    @State private var showsQuestionResults = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(assignment.setTitle)
                        .font(.subheadline.bold())
                        .foregroundStyle(EPTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("指派者：\(assignment.assignedByName) · \(assignment.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(EPTheme.secondaryInk)
                }

                Spacer()

                Text(assignment.status.displayTitle)
                    .font(.caption.bold())
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(statusColor.opacity(0.12))
                    .clipShape(Capsule())
            }

            HStack(spacing: 10) {
                TeacherStatusTile(title: "題數", value: "\(assignment.questionIds.count)", color: EPTheme.primary)
                TeacherStatusTile(title: "已答", value: "\(answeredCount)", color: EPTheme.support)
                TeacherStatusTile(title: "答對", value: "\(correctCount)", color: EPTheme.warning)
            }

            if assignment.status == .completed {
                DisclosureGroup(isExpanded: $showsQuestionResults) {
                    VStack(spacing: 8) {
                        ForEach(resultRows) { row in
                            TeacherAssignmentQuestionResultRow(row: row)
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    Label("查看每題對錯", systemImage: "checklist")
                        .font(.caption.bold())
                        .foregroundStyle(EPTheme.primary)
                }
            } else {
                Text("學生完成後，這裡會顯示每一題的作答結果。")
                    .font(.caption)
                    .foregroundStyle(EPTheme.secondaryInk)
            }

            HStack(spacing: 10) {
                if let withdraw {
                    Button(role: .destructive, action: withdraw) {
                        Label("收回任務", systemImage: "arrow.uturn.backward")
                            .font(.caption.bold())
                            .frame(maxWidth: .infinity, minHeight: 38)
                    }
                    .buttonStyle(.bordered)
                    .tint(EPTheme.warning)
                }

                Button(action: collapse) {
                    Label("收起這筆", systemImage: "archivebox")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity, minHeight: 38)
                }
                .buttonStyle(.bordered)
                .tint(EPTheme.primary)
            }
        }
        .padding(12)
        .background(EPTheme.secondarySurface)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
        .onAppear {
            if assignment.status == .completed {
                showsQuestionResults = true
            }
        }
    }

    private var statusColor: Color {
        switch assignment.status {
        case .pending:
            return EPTheme.warning
        case .active:
            return EPTheme.primary
        case .completed:
            return EPTheme.support
        case .withdrawn:
            return EPTheme.secondaryInk
        }
    }

    private var resultRows: [TeacherAssignmentQuestionResult] {
        assignment.questionIds.enumerated().map { index, questionId in
            let snapshot = assignment.questionResults?.first { $0.questionId == questionId }
            let attempt = attemptsByQuestionId[questionId]
            let question = questionsById[questionId]
            return TeacherAssignmentQuestionResult(
                id: "\(assignment.id)-\(questionId)-\(index)",
                number: index + 1,
                prompt: snapshot?.prompt ?? attempt?.prompt ?? question?.question.prompt ?? "題目內容目前無法載入",
                selectedAnswer: snapshot?.selectedAnswer ?? attempt?.selectedAnswer,
                acceptedAnswer: snapshot?.acceptedAnswer ?? attempt?.acceptedAnswer ?? question?.question.answer,
                isCorrect: snapshot?.isCorrect ?? attempt?.isCorrect,
                explanation: snapshot?.explanation ?? attempt?.explanation ?? question?.question.explanation
            )
        }
    }

    private var answeredCount: Int {
        resultRows.filter { $0.selectedAnswer != nil }.count
    }

    private var correctCount: Int {
        resultRows.filter { $0.isCorrect == true }.count
    }
}

private struct TeacherAssignmentQuestionResult: Identifiable {
    let id: String
    let number: Int
    let prompt: String
    let selectedAnswer: String?
    let acceptedAnswer: String?
    let isCorrect: Bool?
    let explanation: String?
}

private struct TeacherAssignmentQuestionResultRow: View {
    let row: TeacherAssignmentQuestionResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(row.number)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(statusColor)
                    .clipShape(Circle())
                Text(row.prompt)
                    .font(.caption.bold())
                    .foregroundStyle(EPTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                resultPill(title: "學生", value: row.selectedAnswer ?? "未作答", color: row.isCorrect == false ? EPTheme.warning : EPTheme.secondaryInk)
                resultPill(title: "正解", value: row.acceptedAnswer ?? "未提供", color: EPTheme.support)
            }

            if let explanation = row.explanation, !explanation.isEmpty {
                Text(explanation)
                    .font(.caption2)
                    .foregroundStyle(EPTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var statusColor: Color {
        switch row.isCorrect {
        case .some(true):
            return EPTheme.support
        case .some(false):
            return EPTheme.warning
        case .none:
            return EPTheme.secondaryInk
        }
    }

    private func resultPill(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.bold())
                .foregroundStyle(EPTheme.secondaryInk)
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(color)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct TeacherAssignmentEmptyCard: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(EPTheme.ink)
            Text(message)
                .font(.caption)
                .foregroundStyle(EPTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.secondarySurface)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct TeacherStudentMissionPanel: View {
    let student: StaffStudentSummary
    let recommendationText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(student.studentName)
                        .font(.title3.bold())
                        .foregroundStyle(EPTheme.ink)
                    Text(student.classCode)
                        .font(.caption)
                        .foregroundStyle(EPTheme.secondaryInk)
                }
                Spacer()
                Text(student.riskLevel.uiTitle)
                    .font(.caption.bold())
                    .foregroundStyle(student.riskLevel == .high ? EPTheme.warning : EPTheme.support)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background((student.riskLevel == .high ? EPTheme.warning : EPTheme.support).opacity(0.12))
                    .clipShape(Capsule())
            }

            HStack(spacing: 10) {
                TeacherStatusTile(title: "心情", value: moodText, color: EPTheme.support)
                TeacherStatusTile(title: "任務", value: student.missionProgress, color: EPTheme.primary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("下一步")
                    .font(.caption.bold())
                    .foregroundStyle(EPTheme.secondaryInk)
                Text(student.nextAction)
                    .font(.subheadline)
                    .foregroundStyle(EPTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(recommendationText)
                    .font(.footnote)
                    .foregroundStyle(EPTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(EPTheme.secondarySurface)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private var moodText: String {
        guard let moodScore = student.moodScore else { return "未填" }
        return "\(moodScore)/5"
    }
}

private struct TeacherAssignmentConfirmationCard: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "checkmark.circle.fill")
            .font(.subheadline.bold())
            .foregroundStyle(EPTheme.support)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EPTheme.support.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct TeacherClassEmptyStudentCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("目前還沒有可指派學生", systemImage: "person.3")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)
            Text("把班級代碼分享給學生；學生加入後就會出現在這裡，不需要先完成題目或送出求助。")
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

private struct TeacherEmptyQueueCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("目前沒有需要接住的學生", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(EPTheme.support)
            Text("班級目前沒有新的高優先求助。可以先查看題庫指派，或到報告頁確認整體學習狀態。")
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

private struct TeacherPracticeSetCatalog: View {
    let selectedStudent: StaffStudentSummary
    let classStudentCount: Int
    @Binding var assignmentAudience: TeacherAssignmentAudience
    let sets: [QuestionPracticeSet]
    @Binding var selectedQuestionType: QuestionType?
    @Binding var selectedLevel: QuestionLevel?
    @Binding var selectedSkill: String?
    let assignPracticeSet: (QuestionPracticeSet) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Label("3. 依技能指派小題組", systemImage: "books.vertical")
                    .font(.headline)
                    .foregroundStyle(EPTheme.ink)
                Text(assignmentAudience == .entireClass
                    ? "每組 12 題內，先按題型、難度與技能縮小範圍，再一次指派給目前班級。"
                    : "每組 12 題內，先按題型、難度與技能縮小範圍，再指派給 \(selectedStudent.studentName)。")
                    .font(.subheadline)
                    .foregroundStyle(EPTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("指派範圍")
                    .font(.caption.bold())
                    .foregroundStyle(EPTheme.secondaryInk)
                Picker("指派範圍", selection: $assignmentAudience) {
                    ForEach(TeacherAssignmentAudience.allCases) { audience in
                        Text(audience.title).tag(audience)
                    }
                }
                .pickerStyle(.segmented)
                Text(assignmentAudience == .entireClass
                    ? "這組題目會分別建立給全班 \(classStudentCount) 位學生。"
                    : "這組題目只會指派給 \(selectedStudent.studentName)。")
                    .font(.caption)
                    .foregroundStyle(EPTheme.secondaryInk)
            }

            filterSection

            if filteredPracticeSets.isEmpty {
                Text("目前沒有符合篩選條件的題組。")
                    .font(.subheadline)
                    .foregroundStyle(EPTheme.secondaryInk)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(EPTheme.secondarySurface)
                    .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(groupedPracticeSetsBySkill, id: \.skill) { group in
                        TeacherPracticeSetSkillSection(
                            skill: group.skill,
                            sets: group.sets,
                            assignPracticeSet: assignPracticeSet
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    TeacherFilterChip(title: "全部題型", isSelected: selectedQuestionType == nil) {
                        selectedQuestionType = nil
                        selectedSkill = nil
                    }
                    ForEach(QuestionType.allCases) { type in
                        TeacherFilterChip(title: type.title, isSelected: selectedQuestionType == type) {
                            selectedQuestionType = type
                            selectedSkill = nil
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    TeacherFilterChip(title: "全部難度", isSelected: selectedLevel == nil) {
                        selectedLevel = nil
                        selectedSkill = nil
                    }
                    ForEach(QuestionLevel.allCases) { level in
                        TeacherFilterChip(title: level.uiTitle, isSelected: selectedLevel == level) {
                            selectedLevel = level
                            selectedSkill = nil
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            TeacherSkillFilterSection(
                skills: availableSkills,
                selectedSkill: $selectedSkill
            )
        }
    }

    private var filteredPracticeSets: [QuestionPracticeSet] {
        sets
            .filter { set in
                let typeMatches = selectedQuestionType.map { $0 == set.type } ?? true
                let levelMatches = selectedLevel.map { $0 == set.level } ?? true
                let skillMatches = selectedSkill.map { $0 == set.skill } ?? true
                return typeMatches && levelMatches && skillMatches
            }
            .sorted { lhs, rhs in
                if lhs.type.rawValue != rhs.type.rawValue {
                    return lhs.type.rawValue < rhs.type.rawValue
                }
                if lhs.level.rawValue != rhs.level.rawValue {
                    return lhs.level.rawValue < rhs.level.rawValue
                }
                return lhs.skill < rhs.skill
            }
    }

    private var availableSkills: [String] {
        let scope = sets.filter { set in
            let typeMatches = selectedQuestionType.map { $0 == set.type } ?? true
            let levelMatches = selectedLevel.map { $0 == set.level } ?? true
            return typeMatches && levelMatches
        }
        return Array(Set(scope.map(\.skill))).sorted()
    }

    private var groupedPracticeSetsBySkill: [(skill: String, sets: [QuestionPracticeSet])] {
        availableSkills.compactMap { skill in
            let groupSets = filteredPracticeSets.filter { $0.skill == skill }
            return groupSets.isEmpty ? nil : (skill, Array(groupSets.prefix(6)))
        }
    }
}

private struct TeacherSkillFilterSection: View {
    let skills: [String]
    @Binding var selectedSkill: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                TeacherFilterChip(title: "全部技能", isSelected: selectedSkill == nil) {
                    selectedSkill = nil
                }
                ForEach(skills.prefix(16), id: \.self) { skill in
                    TeacherFilterChip(title: skill, isSelected: selectedSkill == skill) {
                        selectedSkill = skill
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }
}

private struct TeacherPracticeSetSkillSection: View {
    let skill: String
    let sets: [QuestionPracticeSet]
    let assignPracticeSet: (QuestionPracticeSet) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(skill)
                    .font(.subheadline.bold())
                    .foregroundStyle(EPTheme.ink)
                Spacer()
                Text("\(sets.count) 組")
                    .font(.caption.bold())
                    .foregroundStyle(EPTheme.primary)
            }

            ForEach(sets) { set in
                TeacherPracticeSetCatalogRow(set: set) {
                    assignPracticeSet(set)
                }
            }
        }
        .padding(12)
        .background(EPTheme.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct TeacherPracticeSetCatalogRow: View {
    let set: QuestionPracticeSet
    let assign: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(set.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(EPTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(set.subtitle)
                        .font(.caption)
                        .foregroundStyle(EPTheme.secondaryInk)
                    Text("技能：\(set.skill)")
                        .font(.caption)
                        .foregroundStyle(EPTheme.secondaryInk)
                        .lineLimit(2)
                    Text("概念：\(set.previewText)")
                        .font(.caption)
                        .foregroundStyle(EPTheme.secondaryInk)
                        .lineLimit(2)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text("\(set.questionCount) 題")
                        .font(.caption.bold())
                    Text("約 \(set.estimatedMinutes) 分")
                        .font(.caption2.bold())
                }
                .foregroundStyle(EPTheme.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(EPTheme.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Button(action: assign) {
                Label("指派這組", systemImage: "paperplane.fill")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(PrimaryActionButtonStyle())
        }
        .padding(12)
        .background(EPTheme.secondarySurface)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct TeacherFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(isSelected ? .white : EPTheme.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(isSelected ? EPTheme.primary : EPTheme.secondarySurface)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private extension PracticeAssignmentStatus {
    var displayTitle: String {
        switch self {
        case .pending:
            return "待學生開始"
        case .active:
            return "學生練習中"
        case .completed:
            return "已完成"
        case .withdrawn:
            return "已收回"
        }
    }
}

private struct TeacherStatusStrip: View {
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

    var body: some View {
        HStack(spacing: 10) {
            TeacherStatusTile(
                title: "優先回覆",
                value: "\(learningRepository.staffDashboardMetrics.priorityHelpCount)",
                color: EPTheme.warning
            )
            TeacherStatusTile(
                title: "待回應",
                value: "\(learningRepository.staffDashboardMetrics.waitingHelpCount)",
                color: EPTheme.primary
            )
            TeacherStatusTile(
                title: "已回覆",
                value: "\(learningRepository.staffDashboardMetrics.repliedCount)",
                color: EPTheme.support
            )
        }
    }
}

private struct TeacherStatusTile: View {
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

private struct TeacherClassSummary: View {
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("班級狀態")
                .font(.headline)
            ForEach(learningRepository.staffStudentSummaries) { summary in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(summary.studentName)
                            .font(.subheadline.bold())
                        Text(summary.missionProgress)
                            .font(.caption)
                            .foregroundStyle(EPTheme.secondaryInk)
                    }
                    Spacer()
                    Text(summary.nextAction)
                        .font(.caption)
                        .foregroundStyle(EPTheme.ink)
                        .multilineTextAlignment(.trailing)
                }
                .padding(12)
                .background(EPTheme.secondarySurface)
                .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
            }
        }
        .padding(16)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

}

private struct TeacherHandoffSummaryCard: View {
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
                TeacherStatusTile(
                    title: "學生",
                    value: "\(learningRepository.staffDashboardMetrics.studentCount)",
                    color: EPTheme.primary
                )
                TeacherStatusTile(
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

struct TeacherReportSignalCard: View {
    let title: String
    let message: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(EPTheme.ink)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(EPTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

struct TeacherQuestionBankRow: View {
    let overview: QuestionBankTypeOverview

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(overview.type.title)
                    .font(.headline)
                    .foregroundStyle(EPTheme.ink)
                Spacer()
                Text("\(overview.totalCount) 題")
                    .font(.caption.bold())
                    .foregroundStyle(EPTheme.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(EPTheme.primary.opacity(0.08))
                    .clipShape(Capsule())
            }

            Text(overview.levelSummary)
                .font(.subheadline)
                .foregroundStyle(EPTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}
