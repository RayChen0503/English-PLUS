import SwiftUI

struct PracticeCenterView: View {
    @EnvironmentObject private var learningRepository: MockLearningRepository

    private let questionBankItems = SeedData.approvedQuestionBankItems

    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("自由練習")
                                .font(.headline)
                            Text("這裡可以直接進入，不會等待心情檢測，也不會改變今日任務進度。")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }

                    Section("題型") {
                        ForEach(QuestionType.allCases) { type in
                            HStack {
                                Label(type.title, systemImage: "checkmark.circle")
                                Spacer()
                                Text(countText(for: type))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Section("今日可先試做") {
                        ForEach(freePracticeItems) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.question.prompt)
                                    .fixedSize(horizontal: false, vertical: true)
                                HStack(spacing: 8) {
                                    Text(item.level.uiTitle)
                                    Text(item.question.type.title)
                                    Text(item.skill)
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("練習中心")
        }
    }

    private func count(for type: QuestionType) -> Int {
        questionBankItems.filter { $0.question.type == type }.count
    }

    private func countText(for type: QuestionType) -> String {
        let total = count(for: type)
        return total == 0 ? "待擴充" : "\(total) 題"
    }

    private var freePracticeItems: [QuestionBankItem] {
        if let currentType = learningRepository.currentCheckIn?.preferredQuestionTypes.first {
            let preferredItems = questionBankItems.filter { $0.question.type == currentType }
            if !preferredItems.isEmpty {
                return Array(preferredItems.prefix(5))
            }
        }
        return Array(questionBankItems.prefix(5))
    }
}
