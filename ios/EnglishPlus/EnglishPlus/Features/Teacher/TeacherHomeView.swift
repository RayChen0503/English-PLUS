import SwiftUI

struct TeacherHomeView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

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
                                    TeacherRequestCard(request: request)
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

struct TeacherStudentsView: View {
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                List {
                    ForEach(learningRepository.staffStudentSummaries) { summary in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(summary.studentName)
                                    .font(.headline)
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
                                .foregroundStyle(EPTheme.ink)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("學生紀錄")
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

                        Text("排序規則：學生主動求助、高風險心情、閱讀卡點會先排在前面。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        TeacherHandoffSummaryCard()

                        ForEach(learningRepository.teacherQueue) { request in
                            TeacherRequestCard(request: request)
                        }
                    }
                    .padding(EPTheme.pagePadding)
                }
            }
            .navigationTitle("接力")
        }
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
                            .foregroundStyle(.secondary)

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
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(metric.value)
                    .font(.title2.bold())
                    .foregroundStyle(EPTheme.ink)
                    .monospacedDigit()
                Text(metric.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
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
                    .foregroundStyle(.secondary)
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
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
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
                            .foregroundStyle(.secondary)
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
        .background(.white)
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
        .background(.white)
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
                .foregroundStyle(.secondary)
                .lineLimit(10)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

struct TeacherQuestionBankView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var learningRepository: LearningRepositoryStore
    @State private var selectedStudentUid: String?

    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("題庫中心")
                            .font(.title.bold())
                            .foregroundStyle(EPTheme.ink)

                        Text("老師可以快速確認題型、難度與任務來源，之後接正式後台即可延伸成審題與派題。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        TeacherQuestionSetAssignmentCard(
                            students: learningRepository.staffStudentSummaries,
                            sets: learningRepository.questionPracticeSets,
                            selectedStudentUid: $selectedStudentUid
                        ) { set, student in
                            learningRepository.assignPracticeSet(set, to: student, by: appState.currentUser)
                        }

                        ForEach(learningRepository.questionBankOverview) { overview in
                            TeacherQuestionBankRow(overview: overview)
                        }
                    }
                    .padding(EPTheme.pagePadding)
                }
            }
            .navigationTitle("題庫")
        }
    }
}

