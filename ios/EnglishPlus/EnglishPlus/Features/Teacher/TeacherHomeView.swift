import SwiftUI

struct TeacherHomeView: View {
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
                            ForEach(learningRepository.teacherQueue.prefix(3)) { request in
                                TeacherRequestCard(request: request)
                            }
                        }

                        TeacherClassSummary()
                    }
                    .padding(EPTheme.pagePadding)
                }
            }
            .navigationTitle("教師工作台")
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

struct TeacherRequestsView: View {
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("待回應求助")
                            .font(.title.bold())
                            .foregroundStyle(EPTheme.ink)
                        ForEach(learningRepository.teacherQueue) { request in
                            TeacherRequestCard(request: request)
                        }
                    }
                    .padding(EPTheme.pagePadding)
                }
            }
            .navigationTitle("求助")
        }
    }
}

private struct TeacherStatusStrip: View {
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

    var body: some View {
        HStack(spacing: 10) {
            TeacherStatusTile(
                title: "高風險",
                value: "\(learningRepository.teacherQueue.filter { $0.priority == .high }.count)",
                color: EPTheme.warning
            )
            TeacherStatusTile(
                title: "待回應",
                value: "\(learningRepository.teacherQueue.count)",
                color: EPTheme.primary
            )
            TeacherStatusTile(
                title: "已回覆",
                value: "\(learningRepository.supportRequests.filter { $0.status == .replied }.count)",
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
    @EnvironmentObject private var learningRepository: LearningRepositoryStore
    let request: StudentSupportRequest

    @State private var replyDraft = ""

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
