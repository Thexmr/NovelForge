import SwiftUI

/// Branding „Studio Noir": ein ruhiges, professionelles Schreibstudio (Linear/Craft-
/// Register). Tiefes, kühl-neutrales Anthrazit mit feinem Indigo-Unterton; EINE gedämpfte
/// Indigo/Blau-Signatur, Farbe sonst nur für Bedeutung. Tiefe entsteht durch Helligkeits-
/// Stufen + feine Kanten, nicht durch Glow. Premium durch Zurückhaltung.
enum StudioTheme {
    // Tiefes, kühl-neutrales Anthrazit mit feinem Indigo-Unterton (Helligkeits-Leiter).
    static let pageTop = Color(red: 0.062, green: 0.062, blue: 0.084)
    static let pageMiddle = Color(red: 0.082, green: 0.082, blue: 0.110)
    static let pageBottom = Color(red: 0.044, green: 0.044, blue: 0.062)

    static let surface = Color(red: 0.104, green: 0.104, blue: 0.136)
    static let surfaceElevated = Color(red: 0.142, green: 0.142, blue: 0.182)
    static let surfaceDeep = Color(red: 0.072, green: 0.072, blue: 0.098)
    static let glassBase = Color(red: 0.090, green: 0.090, blue: 0.120)
    static let glassInk = Color(red: 0.040, green: 0.040, blue: 0.058)
    static let hairline = Color.white.opacity(0.09)
    static let hairlineBright = Color.white.opacity(0.18)
    static let textMuted = Color.white.opacity(0.66)
    static let textFaint = Color.white.opacity(0.42)

    // EINE gedämpfte Indigo/Blau-Signatur; Akzente nur für Bedeutung (gedämpft).
    static let cyan = Color(red: 0.42, green: 0.60, blue: 0.95)    // gedämpftes Blau (sekundär)
    static let violet = Color(red: 0.56, green: 0.50, blue: 0.92)  // Indigo (primär)
    static let magenta = Color(red: 0.78, green: 0.52, blue: 0.74) // gedämpftes Mauve (selten)
    static let lime = Color(red: 0.36, green: 0.72, blue: 0.56)    // gedämpftes Grün (Erfolg)
    static let amber = Color(red: 0.85, green: 0.66, blue: 0.34)   // gedämpftes Amber (Warnung)
    static let danger = Color(red: 0.86, green: 0.40, blue: 0.44)  // gedämpftes Rot (Fehler)

    /// Signatur-Verlauf: Neon-Blau → Neon-Lila (durchgängig in der ganzen App).
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

    static var quietGradient: LinearGradient {
        LinearGradient(colors: [surfaceElevated.opacity(0.86), surface.opacity(0.52)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    @ViewBuilder
    static func glassEdge(_ cornerRadius: CGFloat, accent: Color = StudioTheme.cyan) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(colors: [
                    Color.white.opacity(0.54),
                    accent.opacity(0.34),
                    Color.white.opacity(0.08)
                ], startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 1
            )
    }
}

/// Ruhige, statische Atmosphäre statt zielloser Drift-Animation: zwei tiefe Neon-Halos
/// (Cyan oben, Violett rechts) + ein feines Punkt-Raster (futuristische HUD-Textur, nur
/// gefühlt). Bewegung ist dem aktiven Zustand vorbehalten, nicht dem Hintergrund.
struct StudioBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [StudioTheme.pageTop, StudioTheme.pageMiddle, StudioTheme.pageBottom],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [StudioTheme.cyan.opacity(0.15), .clear],
                           center: UnitPoint(x: 0.15, y: -0.05), startRadius: 40, endRadius: 760)
            RadialGradient(colors: [StudioTheme.violet.opacity(0.17), .clear],
                           center: UnitPoint(x: 0.92, y: 0.10), startRadius: 60, endRadius: 820)
            DotGrid()
            Rectangle().fill(.black.opacity(0.34))
        }
        .ignoresSafeArea()
    }
}

