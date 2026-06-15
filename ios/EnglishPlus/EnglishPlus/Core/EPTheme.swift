import SwiftUI

enum EPTheme {
    static let background = Color(red: 0.97, green: 0.98, blue: 0.96)
    static let ink = Color(red: 0.12, green: 0.16, blue: 0.20)
    static let primary = Color(red: 0.12, green: 0.46, blue: 0.82)
    static let support = Color(red: 0.11, green: 0.55, blue: 0.48)
    static let warning = Color(red: 0.84, green: 0.45, blue: 0.14)

    static let pagePadding: CGFloat = 20
    static let cardRadius: CGFloat = 8
}

struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .background(configuration.isPressed ? EPTheme.primary.opacity(0.78) : EPTheme.primary)
            .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}
