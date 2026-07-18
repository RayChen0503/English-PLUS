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
                    Button("重試") {
                        AppDiagnostics.shared.log(.manualSyncRetry)
                        onRetry()
                    }
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
            .accessibilityLabel("\(presentation.title)。\(presentation.detail)")
            .accessibilityIdentifier("repository.sync.banner")
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private var presentation: SyncBannerPresentation? {
        switch status {
        case .idle, .connecting, .retrying, .listening, .syncIssue:
            return nil
        case .offlineFallback(let reason):
            let lastSyncText = lastSuccessfulSyncAt.map {
                "上次同步：\($0.formatted(date: .omitted, time: .shortened))"
            } ?? "尚未完成第一次同步"
            return SyncBannerPresentation(
                title: "目前為離線模式",
                detail: "\(reason) \(lastSyncText)",
                systemImage: "wifi.slash",
                tint: EPTheme.warning,
                showsRetry: false,
                showsProgress: false
            )
        }
    }
}

enum EPContentState {
    case loading(title: String, detail: String?)
    case empty(systemImage: String, title: String, detail: String)
    case failure(title: String, detail: String)
}

struct EPContentStateView: View {
    let state: EPContentState
    var retryTitle = "重試"
    var onRetry: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title2) private var symbolSize: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                stateSymbol
                    .frame(width: max(symbolSize, 44), height: max(symbolSize, 44))
                    .background(tint.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(EPTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if let detail, !detail.isEmpty {
                        Text(detail)
                            .font(.subheadline)
                            .foregroundStyle(EPTheme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if let onRetry {
                Button(retryTitle) {
                    onRetry()
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .accessibilityHint("重新載入這個區塊的最新資料")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(surface)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(accessibilityIdentifier)
        .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
    }

    @ViewBuilder
    private var stateSymbol: some View {
        switch state {
        case .loading:
            ProgressView()
                .tint(EPTheme.primary)
                .accessibilityHidden(true)
        case .empty(let systemImage, _, _):
            Image(systemName: systemImage)
                .font(.title3.bold())
                .foregroundStyle(tint)
                .accessibilityHidden(true)
        case .failure:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3.bold())
                .foregroundStyle(tint)
                .accessibilityHidden(true)
        }
    }

    private var title: String {
        switch state {
        case .loading(let value, _):
            return value
        case .empty(_, let value, _):
            return value
        case .failure(let value, _):
            return value
        }
    }

    private var detail: String? {
        switch state {
        case .loading(_, let value):
            return value
        case .empty(_, _, let value):
            return value
        case .failure(_, let value):
            return value
        }
    }

    private var tint: Color {
        switch state {
        case .loading: return EPTheme.primary
        case .empty: return EPTheme.support
        case .failure: return EPTheme.warning
        }
    }

    private var surface: Color {
        switch state {
        case .loading, .empty: return EPTheme.card
        case .failure: return EPTheme.warningSurface
        }
    }

    private var accessibilityIdentifier: String {
        switch state {
        case .loading: return "content.state.loading"
        case .empty: return "content.state.empty"
        case .failure: return "content.state.failure"
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
