import SwiftUI

enum StudioTheme {
    static let ink = Color(red: 0.035, green: 0.047, blue: 0.070)
    static let panel = Color(red: 0.075, green: 0.090, blue: 0.120)
    static let panelRaised = Color(red: 0.105, green: 0.125, blue: 0.165)
    static let cyan = Color(red: 0.18, green: 0.82, blue: 0.92)
    static let lime = Color(red: 0.60, green: 0.95, blue: 0.58)
    static let amber = Color(red: 1.0, green: 0.68, blue: 0.22)
    static let violet = Color(red: 0.49, green: 0.40, blue: 0.95)
    static let magenta = Color(red: 0.92, green: 0.40, blue: 0.82)

    /// Marken-Verlauf (Cyan → Violett) – für primäre CTAs und Hero-Akzente.
    static var brandGradient: LinearGradient {
        LinearGradient(colors: [cyan, violet],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Breiter Hero-Verlauf (Cyan → Violett → Magenta) – für große Zahlen/Titel.
    static var heroGradient: LinearGradient {
        LinearGradient(colors: [cyan, violet, magenta],
                       startPoint: .leading, endPoint: .trailing)
    }

    static func accentGradient(_ accent: Color) -> LinearGradient {
        LinearGradient(colors: [accent.opacity(0.95), accent.opacity(0.55)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

struct StudioBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [StudioTheme.ink, Color.black.opacity(0.92)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [StudioTheme.cyan.opacity(0.18), .clear],
                           center: .topTrailing, startRadius: 20, endRadius: 560)
            RadialGradient(colors: [StudioTheme.violet.opacity(0.16), .clear],
                           center: .bottomLeading, startRadius: 20, endRadius: 560)
            RadialGradient(colors: [StudioTheme.magenta.opacity(0.06), .clear],
                           center: .center, startRadius: 60, endRadius: 480)
        }
        .ignoresSafeArea()
    }
}

struct StudioPanel: ViewModifier {
    var cornerRadius: CGFloat = 18
    var accent: Color = StudioTheme.cyan

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(StudioTheme.panel.opacity(0.80))
                    .overlay(alignment: .top) {
                        LinearGradient(colors: [accent.opacity(0.45), .clear],
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(height: 1.5)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.10))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            )
            .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 12)
    }
}

/// Hervorgehobene „Held"-Karte (wie der Popular-Tarif in modernen Pricing-UIs):
/// 2px-Verlaufsrand und stärkerer Schein.
struct StudioFeaturedPanel: ViewModifier {
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(StudioTheme.panelRaised.opacity(0.82))
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(StudioTheme.brandGradient, lineWidth: 2)
            }
            .shadow(color: StudioTheme.violet.opacity(0.28), radius: 26, x: 0, y: 14)
    }
}

extension View {
    func studioPanel(cornerRadius: CGFloat = 18, accent: Color = StudioTheme.cyan) -> some View {
        modifier(StudioPanel(cornerRadius: cornerRadius, accent: accent))
    }

    func studioFeaturedPanel(cornerRadius: CGFloat = 20) -> some View {
        modifier(StudioFeaturedPanel(cornerRadius: cornerRadius))
    }
}

/// Primärer CTA im Marken-Verlauf (gefüllt, weiße Schrift) – wie der
/// hervorgehobene Button auf dem Popular-Tarif.
struct StudioPrimaryButtonStyle: ButtonStyle {
    var gradient: LinearGradient = StudioTheme.brandGradient

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 10)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(gradient)
                    .opacity(configuration.isPressed ? 0.82 : 1)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18))
            }
            .shadow(color: StudioTheme.cyan.opacity(0.30), radius: 12, x: 0, y: 6)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Schlanker Verlaufs-Fortschrittsbalken (statt grauem Standard-ProgressView).
struct StudioProgressBar: View {
    var value: Double
    var gradient: LinearGradient = StudioTheme.brandGradient
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(gradient)
                    .frame(width: max(0, min(1, value)) * geo.size.width)
            }
        }
        .frame(height: height)
    }
}

/// Große, verlaufsgefüllte Kennzahl – „die Zahl ist der Held" (wie der Preis
/// in modernen Pricing-Layouts).
struct StudioStatNumber: View {
    let value: String
    var gradient: LinearGradient = StudioTheme.heroGradient

    var body: some View {
        Text(value)
            .font(.system(size: 30, weight: .bold, design: .rounded))
            .foregroundStyle(gradient)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }
}