private struct TeacherQuestionSetAssignmentCard: View {
    let students: [StaffStudentSummary]
    let sets: [QuestionPracticeSet]
    @Binding var selectedStudentUid: String?
    let assignPracticeSet: (QuestionPracticeSet, StaffStudentSummary) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("指派小題組", systemImage: "tray.and.arrow.down.fill")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)

            if students.isEmpty {
                Text("目前沒有可指派的學生。學生送出求助或同步登入後，會出現在這裡。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(students) { student in
                            studentButton(student)
                        }
                    }
                    .padding(.vertical, 2)
                }

                if let recommendedStudentForAssignment,
                   let recommendedSet = recommendedAssignmentSets.first {
                    TeacherRecommendedAssignmentCard(
                        student: recommendedStudentForAssignment,
                        set: recommendedSet
                    ) {
                        assignRecommendedPracticeSet(recommendedSet, to: recommendedStudentForAssignment)
                    }
                }

                LazyVStack(spacing: 12) {
                    ForEach(groupedSetsByType, id: \.type) { group in
                        TeacherPracticeSetGroupSection(
                            type: group.type,
                            sets: group.sets,
                            selectedStudent: selectedStudent,
                            assignPracticeSet: assignPracticeSet
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private var selectedStudent: StaffStudentSummary? {
        students.first { $0.studentUid == selectedStudentUid } ?? students.first
    }

    private var recommendedStudentForAssignment: StaffStudentSummary? {
        students.sorted { lhs, rhs in
            riskPriority(lhs.riskLevel) > riskPriority(rhs.riskLevel)
        }.first ?? selectedStudent
    }

    private var recommendedAssignmentSets: [QuestionPracticeSet] {
        guard let targetStudent = recommendedStudentForAssignment else {
            return Array(sets.prefix(3))
        }

        let recommended = sets.filter { set in
            isRecommended(set, for: targetStudent)
        }

        return Array((recommended.isEmpty ? sets : recommended).prefix(3))
    }

    private var groupedSetsByType: [(type: QuestionType, sets: [QuestionPracticeSet])] {
        return QuestionType.allCases.compactMap { type in
            let typeSets = Array(sets.filter { $0.type == type }.prefix(4))
            return typeSets.isEmpty ? nil : (type, typeSets)
        }
    }

    private func assignRecommendedPracticeSet(_ set: QuestionPracticeSet, to student: StaffStudentSummary) {
        assignPracticeSet(set, student)
    }

    private func isRecommended(_ set: QuestionPracticeSet, for student: StaffStudentSummary) -> Bool {
        switch student.riskLevel {
        case .high:
            return set.level == .a1 || set.level == .a2
        case .medium:
            return set.level == .a2 || set.level == .b1
        case .low:
            return set.level == .b1 || set.level == .b2
        }
    }

    private func riskPriority(_ riskLevel: RiskLevel) -> Int {
        switch riskLevel {
        case .low:
            return 1
        case .medium:
            return 2
        case .high:
            return 3
        }
    }

    private func studentButton(_ student: StaffStudentSummary) -> some View {
        let isSelected = selectedStudent?.studentUid == student.studentUid
        return Button {
            selectedStudentUid = student.studentUid
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(student.studentName)
                    .font(.caption.bold())
                Text(student.riskLevel.uiTitle)
                    .font(.caption2)
            }
            .foregroundStyle(isSelected ? .white : EPTheme.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(isSelected ? EPTheme.primary : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
        }
        .buttonStyle(.plain)
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
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct TeacherPracticeSetGroupSection: View {
    let type: QuestionType
    let sets: [QuestionPracticeSet]
    let selectedStudent: StaffStudentSummary?
    let assignPracticeSet: (QuestionPracticeSet, StaffStudentSummary) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(type.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(EPTheme.ink)
                Spacer()
                Text("\(sets.count) 組")
                    .font(.caption.bold())
                    .foregroundStyle(EPTheme.primary)
            }

            ForEach(sets) { set in
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(set.title)
                            .font(.subheadline.bold())
                            .foregroundStyle(EPTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(set.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(set.previewText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Button("指派") {
                        if let selectedStudent {
                            assignPracticeSet(set, selectedStudent)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedStudent == nil)
                }
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
            }
        }
        .padding(12)
        .background(EPTheme.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct TeacherRecommendedAssignmentCard: View {
    let student: StaffStudentSummary
    let set: QuestionPracticeSet
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.headline)
                    .foregroundStyle(EPTheme.primary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("建議先指派")
                        .font(.caption.bold())
                        .foregroundStyle(EPTheme.primary)
                    Text("\(student.studentName) / \(set.title)")
                        .font(.subheadline.bold())
                        .foregroundStyle(EPTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(set.questionCount) 題，約 \(set.estimatedMinutes) 分鐘。依學生風險與難度先排最容易開始的一組。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button(action: action) {
                Label("一鍵指派推薦題組", systemImage: "paperplane.fill")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(PrimaryActionButtonStyle())
        }
        .padding(12)
        .background(EPTheme.primary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct TeacherStatusStrip: View {
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

    var body: some View {
        HStack(spacing: 10) {
            TeacherStatusTile(
                title: "高風險",
                value: "\(learningRepository.staffDashboardMetrics.highRiskCount)",
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
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

struct TeacherRequestCard: View {
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
                    Text(request.classCode)
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

            if let moodScore = request.moodScore {
                Label("心情 \(moodScore)/5", systemImage: "heart.text.square")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(request.replies) { reply in
                Text("\(reply.authorName)：\(reply.body)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            TextField("輸入老師回饋", text: $replyDraft, axis: .vertical)
                .textFieldStyle(.roundedBorder)

            Button(isDraftingWithAI ? "正在產生草稿" : "AI 產生建議草稿") {
                Task {
                    await fillTeacherDraftWithAI()
                }
            }
            .buttonStyle(.bordered)
            .disabled(isDraftingWithAI)

            Button("送出回饋") {
                learningRepository.addTeacherReply(to: request.id, body: replyDraft)
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

    private func fillTeacherDraftWithAI() async {
        isDraftingWithAI = true
        let response = await appState.draftTeacherFeedbackWithAI(context: SupportAIContext(request: request))
        replyDraft = response.output.studentFacingFeedback
            ?? response.output.recommendedNextAction
            ?? response.output.teacherSummary
            ?? response.output.summary
            ?? replyDraft
        isDraftingWithAI = false
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
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(summary.nextAction)
                        .font(.caption)
                        .foregroundStyle(EPTheme.ink)
                        .multilineTextAlignment(.trailing)
                }
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
            }
        }
        .padding(16)
        .background(.white)
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

            Text("老師先看求助與風險，再決定要直接回覆、交給志工陪練，或放進本週追蹤。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
        .background(.white)
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
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
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
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}
