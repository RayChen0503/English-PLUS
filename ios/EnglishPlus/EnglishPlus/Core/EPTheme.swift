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
    static let elevatedCard = adaptiveColor(
        light: UIColor(red: 0.99, green: 1.00, blue: 0.98, alpha: 1),
        dark: UIColor(red: 0.12, green: 0.17, blue: 0.19, alpha: 1)
    )
    static let buttonSecondarySurface = adaptiveColor(
        light: UIColor(red: 0.91, green: 0.95, blue: 0.95, alpha: 1),
        dark: UIColor(red: 0.17, green: 0.24, blue: 0.27, alpha: 1)
    )
    static let ink = adaptiveColor(
        light: UIColor(red: 0.12, green: 0.16, blue: 0.20, alpha: 1),
        dark: UIColor(red: 0.92, green: 0.96, blue: 0.94, alpha: 1)
    )
    static let secondaryInk = adaptiveColor(
        light: UIColor(red: 0.39, green: 0.45, blue: 0.50, alpha: 1),
        dark: UIColor(red: 0.68, green: 0.75, blue: 0.78, alpha: 1)
    )
    static let mutedInk = adaptiveColor(
        light: UIColor(red: 0.51, green: 0.57, blue: 0.62, alpha: 1),
        dark: UIColor(red: 0.53, green: 0.60, blue: 0.64, alpha: 1)
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
    static let danger = adaptiveColor(
        light: UIColor(red: 0.82, green: 0.20, blue: 0.20, alpha: 1),
        dark: UIColor(red: 1.00, green: 0.46, blue: 0.46, alpha: 1)
    )
    static let hairline = adaptiveColor(
        light: UIColor(red: 0.84, green: 0.88, blue: 0.86, alpha: 1),
        dark: UIColor(red: 0.24, green: 0.31, blue: 0.34, alpha: 1)
    )
    static let disabledSurface = adaptiveColor(
        light: UIColor(red: 0.88, green: 0.91, blue: 0.90, alpha: 1),
        dark: UIColor(red: 0.16, green: 0.20, blue: 0.22, alpha: 1)
    )
    static let disabledInk = adaptiveColor(
        light: UIColor(red: 0.57, green: 0.62, blue: 0.64, alpha: 1),
        dark: UIColor(red: 0.40, green: 0.47, blue: 0.50, alpha: 1)
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
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .background(isEnabled ? (configuration.isPressed ? EPTheme.primary.opacity(0.78) : EPTheme.primary) : EPTheme.disabledSurface)
            .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(isEnabled ? EPTheme.primary : EPTheme.disabledInk)
            .background(isEnabled ? (configuration.isPressed ? EPTheme.primary.opacity(0.16) : EPTheme.buttonSecondarySurface) : EPTheme.disabledSurface)
            .overlay(
                RoundedRectangle(cornerRadius: EPTheme.cardRadius)
                    .stroke(isEnabled ? EPTheme.primary.opacity(0.35) : EPTheme.hairline, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}
