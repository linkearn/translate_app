import SwiftUI

/// Cyberpunk color palette + reusable styling.
enum Cyber {
    static let bg      = Color(red: 0.03, green: 0.04, blue: 0.08)
    static let bg2     = Color(red: 0.06, green: 0.07, blue: 0.13)
    static let panel   = Color(red: 0.08, green: 0.10, blue: 0.17)
    static let stroke  = Color(red: 0.16, green: 0.22, blue: 0.34)
    static let cyan    = Color(red: 0.00, green: 0.92, blue: 1.00)
    static let magenta = Color(red: 1.00, green: 0.18, blue: 0.62)
    static let green   = Color(red: 0.20, green: 1.00, blue: 0.62)
    static let amber   = Color(red: 1.00, green: 0.78, blue: 0.25)
    static let text    = Color(red: 0.86, green: 0.95, blue: 1.00)
    static let dim     = Color(red: 0.48, green: 0.55, blue: 0.66)

    static let mono = Font.system(.body, design: .monospaced)
}

extension View {
    /// Neon outline + soft glow used across panels.
    func neonPanel(_ color: Color = Cyber.stroke, glow: Color? = nil, radius: CGFloat = 12) -> some View {
        self
            .background(Cyber.panel)
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(color, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: (glow ?? color).opacity(0.35), radius: 8, x: 0, y: 0)
    }

    func neonGlow(_ color: Color, radius: CGFloat = 6) -> some View {
        self.shadow(color: color.opacity(0.8), radius: radius)
            .shadow(color: color.opacity(0.4), radius: radius * 2)
    }
}

/// A glowing primary action button.
struct CyberButtonStyle: ButtonStyle {
    var tint: Color = Cyber.cyan
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .monospaced).weight(.semibold))
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .foregroundStyle(Cyber.bg)
            .background(
                LinearGradient(colors: [tint, tint.opacity(0.7)], startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .neonGlow(tint, radius: configuration.isPressed ? 2 : 8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// A subtle outlined chip button.
struct GhostButtonStyle: ButtonStyle {
    var tint: Color = Cyber.cyan
    var active: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.callout, design: .monospaced))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundStyle(active ? Cyber.bg : tint)
            .background(active ? tint : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(tint.opacity(active ? 0 : 0.7), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
