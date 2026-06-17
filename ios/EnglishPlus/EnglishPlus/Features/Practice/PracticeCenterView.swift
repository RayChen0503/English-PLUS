import SwiftUI

struct PracticeCenterView: View {
    private let questionBankItems = SeedData.approvedQuestionBankItems

    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                List {
                    Section("題型") {
                        ForEach(QuestionType.allCases) { type in
                            HStack {
                                Label(type.title, systemImage: "checkmark.circle")
                                Spacer()
                                Text("\(count(for: type)) 題")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Section("今日可先試做") {
                        ForEach(questionBankItems.prefix(5)) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.question.prompt)
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
}
