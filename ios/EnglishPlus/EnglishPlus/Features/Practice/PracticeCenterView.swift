import SwiftUI

struct PracticeCenterView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                List {
                    Section("題型") {
                        ForEach(QuestionType.allCases) { type in
                            Label(type.title, systemImage: "checkmark.circle")
                        }
                    }

                    Section("今日可先試做") {
                        ForEach(SeedData.starterQuestions) { question in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(question.prompt)
                                Text(question.difficulty)
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
}
