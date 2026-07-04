import SwiftUI

struct StaffSupportQueueHeaderCard: View {
    let title: String
    let subtitle: String
    let waitingCount: Int
    let highPriorityCount: Int
    let handledCount: Int
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "bell.badge")
                    .font(.title3.bold())
                    .foregroundStyle(tint)
                    .frame(width: 40, height: 40)
                    .background(tint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(EPTheme.ink)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(EPTheme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if waitingCount > 0 {
                    Text("\(waitingCount)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .frame(minWidth: 28, minHeight: 28)
                        .padding(.horizontal, 2)
                        .background(EPTheme.warning)
                        .clipShape(Capsule())
                        .accessibilityLabel("未處理 \(waitingCount) 件")
                }
            }

            HStack(spacing: 10) {
                StaffSupportMetricPill(title: "未處理", value: "\(waitingCount)", tint: EPTheme.warning)
                StaffSupportMetricPill(title: "高優先", value: "\(highPriorityCount)", tint: EPTheme.primary)
                StaffSupportMetricPill(title: "已處理", value: "\(handledCount)", tint: EPTheme.support)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct StaffSupportMetricPill: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(EPTheme.secondaryInk)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(tint)
                .monospacedDigit()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct StaffSupportActionBar: View {
    let canReply: Bool
    let sendReply: () -> Void
    let archiveThread: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("處理這筆求助")
                .font(.subheadline.bold())
                .foregroundStyle(EPTheme.ink)

            Button(action: sendReply) {
                Label("送出回覆", systemImage: "paperplane.fill")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(!canReply)
            .opacity(canReply ? 1 : 0.45)

            Button(action: archiveThread) {
                Label("收起", systemImage: "archivebox")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(SecondaryActionButtonStyle())

            Text("收起只會從你的待辦移除，不會刪除學生資料；另一端仍可看見並選擇是否補充回覆。")
                .font(.caption)
                .foregroundStyle(EPTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(EPTheme.support.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