/// Feines Punkt-Raster (sub-perzeptuell), gibt dem Hintergrund einen „System"-Charakter.
struct DotGrid: View {
    var body: some View {
        Canvas { ctx, size in
            let step: CGFloat = 26
            let dot: CGFloat = 1.0
            let shading = GraphicsContext.Shading.color(.white.opacity(0.045))
            var y: CGFloat = step
            while y < size.height {
                var x: CGFloat = step
                while x < size.width {
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: dot, height: dot)), with: shading)
                    x += step
                }
                y += step
            }
        }
        .allowsHitTesting(false)
        .blendMode(.plusLighter)
    }
}

/// Bewegungs-Tokens für ein konsistentes Gefühl in der ganzen App.
enum Motion {
    static let fast = Animation.easeOut(duration: 0.12)
    static let standard = Animation.spring(response: 0.32, dampingFraction: 0.85)
    static let expressive = Animation.spring(response: 0.5, dampingFraction: 0.72)
}

extension View {
    /// Echter Neon-Glow als gestaffeltes Licht-Decay (mehrere Schatten, ~2× Radius je Stufe)
    /// statt eines einzelnen fetten Blurs. `intensity` skaliert die Stärke (0 = aus).
    func neonGlow(_ color: Color, intensity: Double = 1) -> some View {
        self
            .shadow(color: color.opacity(0.55 * intensity), radius: 4)
            .shadow(color: color.opacity(0.32 * intensity), radius: 11)
            .shadow(color: color.opacity(0.16 * intensity), radius: 22)
    }
}

private struct GlassSurface: ViewModifier {
    var cornerRadius: CGFloat
    var bloom: CGFloat
    var tint: Color?
    var accent: Color
    var isInteractiveGlass: Bool

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(StudioTheme.glassBase.opacity(isInteractiveGlass ? 0.36 : 0.44))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(colors: [
                                    Color.white.opacity(isInteractiveGlass ? 0.18 : 0.12),
                                    (tint ?? accent).opacity(isInteractiveGlass ? 0.08 : 0.055),
                                    StudioTheme.glassInk.opacity(isInteractiveGlass ? 0.30 : 0.34)
                                ], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(colors: [
                                    Color.white.opacity(0.08),
                                    Color.clear,
                                    StudioTheme.glassInk.opacity(isInteractiveGlass ? 0.34 : 0.38)
                                ], startPoint: .top, endPoint: .bottom)
                            )
                    )
                    .overlay(alignment: .top) {
                        LinearGradient(colors: [.white.opacity(0.42), .white.opacity(0.10), .clear],
                                       startPoint: .top, endPoint: .bottom)
                            .frame(height: max(18, cornerRadius * 1.8))
                            .mask(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    }
                    .overlay(alignment: .topLeading) {
                        RadialGradient(colors: [accent.opacity(isInteractiveGlass ? 0.26 : 0.16), .clear],
                                       center: .topLeading, startRadius: 8, endRadius: 240)
                            .mask(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    }
                    .overlay(alignment: .leading) {
                        LinearGradient(colors: [accent.opacity(isInteractiveGlass ? 0.20 : 0.12), .clear],
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(width: 96)
                            .mask(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    }
            )
            .overlay { StudioTheme.glassEdge(cornerRadius, accent: accent) }
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.09), lineWidth: 3)
                    .mask(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
            .shadow(color: Color.black.opacity(0.22), radius: isInteractiveGlass ? 9 : 5, x: 0, y: isInteractiveGlass ? 7 : 3)
            .shadow(color: accent.opacity(0.08 * Double(bloom)), radius: (isInteractiveGlass ? 11 : 7) * bloom, x: 0, y: 4)
    }
}

private extension View {
    func glassSurface(cornerRadius: CGFloat,
                      bloom: CGFloat = 1,
                      tint: Color? = nil,
                      accent: Color = StudioTheme.cyan,
                      isInteractiveGlass: Bool = false) -> some View {
        modifier(GlassSurface(cornerRadius: cornerRadius,
                              bloom: bloom,
                              tint: tint,
                              accent: accent,
                              isInteractiveGlass: isInteractiveGlass))
    }
}

