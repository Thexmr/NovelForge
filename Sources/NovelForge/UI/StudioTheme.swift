import SwiftUI

/// Design philosophy: NovelForge should feel like an autonomous writing command
/// center with controlled density, calm pressure, and premium production focus.
/// Signature: liquid-glass surfaces float over graphite with cyan/lime/violet
/// energy reserved for status, progress, and primary action. Constraint:
/// DESIGN_VARIANCE 7, MOTION_INTENSITY 4, VISUAL_DENSITY 8; no decorative glow
/// where plain structure would read faster.
enum StudioTheme {
    static let pageTop = Color(red: 0.025, green: 0.031, blue: 0.045)
    static let pageMiddle = Color(red: 0.050, green: 0.058, blue: 0.078)
    static let pageBottom = Color(red: 0.018, green: 0.021, blue: 0.030)

    static let surface = Color(red: 0.060, green: 0.070, blue: 0.092)
    static let surfaceElevated = Color(red: 0.095, green: 0.110, blue: 0.145)
    static let surfaceDeep = Color(red: 0.030, green: 0.036, blue: 0.050)
    static let glassBase = Color(red: 0.020, green: 0.026, blue: 0.038)
    static let glassInk = Color(red: 0.006, green: 0.010, blue: 0.018)
    static let hairline = Color.white.opacity(0.12)
    static let hairlineBright = Color.white.opacity(0.24)
    static let textMuted = Color.white.opacity(0.66)
    static let textFaint = Color.white.opacity(0.44)

    static let cyan = Color(red: 0.23, green: 0.86, blue: 0.98)
    static let violet = Color(red: 0.57, green: 0.46, blue: 0.96)
    static let magenta = Color(red: 0.94, green: 0.35, blue: 0.67)
    static let lime = Color(red: 0.55, green: 0.95, blue: 0.48)
    static let amber = Color(red: 1.00, green: 0.72, blue: 0.30)
    static let danger = Color(red: 1.00, green: 0.35, blue: 0.42)

    static var brandGradient: LinearGradient {
        LinearGradient(colors: [cyan, lime],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var heroGradient: LinearGradient {
        LinearGradient(colors: [cyan, lime, violet],
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

struct StudioBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [StudioTheme.pageTop, StudioTheme.pageMiddle, StudioTheme.pageBottom],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [StudioTheme.cyan.opacity(0.24), .clear],
                           center: UnitPoint(x: 0.10, y: 0.02), startRadius: 20, endRadius: 680)
            RadialGradient(colors: [StudioTheme.violet.opacity(0.22), .clear],
                           center: UnitPoint(x: 0.88, y: 0.20), startRadius: 40, endRadius: 760)
            RadialGradient(colors: [StudioTheme.lime.opacity(0.14), .clear],
                           center: UnitPoint(x: 0.70, y: 1.05), startRadius: 40, endRadius: 620)
            StudioBackdropGrid()
                .opacity(0.42)
            Rectangle()
                .fill(.black.opacity(0.34))
        }
        .ignoresSafeArea()
    }
}

struct StudioBackdropGrid: View {
    var body: some View {
        Canvas { context, size in
            var vertical = Path()
            var x: CGFloat = 0
            while x <= size.width {
                vertical.move(to: CGPoint(x: x, y: 0))
                vertical.addLine(to: CGPoint(x: x, y: size.height))
                x += 46
            }

            var horizontal = Path()
            var y: CGFloat = 0
            while y <= size.height {
                horizontal.move(to: CGPoint(x: 0, y: y))
                horizontal.addLine(to: CGPoint(x: size.width, y: y))
                y += 46
            }

            context.stroke(vertical, with: .color(.white.opacity(0.035)), lineWidth: 0.6)
            context.stroke(horizontal, with: .color(StudioTheme.cyan.opacity(0.025)), lineWidth: 0.6)
        }
    }
}

private struct GlassSurface: ViewModifier {
    var cornerRadius: CGFloat
    var bloom: CGFloat
    var tint: Color?
    var accent: Color
    var materialOpacity: Double
    var isInteractiveGlass: Bool

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(StudioTheme.glassBase.opacity(isInteractiveGlass ? 0.58 : 0.72))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .opacity(materialOpacity)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(colors: [
                                    Color.white.opacity(isInteractiveGlass ? 0.13 : 0.08),
                                    (tint ?? accent).opacity(isInteractiveGlass ? 0.06 : 0.035),
                                    StudioTheme.glassInk.opacity(0.50)
                                ], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(colors: [
                                    Color.white.opacity(0.06),
                                    Color.clear,
                                    StudioTheme.glassInk.opacity(0.48)
                                ], startPoint: .top, endPoint: .bottom)
                            )
                    )
                    .overlay(alignment: .top) {
                        LinearGradient(colors: [.white.opacity(0.30), .white.opacity(0.08), .clear],
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
                            .blur(radius: isInteractiveGlass ? 8 : 2)
                            .mask(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    }
            )
            .overlay { StudioTheme.glassEdge(cornerRadius, accent: accent) }
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.09), lineWidth: 3)
                    .blur(radius: 3)
                    .mask(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
            .shadow(color: Color.black.opacity(0.42), radius: isInteractiveGlass ? 22 : 13, x: 0, y: isInteractiveGlass ? 16 : 9)
            .shadow(color: accent.opacity(0.14 * Double(bloom)), radius: (isInteractiveGlass ? 18 : 9) * bloom, x: 0, y: 8)
    }
}

private extension View {
    func glassSurface(cornerRadius: CGFloat,
                      bloom: CGFloat = 1,
                      tint: Color? = nil,
                      accent: Color = StudioTheme.cyan,
                      materialOpacity: Double = 0.10,
                      isInteractiveGlass: Bool = false) -> some View {
        modifier(GlassSurface(cornerRadius: cornerRadius,
                              bloom: bloom,
                              tint: tint,
                              accent: accent,
                              materialOpacity: materialOpacity,
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
                             materialOpacity: 0.06,
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
                          materialOpacity: 0.16,
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
            .shadow(color: StudioTheme.cyan.opacity(isEnabled ? 0.26 : 0), radius: configuration.isPressed ? 5 : 14, x: 0, y: 8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
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
                          materialOpacity: 0.10,
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
            ZStack(alignment: .leading) {
                Capsule().fill(StudioTheme.surfaceDeep.opacity(0.86))
                Capsule().fill(.ultraThinMaterial).opacity(0.35)
                Capsule()
                    .fill(gradient)
                    .frame(width: max(0, min(1, value)) * geo.size.width)
                    .shadow(color: StudioTheme.cyan.opacity(0.46), radius: 7, y: 1)
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
            .font(.system(size: 30, weight: .bold, design: .rounded))
            .foregroundStyle(gradient)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .monospacedDigit()
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
                                .shadow(color: StudioTheme.cyan.opacity(0.22), radius: 10, y: 4)
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
            Text(text)
                .lineLimit(1)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(color.opacity(0.12), in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.28), lineWidth: 1))
    }
}

struct StudioSectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(StudioTheme.textFaint)
            .tracking(0)
    }
}
