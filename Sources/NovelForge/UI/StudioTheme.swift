import SwiftUI

/// Helles, luftiges „Studio"-Design im Stil moderner SaaS-/Pricing-Oberflächen:
/// weiche weiße Karten, großzügiger Weißraum, kräftige Verlaufs-Akzente nur auf
/// Hero-Elementen, große Zahlen. Dunkle Flächen gibt es bewusst nicht mehr.
enum StudioTheme {
    // Helle Grundflächen
    static let pageTop = Color(red: 0.975, green: 0.977, blue: 0.992)
    static let pageBottom = Color(red: 0.935, green: 0.945, blue: 0.975)
    static let card = Color.white
    static let hairline = Color.black.opacity(0.07)
    static let trackBg = Color.black.opacity(0.06)

    // Akzentfarben (für Verläufe & Badges) – auf Weiß abgestimmt
    static let cyan = Color(red: 0.10, green: 0.60, blue: 0.95)
    static let violet = Color(red: 0.45, green: 0.34, blue: 0.93)
    static let magenta = Color(red: 0.86, green: 0.31, blue: 0.71)
    static let lime = Color(red: 0.18, green: 0.70, blue: 0.45)
    static let amber = Color(red: 0.95, green: 0.62, blue: 0.10)

    /// Marken-Verlauf (Blau → Violett) – primäre CTAs und Hero-Akzente.
    static var brandGradient: LinearGradient {
        LinearGradient(colors: [cyan, violet],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Hero-Verlauf (Blau → Violett → Magenta) – große Zahlen/Titel.
    static var heroGradient: LinearGradient {
        LinearGradient(colors: [cyan, violet, magenta],
                       startPoint: .leading, endPoint: .trailing)
    }

    static func accentGradient(_ accent: Color) -> LinearGradient {
        LinearGradient(colors: [accent, accent.opacity(0.65)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// Heller, luftiger Hintergrund mit dezenten Farbblüten (wie die topografischen/
/// Aurora-Hintergründe der Referenzen, nur subtil).
struct StudioBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [StudioTheme.pageTop, StudioTheme.pageBottom],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [StudioTheme.cyan.opacity(0.10), .clear],
                           center: .topTrailing, startRadius: 20, endRadius: 620)
            RadialGradient(colors: [StudioTheme.violet.opacity(0.10), .clear],
                           center: .bottomLeading, startRadius: 20, endRadius: 620)
            RadialGradient(colors: [StudioTheme.magenta.opacity(0.05), .clear],
                           center: .center, startRadius: 80, endRadius: 520)
        }
        .ignoresSafeArea()
    }
}

/// Weiche weiße Karte mit zarter Kontur und dezentem Schatten.
struct StudioPanel: ViewModifier {
    var cornerRadius: CGFloat = 18
    var accent: Color = StudioTheme.cyan

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(StudioTheme.card)
                    .overlay(alignment: .top) {
                        LinearGradient(colors: [accent.opacity(0.65), .clear],
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(height: 2)
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    }
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(StudioTheme.hairline)
            }
            .shadow(color: Color.black.opacity(0.06), radius: 16, x: 0, y: 8)
    }
}

/// Hervorgehobene „Held"-Karte (wie der Popular-Tarif): 2px-Verlaufsrand,
/// weicher farbiger Schein.
struct StudioFeaturedPanel: ViewModifier {
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(StudioTheme.card)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(StudioTheme.brandGradient, lineWidth: 2)
            }
            .shadow(color: StudioTheme.violet.opacity(0.16), radius: 26, x: 0, y: 14)
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

/// Primärer CTA im Marken-Verlauf (gefüllt, weiße Schrift).
struct StudioPrimaryButtonStyle: ButtonStyle {
    var gradient: LinearGradient = StudioTheme.brandGradient

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 11)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(gradient)
                    .opacity(configuration.isPressed ? 0.85 : 1)
            )
            .shadow(color: StudioTheme.violet.opacity(0.30), radius: 12, x: 0, y: 6)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Schlanker Verlaufs-Fortschrittsbalken.
struct StudioProgressBar: View {
    var value: Double
    var gradient: LinearGradient = StudioTheme.brandGradient
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(StudioTheme.trackBg)
                Capsule()
                    .fill(gradient)
                    .frame(width: max(0, min(1, value)) * geo.size.width)
            }
        }
        .frame(height: height)
    }
}

/// Große, verlaufsgefüllte Kennzahl – „die Zahl ist der Held".
struct StudioStatNumber: View {
    let value: String
    var gradient: LinearGradient = StudioTheme.heroGradient

    var body: some View {
        Text(value)
            .font(.system(size: 32, weight: .bold, design: .rounded))
            .foregroundStyle(gradient)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }
}

/// Pill-Segment-Umschalter (wie Monatlich/Jährlich in den Referenzen).
struct StudioSegmentedPills: View {
    let options: [String]
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                let active = option == selection
                Text(option)
                    .font(.caption.weight(.semibold))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 14)
                    .background {
                        if active {
                            Capsule().fill(StudioTheme.brandGradient)
                        }
                    }
                    .foregroundStyle(active ? Color.white : Color.secondary)
                    .contentShape(Capsule())
                    .onTapGesture { selection = option }
            }
        }
        .padding(4)
        .background(Capsule().fill(StudioTheme.trackBg))
    }
}