struct StudioPanel: ViewModifier {
    var cornerRadius: CGFloat = 8
    var accent: Color = StudioTheme.cyan

    func body(content: Content) -> some View {
        content.glassSurface(cornerRadius: cornerRadius,
                             bloom: 0.45,
                             accent: accent,
                             isInteractiveGlass: false)
    }
}

struct StudioFeaturedPanel: ViewModifier {
    var cornerRadius: CGFloat = 10

    func body(content: Content) -> some View {
        content
            .glassSurface(cornerRadius: cornerRadius,
                          bloom: 1.05,
                          tint: StudioTheme.surfaceElevated,
                          accent: StudioTheme.cyan,
                          isInteractiveGlass: true)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(StudioTheme.brandGradient.opacity(0.55), lineWidth: 1.5)
            }
    }
}

extension View {
    func studioPanel(cornerRadius: CGFloat = 8, accent: Color = StudioTheme.cyan) -> some View {
        modifier(StudioPanel(cornerRadius: cornerRadius, accent: accent))
    }

    func studioFeaturedPanel(cornerRadius: CGFloat = 10) -> some View {
        modifier(StudioFeaturedPanel(cornerRadius: cornerRadius))
    }
}

struct StudioPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var gradient: LinearGradient = StudioTheme.brandGradient

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .foregroundStyle(isEnabled ? Color.black.opacity(0.88) : StudioTheme.textFaint)
            .padding(.vertical, 11)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isEnabled ? gradient : StudioTheme.quietGradient)
                    .overlay(alignment: .top) {
                        Color.white.opacity(isEnabled ? 0.34 : 0.10)
                            .frame(height: 1)
                    }
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.white.opacity(isEnabled ? 0.24 : 0.08), lineWidth: 1)
            }
            .shadow(color: StudioTheme.violet.opacity(isEnabled ? 0.30 : 0), radius: configuration.isPressed ? 7 : 14, x: 0, y: 6)
            .shadow(color: StudioTheme.cyan.opacity(isEnabled ? 0.18 : 0), radius: configuration.isPressed ? 5 : 9, x: 0, y: 0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct StudioSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var accent: Color = StudioTheme.cyan

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .foregroundStyle(isEnabled ? Color.primary : StudioTheme.textFaint)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .frame(minHeight: 40)
            .glassSurface(cornerRadius: 8,
                          bloom: configuration.isPressed ? 0.35 : 0.8,
                          tint: StudioTheme.surfaceElevated,
                          accent: isEnabled ? accent : .gray,
                          isInteractiveGlass: true)
            .opacity(isEnabled ? 1 : 0.55)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct StudioProgressBar: View {
    var value: Double
    var gradient: LinearGradient = StudioTheme.brandGradient
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            // value kann aus einer 0/0-Division NaN/Inf werden (z.B. 0 von 0 Kapiteln).
            // Auf 0 normalisieren, sonst zeigt der Balken fälschlich „voll" statt leer.
            let safeValue = value.isFinite ? value : 0
            ZStack(alignment: .leading) {
                Capsule().fill(StudioTheme.surfaceDeep.opacity(0.86))
                Capsule().fill(Color.white.opacity(0.06))
                Capsule()
                    .fill(gradient)
                    .frame(width: max(0, min(1, safeValue)) * geo.size.width)
                    .shadow(color: StudioTheme.cyan.opacity(0.24), radius: 4, y: 1)
            }
            .overlay { Capsule().strokeBorder(StudioTheme.hairline, lineWidth: 1) }
        }
        .frame(height: height)
    }
}

struct StudioStatNumber: View {
    let value: String
    var gradient: LinearGradient = StudioTheme.heroGradient

