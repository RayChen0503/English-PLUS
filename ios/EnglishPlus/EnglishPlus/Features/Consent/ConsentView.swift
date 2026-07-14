import SwiftUI

struct ConsentView: View {
    @EnvironmentObject private var appState: AppState
    let role: UserRole

    @State private var acceptsPrivacy = false
    @State private var acceptsMoodAndAi = false
    @State private var confirmsGuardianContext = false
    @State private var sharesStabilityDiagnostics = false

    private var canContinue: Bool {
        acceptsPrivacy
            && acceptsMoodAndAi
            && (role != .student || confirmsGuardianContext)
    }

    var body: some View {
        ZStack {
            EPTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Button {
                        guard !appState.isSavingConsent else { return }
                        appState.signOut()
                    } label: {
                        Label("返回", systemImage: "chevron.left")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(EPTheme.primary)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("資料使用確認")
                            .font(.largeTitle.bold())
                            .foregroundStyle(EPTheme.ink)
                        Text("先用一分鐘確認資料如何使用，再進入\(role.title)端。這次同意對應 \(LegalSupportConfiguration.policyEffectiveDate) 生效的政策。")
                            .foregroundStyle(EPTheme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        ConsentSummaryRow(
                            icon: "lock.shield",
                            title: "只為帳號與學習功能",
                            detail: "不出售資料，也不做跨 App 或網站的廣告追蹤。"
                        )
                        ConsentSummaryRow(
                            icon: "person.2",
                            title: "真人協助由你決定",
                            detail: "學生主動送出後，獲授權的老師或志工才會看到求助。"
                        )
                        ConsentSummaryRow(
                            icon: "trash",
                            title: "可在 App 內刪除帳號",
                            detail: "可識別個人的帳號、學習、支持與證明資料會依流程清除。"
                        )
                    }
                    .padding(16)
                    .background(EPTheme.secondarySurface)
                    .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))

                    VStack(alignment: .leading, spacing: 14) {
                        ConsentToggle(
                            title: "帳號與服務資料",
                            text: PrivacyPolicyCopy.primaryAgreement(for: role),
                            accessibilityIdentifier: "consent.privacy",
                            isOn: $acceptsPrivacy
                        )
                        Divider()
                        ConsentToggle(
                            title: "第三方 AI 處理",
                            text: PrivacyPolicyCopy.aiAgreement(for: role),
                            accessibilityIdentifier: "consent.ai",
                            isOn: $acceptsMoodAndAi
                        )

                        if role == .student {
                            Divider()
                            ConsentToggle(
                                title: "未成年人使用確認",
                                text: PrivacyPolicyCopy.guardianAgreement,
                                accessibilityIdentifier: "consent.guardian",
                                isOn: $confirmsGuardianContext
                            )
                        }
                    }
                    .padding(16)
                    .background(EPTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))

                    ConsentToggle(
                        title: "選用：當機與穩定性診斷",
                        text: "協助修復閃退與同步失敗；只傳送 App 版本、角色、所在流程與錯誤類別，不傳姓名、Email、題目、心情分數或班級名稱。未開啟也能完整使用。",
                        accessibilityIdentifier: "consent.diagnostics",
                        isOn: $sharesStabilityDiagnostics
                    )
                    .padding(16)
                    .background(EPTheme.secondarySurface)
                    .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))

                    Text(PrivacyPolicyCopy.refusalPath)
                        .font(.footnote)
                        .foregroundStyle(EPTheme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)

                    Label(PrivacyPolicyCopy.aiAccuracyNotice, systemImage: "exclamationmark.bubble")
                        .font(.footnote)
                        .foregroundStyle(EPTheme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)

                    PrivacySupportLinks(role: role)

                    if let message = appState.consentErrorMessage {
                        Label(message, systemImage: "wifi.exclamationmark")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(EPTheme.danger)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(EPTheme.danger.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
                    }

                    Button {
                        Task {
                            await appState.acceptPrivacyConsent(
                                categories: PrivacyPolicyCopy.requiredCategories(for: role),
                                guardianConsentStatus: role == .student ? .received : .notRequired
                            )
                            if case .home = appState.route {
                                AppDiagnostics.shared.setCollectionEnabled(sharesStabilityDiagnostics)
                            }
                        }
                    } label: {
                        if appState.isSavingConsent {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("正在保存...")
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                        } else {
                            Text("我了解並繼續")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(!canContinue || appState.isSavingConsent)
                    .opacity(canContinue && !appState.isSavingConsent ? 1 : 0.45)
                    .accessibilityIdentifier("consent.continue")
                }
                .padding(EPTheme.pagePadding)
            }
        }
    }
}

struct PrivacySupportLinks: View {
    let role: UserRole?

    init(role: UserRole? = nil) {
        self.role = role
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Link(destination: LegalSupportConfiguration.privacyPolicyURL) {
                PrivacySupportLinkLabel(
                    title: "閱讀完整隱私政策",
                    systemImage: "doc.text"
                )
            }

            Link(destination: LegalSupportConfiguration.supportURL) {
                PrivacySupportLinkLabel(
                    title: "支援與聯絡",
                    systemImage: "questionmark.circle"
                )
            }

            Link(destination: LegalSupportConfiguration.supportEmailURL(role: role)) {
                PrivacySupportLinkLabel(
                    title: LegalSupportConfiguration.supportEmail,
                    systemImage: "envelope"
                )
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(EPTheme.primary)
    }
}

private struct PrivacySupportLinkLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .frame(width: 24)
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer(minLength: 8)
            Image(systemName: "arrow.up.right")
                .font(.caption.bold())
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private struct ConsentSummaryRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(EPTheme.primary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(EPTheme.ink)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(EPTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct ConsentToggle: View {
    let title: String
    let text: String
    let accessibilityIdentifier: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: isOn ? "checkmark.square.fill" : "square")
                        .foregroundStyle(isOn ? EPTheme.primary : EPTheme.secondaryInk)
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(EPTheme.ink)
                }
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(EPTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityValue(isOn ? "已同意" : "未同意")
    }
}
