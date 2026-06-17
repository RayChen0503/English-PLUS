import SwiftUI

struct VolunteerHomeView: View {
    @EnvironmentObject private var learningRepository: MockLearningRepository

    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("今日接力任務")
                            .font(.title.bold())
                            .foregroundStyle(EPTheme.ink)

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

                        ForEach(learningRepository.volunteerQueue.prefix(3)) { request in
                            VolunteerTaskCard(request: request)
                        }
                    }
                    .padding(EPTheme.pagePadding)
                }
            }
            .navigationTitle("志工工作台")
        }
    }
}

struct VolunteerWaitingView: View {
    @EnvironmentObject private var learningRepository: MockLearningRepository

    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("等待陪伴")
                            .font(.title.bold())
                            .foregroundStyle(EPTheme.ink)
                        ForEach(learningRepository.volunteerQueue) { request in
                            VolunteerTaskCard(request: request)
                        }
                    }
                    .padding(EPTheme.pagePadding)
                }
            }
            .navigationTitle("學生")
        }
    }
}

struct VolunteerRecordsView: View {
    @EnvironmentObject private var learningRepository: MockLearningRepository

    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                List {
                    ForEach(learningRepository.supportRequests.filter { !$0.replies.isEmpty }) { request in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(request.studentName)
                                .font(.headline)
                            ForEach(request.replies.filter { $0.authorRole == .volunteer }) { reply in
                                Text(reply.body)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("回覆紀錄")
        }
    }
}

struct VolunteerTaskCard: View {
    @EnvironmentObject private var learningRepository: MockLearningRepository
    let request: StudentSupportRequest

    @State private var replyDraft = ""

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

            TextField("留下鼓勵或陪伴回覆", text: $replyDraft, axis: .vertical)
                .textFieldStyle(.roundedBorder)

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

    private var statusSummary: String {
        if let moodScore = request.moodScore {
            return "心情 \(moodScore)/5 · \(request.status.uiTitle)"
        }
        return request.status.uiTitle
    }
}