    var body: some View {
        Text(value)
            .font(.system(size: 30, weight: .bold, design: .monospaced))
            .foregroundStyle(gradient)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .contentTransition(.numericText())
            .animation(Motion.standard, value: value)
            .shadow(color: StudioTheme.violet.opacity(0.16), radius: 7, x: 0, y: 0)
    }
}

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
                            Capsule()
                                .fill(StudioTheme.brandGradient)
                                .overlay(Capsule().strokeBorder(Color.white.opacity(0.28), lineWidth: 1))
                                .shadow(color: StudioTheme.cyan.opacity(0.14), radius: 6, y: 3)
                        }
                    }
                    .foregroundStyle(active ? Color.black.opacity(0.86) : StudioTheme.textMuted)
                    .contentShape(Capsule())
                    .onTapGesture { selection = option }
            }
        }
        .padding(5)
        .background(Capsule().fill(StudioTheme.surfaceDeep.opacity(0.68)))
        .overlay(Capsule().strokeBorder(StudioTheme.hairline, lineWidth: 1))
    }
}

struct StudioStatusPill: View {
    let text: String
    var systemImage: String? = nil
    var color: Color = StudioTheme.cyan

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.bold))
            }
            Text(text.uppercased())
                .tracking(0.8)
                .lineLimit(1)
        }
        .font(.system(.caption2, design: .monospaced).weight(.semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.12), in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.32), lineWidth: 1))
        .shadow(color: color.opacity(0.14), radius: 4, x: 0, y: 0)
    }
}

struct StudioGlassTile: ViewModifier {
    var cornerRadius: CGFloat = 8
    var accent: Color = StudioTheme.cyan
    var opacity: Double = 1

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(colors: [
                            Color.white.opacity(0.085 * opacity),
                            accent.opacity(0.045 * opacity),
                            StudioTheme.glassInk.opacity(0.30 * opacity)
                        ], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .overlay(alignment: .top) {
                        Color.white.opacity(0.20 * opacity)
                            .frame(height: 1)
                    }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [
                            Color.white.opacity(0.24 * opacity),
                            accent.opacity(0.18 * opacity),
                            Color.white.opacity(0.055 * opacity)
                        ], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.20 * opacity), radius: 5, x: 0, y: 3)
            .shadow(color: accent.opacity(0.10 * opacity), radius: 10, x: 0, y: 0)
    }
}

extension View {
    func studioGlassTile(cornerRadius: CGFloat = 8,
                         accent: Color = StudioTheme.cyan,
                         opacity: Double = 1) -> some View {
        modifier(StudioGlassTile(cornerRadius: cornerRadius, accent: accent, opacity: opacity))
    }
}

struct StudioSectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(StudioTheme.textMuted)
            .tracking(1.5)
    }
}

/// Marken-Logo „Tinte & Papier": dunkles Emblem mit Gold-Kante, „N"-Monogramm im
/// Salbei→Gold-Verlauf und einem Forge-Funken. Skaliert über `size`.
struct NovelForgeLogo: View {
    var size: CGFloat = 44

    var body: some View {
        let radius = size * 0.27
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(
                LinearGradient(colors: [StudioTheme.surfaceElevated, StudioTheme.glassInk],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .frame(width: size, height: size)
            .overlay(alignment: .top) {
                LinearGradient(colors: [.white.opacity(0.16), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: size * 0.42)
                    .mask(RoundedRectangle(cornerRadius: radius, style: .continuous))
            }
            .overlay {
                NMonogram()
                    .stroke(StudioTheme.brandGradient,
                            style: StrokeStyle(lineWidth: size * 0.13, lineCap: .round, lineJoin: .round))
                    .padding(.horizontal, size * 0.30)
                    .padding(.vertical, size * 0.26)
            }
            .overlay(alignment: .topTrailing) {
                Image(systemName: "sparkle")
                    .font(.system(size: size * 0.20, weight: .bold))
                    .foregroundStyle(StudioTheme.amber)
                    .padding(size * 0.10)
            }
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(StudioTheme.violet.opacity(0.55), lineWidth: max(1, size * 0.024))
            )
            .shadow(color: StudioTheme.violet.opacity(0.25), radius: size * 0.16, x: 0, y: size * 0.06)
    }
}

/// Geometrisches „N" als Pfad: links hoch, Diagonale runter, rechts hoch.
struct NMonogram: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return p
    }
}
