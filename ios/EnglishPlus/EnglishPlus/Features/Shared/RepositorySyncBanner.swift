import SwiftUI

struct RepositorySyncBanner: View {
    let status: LearningRepositorySyncStatus
    let lastSuccessfulSyncAt: Date?
    let onRetry: () -> Void

    var body: some View {
        if let presentation {
            HStack(spacing: 10) {
                Image(systemName: presentation.systemImage)
                    .foregroundStyle(presentation.tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text(presentation.title)
                        .font(.caption.bold())
                        .foregroundStyle(EPTheme.ink)
                    Text(presentation.detail)
                        .font(.caption2)
                        .foregroundStyle(EPTheme.secondaryInk)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                if presentation.showsRetry {
                    Button("重試", action: onRetry)
                        .font(.caption.bold())
                        .buttonStyle(.bordered)
                        .tint(EPTheme.primary)
                        .accessibilityHint("重新連線並同步最新資料")
                } else if presentation.showsProgress {
                    ProgressView()
                        .controlSize(.small)
                        .tint(EPTheme.primary)
                        .accessibilityLabel("正在同步")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(EPTheme.elevatedCard)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(EPTheme.hairline)
                    .frame(height: 1)
            }
            .accessibilityElement(children: .contain)
        }
    }

    private var presentation: SyncBannerPresentation? {
        switch status {
        case .idle, .listening:
            return nil
        case .connecting:
            return SyncBannerPresentation(
                title: "正在同步最新資料",
                detail: "已儲存的內容仍可使用。",
                systemImage: "arrow.triangle.2.circlepath",
                tint: EPTheme.primary,
                showsRetry: false,
                showsProgress: true
            )
        case .retrying(_, let attempt):
            return SyncBannerPresentation(
                title: "正在重新連線",
                detail: "第 \(attempt) 次嘗試，畫面會保留目前資料。",
                systemImage: "arrow.clockwise",
                tint: EPTheme.primary,
                showsRetry: false,
                showsProgress: true
            )
        case .offlineFallback(let reason):
            let lastSyncText = lastSuccessfulSyncAt.map {
                "上次同步：\($0.formatted(date: .omitted, time: .shortened))"
            } ?? "尚未完成第一次同步"
            return SyncBannerPresentation(
                title: "目前為離線模式",
                detail: "\(reason) \(lastSyncText)",
                systemImage: "wifi.slash",
                tint: EPTheme.warning,
                showsRetry: true,
                showsProgress: false
            )
        }
    }
}

private struct SyncBannerPresentation {
    let title: String
    let detail: String
    let systemImage: String
    let tint: Color
    let showsRetry: Bool
    let showsProgress: Bool
}
