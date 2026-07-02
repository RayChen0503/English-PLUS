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

struct TeacherClassAssignmentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var learningRepository: LearningRepositoryStore
    @State private var selectedStudentUid: String?
    @State private var selectedQuestionType: QuestionType?
    @State private var selectedLevel: QuestionLevel?
    @State private var assignmentConfirmation: String?

    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        TeacherClassAssignmentHeader(
                            studentCount: learningRepository.staffStudentSummaries.count,
                            assignmentCount: learningRepository.assignedPracticeTasks.count
                        )

                        TeacherStudentPickerCard(
                            students: learningRepository.staffStudentSummaries,
                            selectedStudentUid: $selectedStudentUid
                        )

                        if let selectedStudent {
                            TeacherSelectedStudentPanel(
                                student: selectedStudent,
                                assignments: learningRepository.assignments(forStudentUid: selectedStudent.studentUid),
                                recommendationText: recommendationText(for: selectedStudent)
                            )

                            if let assignmentConfirmation {
                                TeacherAssignmentConfirmationCard(message: assignmentConfirmation)
                            }

                            TeacherPracticeSetCatalog(
                                selectedStudent: selectedStudent,
                                sets: learningRepository.questionPracticeSets,
                                selectedQuestionType: $selectedQuestionType,
                                selectedLevel: $selectedLevel
                            ) { set in
                                learningRepository.assignPracticeSet(set, to: selectedStudent, by: appState.currentUser)
                                assignmentConfirmation = "已指派給 \(selectedStudent.studentName)：\(set.title)"
                            }
                        } else {
                            TeacherClassEmptyStudentCard()
                        }
                    }
                    .padding(EPTheme.pagePadding)
                }
            }
            .navigationTitle("班級")
        }
    }

    private var selectedStudent: StaffStudentSummary? {
        learningRepository.staffStudentSummaries.first { $0.studentUid == selectedStudentUid }
            ?? learningRepository.staffStudentSummaries.first
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

private struct TeacherClassAssignmentHeader: View {
    let studentCount: Int
    let assignmentCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("班級派題")
                    .font(.title.bold())
                    .foregroundStyle(EPTheme.ink)
                Text("先選學生，再指派 12 題內的小題組。題組已依題型、難度與技能整理，不需要老師從整份題庫慢慢找。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                TeacherStatusTile(title: "學生", value: "\(max(studentCount, 1))", color: EPTheme.primary)
                TeacherStatusTile(title: "已派題", value: "\(assignmentCount)", color: EPTheme.support)
            }
        }
    }
}

private struct TeacherStudentPickerCard: View {
    let students: [StaffStudentSummary]
    @Binding var selectedStudentUid: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("1. 選擇學生", systemImage: "person.crop.circle.badge.checkmark")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)

            if students.isEmpty {
                Text("目前沒有學生資料。學生登入、送出求助或產生學習紀錄後，會出現在這裡。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 10) {
                    ForEach(students) { student in
                        studentButton(student)
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

    private func studentButton(_ student: StaffStudentSummary) -> some View {
        let isSelected = selectedStudent?.studentUid == student.studentUid
        return Button {
            selectedStudentUid = student.studentUid
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(student.studentName)
                        .font(.subheadline.bold())
                    Text(student.classCode)
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.86) : .secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(student.riskLevel.uiTitle)
                        .font(.caption.bold())
                    Text(student.missionProgress)
                        .font(.caption2)
                        .lineLimit(1)
                }
            }
            .foregroundStyle(isSelected ? .white : EPTheme.ink)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? EPTheme.primary : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
        }
        .buttonStyle(.plain)
    }
}

private struct TeacherSelectedStudentPanel: View {
    let student: StaffStudentSummary
    let assignments: [TeacherAssignedPracticeTask]
    let recommendationText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("2. 確認學生狀態", systemImage: "list.clipboard")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(student.studentName)
                            .font(.title3.bold())
                            .foregroundStyle(EPTheme.ink)
                        Text(student.classCode)
                            .font(.caption)
                            .foregroundStyle(.secondary)
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

