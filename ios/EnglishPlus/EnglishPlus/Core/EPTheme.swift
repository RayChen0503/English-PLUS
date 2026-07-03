import SwiftUI
import UIKit

enum EPTheme {
    static let background = adaptiveColor(
        light: UIColor(red: 0.97, green: 0.98, blue: 0.96, alpha: 1),
        dark: UIColor(red: 0.04, green: 0.07, blue: 0.08, alpha: 1)
    )
    static let card = adaptiveColor(
        light: .white,
        dark: UIColor(red: 0.09, green: 0.13, blue: 0.15, alpha: 1)
    )
    static let secondarySurface = adaptiveColor(
        light: UIColor(red: 0.94, green: 0.96, blue: 0.95, alpha: 1),
        dark: UIColor(red: 0.13, green: 0.18, blue: 0.20, alpha: 1)
    )
    static let ink = adaptiveColor(
        light: UIColor(red: 0.12, green: 0.16, blue: 0.20, alpha: 1),
        dark: UIColor(red: 0.92, green: 0.96, blue: 0.94, alpha: 1)
    )
    static let secondaryInk = adaptiveColor(
        light: UIColor(red: 0.39, green: 0.45, blue: 0.50, alpha: 1),
        dark: UIColor(red: 0.68, green: 0.75, blue: 0.78, alpha: 1)
    )
    static let primary = adaptiveColor(
        light: UIColor(red: 0.12, green: 0.46, blue: 0.82, alpha: 1),
        dark: UIColor(red: 0.39, green: 0.70, blue: 1.00, alpha: 1)
    )
    static let support = adaptiveColor(
        light: UIColor(red: 0.11, green: 0.55, blue: 0.48, alpha: 1),
        dark: UIColor(red: 0.30, green: 0.83, blue: 0.74, alpha: 1)
    )
    static let warning = adaptiveColor(
        light: UIColor(red: 0.84, green: 0.45, blue: 0.14, alpha: 1),
        dark: UIColor(red: 1.00, green: 0.67, blue: 0.34, alpha: 1)
    )

    static let pagePadding: CGFloat = 20
    static let cardRadius: CGFloat = 8

    private static func adaptiveColor(light: UIColor, dark: UIColor) -> Color {
        Color(
            UIColor { traits in
                traits.userInterfaceStyle == .dark ? dark : light
            }
        )
    }
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
