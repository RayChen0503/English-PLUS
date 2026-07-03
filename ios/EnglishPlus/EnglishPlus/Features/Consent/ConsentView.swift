import SwiftUI

struct ConsentView: View {
    @EnvironmentObject private var appState: AppState
    let role: UserRole

    @State private var acceptsPrivacy = false
    @State private var acceptsMoodAndAi = false

    private var canContinue: Bool {
        acceptsPrivacy && acceptsMoodAndAi
    }

    var body: some View {
        ZStack {
            EPTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Button {
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
                        Text("請先確認 English+ 如何使用資料，再進入\(role.title)端。")
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        ConsentToggle(
                            title: "學習與協助資料",
                            text: PrivacyPolicyCopy.primaryAgreement,
                            isOn: $acceptsPrivacy
                        )
                        Divider()
                        ConsentToggle(
                            title: "心情檢測與 AI 建議",
                            text: PrivacyPolicyCopy.moodAndAiAgreement,
                            isOn: $acceptsMoodAndAi
                        )
                    }
                    .padding(16)
                    .background(EPTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))

                    Text(PrivacyPolicyCopy.refusalPath)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button("我了解並繼續") {
                        appState.acceptPrivacyConsent(categories: PrivacyConsentCategory.allCases)
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(!canContinue)
                    .opacity(canContinue ? 1 : 0.45)
                }
                .padding(EPTheme.pagePadding)
            }
        }
    }
}

private struct ConsentToggle: View {
    let title: String
    let text: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: isOn ? "checkmark.square.fill" : "square")
                        .foregroundStyle(isOn ? EPTheme.primary : .secondary)
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(EPTheme.ink)
                }
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .buttonStyle(.plain)
    }
}
