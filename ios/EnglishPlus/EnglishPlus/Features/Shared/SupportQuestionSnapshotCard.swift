import SwiftUI

struct SupportQuestionSnapshotCard: View {
    let snapshot: SupportQuestionSnapshot
    var title: String = "學生卡住的題目"
    var showsExplanation: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: "doc.text.magnifyingglass")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)

            HStack(spacing: 8) {
                snapshotTag(snapshot.questionTypeTitle)
                snapshotTag(snapshot.levelTitle)
                if !snapshot.skill.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    snapshotTag(snapshot.skill)
                }
            }

            Text(snapshot.prompt)
                .font(.subheadline.bold())
                .foregroundStyle(EPTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            if !snapshot.options.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(snapshot.options, id: \.self) { option in
                        optionRow(option)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                answerRow(title: "學生答案", value: snapshot.selectedAnswerText, color: EPTheme.warning)
                answerRow(title: "正確答案", value: snapshot.correctAnswer, color: EPTheme.support)
            }

            if showsExplanation {
                VStack(alignment: .leading, spacing: 6) {
                    Text("解析")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(snapshot.explanation)
                        .font(.footnote)
                        .foregroundStyle(EPTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("下一步")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(snapshot.repairHint)
                        .font(.footnote)
                        .foregroundStyle(EPTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private func snapshotTag(_ text: String) -> some View {
        Text(text)
            .font(.caption.bold())
            .foregroundStyle(EPTheme.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func optionRow(_ option: String) -> some View {
        let isSelected = option == snapshot.selectedAnswer
        let isCorrect = option == snapshot.correctAnswer
        return HStack(spacing: 8) {
            Image(systemName: isCorrect ? "checkmark.circle.fill" : isSelected ? "xmark.circle.fill" : "circle")
                .foregroundStyle(isCorrect ? EPTheme.support : isSelected ? EPTheme.warning : .secondary)
            Text(option)
                .font(.footnote)
                .foregroundStyle(EPTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(8)
        .background(isCorrect ? EPTheme.support.opacity(0.10) : isSelected ? EPTheme.warning.opacity(0.10) : .white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func answerRow(title: String, value: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(color)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }
}