                Text(student.nextAction)
                    .font(.subheadline)
                    .foregroundStyle(EPTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(recommendationText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))

            TeacherStudentAssignmentHistory(assignments: assignments)
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct TeacherStudentAssignmentHistory: View {
    let assignments: [TeacherAssignedPracticeTask]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("已指派任務")
                .font(.subheadline.bold())
                .foregroundStyle(EPTheme.ink)

            if assignments.isEmpty {
                Text("這位學生目前沒有老師指派題組。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(assignments.prefix(3)) { assignment in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: assignment.status == .completed ? "checkmark.circle.fill" : "clock")
                            .foregroundStyle(assignment.status == .completed ? EPTheme.support : EPTheme.primary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(assignment.setTitle)
                                .font(.caption.bold())
                                .foregroundStyle(EPTheme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("\(assignment.questionIds.count) 題 / \(assignment.status.displayTitle)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
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
            Text("等學生登入、完成檢測或送出求助後，這裡會出現班級名單。")
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

private struct TeacherPracticeSetCatalog: View {
    let selectedStudent: StaffStudentSummary
    let sets: [QuestionPracticeSet]
    @Binding var selectedQuestionType: QuestionType?
    @Binding var selectedLevel: QuestionLevel?
    let assignPracticeSet: (QuestionPracticeSet) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Label("3. 選擇小題組", systemImage: "books.vertical")
                    .font(.headline)
                    .foregroundStyle(EPTheme.ink)
                Text("每組最多 12 題，先按題型與難度縮小範圍，再指派給 \(selectedStudent.studentName)。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            filterSection

            if filteredPracticeSets.isEmpty {
                Text("目前沒有符合篩選條件的題組。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(groupedPracticeSets, id: \.type) { group in
                        TeacherPracticeSetCatalogSection(
                            type: group.type,
                            sets: group.sets,
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

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    TeacherFilterChip(title: "全部題型", isSelected: selectedQuestionType == nil) {
                        selectedQuestionType = nil
                    }
                    ForEach(QuestionType.allCases) { type in
                        TeacherFilterChip(title: type.title, isSelected: selectedQuestionType == type) {
                            selectedQuestionType = type
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    TeacherFilterChip(title: "全部難度", isSelected: selectedLevel == nil) {
                        selectedLevel = nil
                    }
                    ForEach(QuestionLevel.allCases) { level in
                        TeacherFilterChip(title: level.uiTitle, isSelected: selectedLevel == level) {
                            selectedLevel = level
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var filteredPracticeSets: [QuestionPracticeSet] {
        sets
            .filter { set in
                let typeMatches = selectedQuestionType.map { $0 == set.type } ?? true
                let levelMatches = selectedLevel.map { $0 == set.level } ?? true
                return typeMatches && levelMatches
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

    private var groupedPracticeSets: [(type: QuestionType, sets: [QuestionPracticeSet])] {
        QuestionType.allCases.compactMap { type in
            let groupSets = filteredPracticeSets.filter { $0.type == type }
            return groupSets.isEmpty ? nil : (type, Array(groupSets.prefix(8)))
        }
    }
}

private struct TeacherPracticeSetCatalogSection: View {
    let type: QuestionType
    let sets: [QuestionPracticeSet]
    let assignPracticeSet: (QuestionPracticeSet) -> Void

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
                        .foregroundStyle(.secondary)
                    Text("技能：\(set.previewText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Text("\(set.questionCount) 題")
                    .font(.caption.bold())
                    .foregroundStyle(EPTheme.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(EPTheme.primary.opacity(0.08))
                    .clipShape(Capsule())
            }

            Button(action: assign) {
                Label("指派這組", systemImage: "paperplane.fill")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(PrimaryActionButtonStyle())
        }
        .padding(12)
        .background(Color(.systemGray6))
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
                .background(isSelected ? EPTheme.primary : Color(.systemGray6))
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
        }
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
