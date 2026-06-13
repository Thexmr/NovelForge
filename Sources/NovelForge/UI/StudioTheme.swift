import SwiftUI

/// „Liquid Glass" / Glassmorphism-Design: warmer, neutraler Hintergrund und
/// milchig-transparente Frosted-Controls mit weichem Licht-Bloom darunter,
/// zarter Oberkante und feinem Rand. Großzügig, ruhig, übersichtlich.
enum StudioTheme {
    // Warme, neutrale Grundflächen (Taupe/Beige)
    static let pageTop = Color(red: 0.91, green: 0.885, blue: 0.84)
    static let pageBottom = Color(red: 0.80, green: 0.765, blue: 0.71)

    // Dezente Akzente (Verläufe & Badges)
    static let cyan = Color(red: 0.20, green: 0.58, blue: 0.86)
    static let violet = Color(red: 0.46, green: 0.40, blue: 0.82)
    static let magenta = Color(red: 0.80, green: 0.40, blue: 0.66)
    static let lime = Color(red: 0.32, green: 0.62, blue: 0.46)
    static let amber = Color(red: 0.86, green: 0.62, blue: 0.28)

    static var brandGradient: LinearGradient {
        LinearGradient(colors: [cyan, violet],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var heroGradient: LinearGradient {
        LinearGradient(colors: [cyan, violet, magenta],
                       startPoint: .leading, endPoint: .trailing)
    }

    static func accentGradient(_ accent: Color) -> LinearGradient {
        LinearGradient(colors: [accent, accent.opacity(0.6)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Zarte Oberkanten-Lichtkante + feiner Glasrand für eine Frosted-Form.
    @ViewBuilder
    static func glassEdge(_ cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.12)],
                               startPoint: .top, endPoint: .bottom),
                lineWidth: 1
            )
    }
}

/// Warmer, weicher Hintergrund mit dezenten Lichthöfen – die Bühne für das Glas.
struct StudioBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [StudioTheme.pageTop, StudioTheme.pageBottom],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Color.white.opacity(0.30), .clear],
                           center: .top, startRadius: 10, endRadius: 540)
            RadialGradient(colors: [StudioTheme.amber.opacity(0.10), .clear],
                           center: .bottomTrailing, startRadius: 20, endRadius: 560)
        }
        .ignoresSafeArea()
    }
}

/// Frosted-Glas-Fläche mit Licht-Bloom darunter (wie die Buttons der Referenz).
private struct GlassSurface: ViewModifier {
    var cornerRadius: CGFloat
    var bloom: CGFloat // Stärke des Licht-Booms darunter
    var tint: Color?

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill((tint ?? .white).opacity(tint == nil ? 0.12 : 0.18))
                    )
                    .overlay(alignment: .top) {
                        LinearGradient(colors: [.white.opacity(0.55), .clear],
                                       startPoint: .top, endPoint: .bottom)
                            .frame(height: cornerRadius * 1.4)
                            .blur(radius: 3)
                            .mask(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    }
            )
            .overlay { StudioTheme.glassEdge(cornerRadius) }
            // Tiefe …
            .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 12)
            // … und der helle Bloom unter dem Glas.
            .shadow(color: Color.white.opacity(0.55 * bloom), radius: 16 * bloom, x: 0, y: 10)
    }
}

private extension View {
    func glassSurface(cornerRadius: CGFloat, bloom: CGFloat = 1, tint: Color? = nil) -> some View {
        modifier(GlassSurface(cornerRadius: cornerRadius, bloom: bloom, tint: tint))
    }
}

struct StudioPanel: ViewModifier {
    var cornerRadius: CGFloat = 20
    var accent: Color = StudioTheme.cyan

    func body(content: Content) -> some View {
        content.glassSurface(cornerRadius: cornerRadius, bloom: 0.8)
    }
}

/// Hervorgehobene „Held"-Karte: stärkerer Bloom + zarter Marken-Schimmer.
struct StudioFeaturedPanel: ViewModifier {
    var cornerRadius: CGFloat = 22

    func body(content: Content) -> some View {
        content
            .glassSurface(cornerRadius: cornerRadius, bloom: 1.3, tint: StudioTheme.violet)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(StudioTheme.brandGradient.opacity(0.55), lineWidth: 1.5)
            }
    }
}

extension View {
    func studioPanel(cornerRadius: CGFloat = 20, accent: Color = StudioTheme.cyan) -> some View {
        modifier(StudioPanel(cornerRadius: cornerRadius, accent: accent))
    }

    func studioFeaturedPanel(cornerRadius: CGFloat = 22) -> some View {
        modifier(StudioFeaturedPanel(cornerRadius: cornerRadius))
    }
}

/// Primärer CTA als helles Frosted-Glas mit kräftigem Bloom und fetter Schrift.
struct StudioPrimaryButtonStyle: ButtonStyle {
    var gradient: LinearGradient = StudioTheme.brandGradient

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.vertical, 13)
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity)
            .glassSurface(cornerRadius: 16, bloom: configuration.isPressed ? 0.6 : 1.4, tint: .white)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Schlanker Fortschrittsbalken im Glas-Look.
struct StudioProgressBar: View {
    var value: Double
    var gradient: LinearGradient = StudioTheme.brandGradient
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.ultraThinMaterial)
                Capsule().fill(Color.black.opacity(0.06))
                Capsule()
                    .fill(gradient)
                    .frame(width: max(0, min(1, value)) * geo.size.width)
                    .shadow(color: StudioTheme.violet.opacity(0.4), radius: 4, y: 1)
            }
            .overlay { Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 1) }
        }
        .frame(height: height)
    }
}

/// Große Kennzahl – auf dem warmen Glas-Hintergrund kräftig, aber elegant.
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

/// Frosted-Glas Pill-Umschalter (wie Dropdown/Tabs in der Referenz).
struct StudioSegmentedPills: View {
    let options: [String]
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                let active = option == selection
                Text(option)
                    .font(.subheadline.weight(.semibold))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background {
                        if active {
                            Capsule().fill(.ultraThinMaterial)
                                .overlay(Capsule().fill(Color.white.opacity(0.25)))
                                .overlay(Capsule().strokeBorder(Color.white.opacity(0.5), lineWidth: 1))
                                .shadow(color: .white.opacity(0.5), radius: 8, y: 4)
                        }
                    }
                    .foregroundStyle(active ? Color.primary : Color.secondary)
                    .contentShape(Capsule())
                    .onTapGesture { selection = option }
            }
        }
        .padding(5)
        .background(Capsule().fill(Color.black.opacity(0.05)))
    }
}
