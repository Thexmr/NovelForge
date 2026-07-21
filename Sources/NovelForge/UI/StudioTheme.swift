import SwiftUI

/// NovelForge's visual language: a quiet editorial workspace with translucent
/// materials, precise borders and color reserved for state and action.
enum StudioTheme {
    static let pageTop = Color(red: 0.040, green: 0.047, blue: 0.058)
    static let pageMiddle = Color(red: 0.052, green: 0.060, blue: 0.071)
    static let pageBottom = Color(red: 0.028, green: 0.033, blue: 0.041)

    static let surface = Color(red: 0.090, green: 0.101, blue: 0.116)
    static let surfaceElevated = Color(red: 0.128, green: 0.142, blue: 0.160)
    static let surfaceDeep = Color(red: 0.047, green: 0.054, blue: 0.065)
    static let glassBase = Color(red: 0.075, green: 0.086, blue: 0.101)
    static let glassInk = Color(red: 0.024, green: 0.029, blue: 0.036)
    static let hairline = Color.white.opacity(0.10)
    static let hairlineBright = Color.white.opacity(0.20)
    static let textMuted = Color.white.opacity(0.68)
    static let textFaint = Color.white.opacity(0.44)

    static let cyan = Color(red: 0.27, green: 0.76, blue: 0.72)
    static let violet = Color(red: 0.49, green: 0.61, blue: 0.94)
    static let magenta = Color(red: 0.91, green: 0.49, blue: 0.53)
    static let lime = Color(red: 0.43, green: 0.77, blue: 0.52)
    static let amber = Color(red: 0.90, green: 0.68, blue: 0.32)
    static let danger = Color(red: 0.93, green: 0.39, blue: 0.42)

    static var brandGradient: LinearGradient {
        LinearGradient(colors: [cyan, violet], startPoint: .leading, endPoint: .trailing)
    }

    static var heroGradient: LinearGradient {
        LinearGradient(colors: [Color.white, cyan.opacity(0.94)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func accentGradient(_ accent: Color) -> LinearGradient {
        LinearGradient(colors: [accent.opacity(0.98), accent.opacity(0.68)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var quietGradient: LinearGradient {
        LinearGradient(colors: [surfaceElevated.opacity(0.90), surface.opacity(0.72)],
                       startPoint: .top, endPoint: .bottom)
    }

    @ViewBuilder
    static func glassEdge(_ cornerRadius: CGFloat, accent: Color = StudioTheme.cyan) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(colors: [
                    Color.white.opacity(0.30),
                    accent.opacity(0.18),
                    Color.white.opacity(0.055)
                ], startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 1
            )
    }
}

@MainActor
struct StudioBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [StudioTheme.pageTop, StudioTheme.pageMiddle, StudioTheme.pageBottom],
                           startPoint: .top, endPoint: .bottom)
            StudioGrid()
            Rectangle().fill(.black.opacity(0.14))
        }
        .ignoresSafeArea()
    }
}

@MainActor
private struct StudioGrid: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 36
            var path = Path()
            var x: CGFloat = step
            while x < size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += step
            }
            var y: CGFloat = step
            while y < size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += step
            }
            context.stroke(path, with: .color(.white.opacity(0.024)), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
    }
}

enum Motion {
    static let fast = Animation.easeOut(duration: 0.12)
    static let standard = Animation.spring(response: 0.34, dampingFraction: 0.86)
    static let expressive = Animation.spring(response: 0.48, dampingFraction: 0.78)
}

extension View {
    func neonGlow(_ color: Color, intensity: Double = 1) -> some View {
        shadow(color: color.opacity(0.16 * intensity), radius: 8, x: 0, y: 3)
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
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(StudioTheme.glassBase.opacity(isInteractiveGlass ? 0.42 : 0.52))
                    }
                    .overlay(alignment: .top) {
                        LinearGradient(colors: [
                            Color.white.opacity(isInteractiveGlass ? 0.16 : 0.11),
                            (tint ?? accent).opacity(0.035),
                            .clear
                        ], startPoint: .top, endPoint: .bottom)
                        .frame(height: max(22, cornerRadius * 4))
                        .mask(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    }
            }
            .overlay { StudioTheme.glassEdge(cornerRadius, accent: accent) }
            .shadow(color: .black.opacity(isInteractiveGlass ? 0.24 : 0.16),
                    radius: isInteractiveGlass ? 10 : 5,
                    x: 0,
                    y: isInteractiveGlass ? 6 : 3)
            .shadow(color: accent.opacity(0.035 * Double(bloom)), radius: 8 * bloom, x: 0, y: 2)
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
                             bloom: 0.35,
                             accent: accent,
                             isInteractiveGlass: false)
    }
}

struct StudioFeaturedPanel: ViewModifier {
    var cornerRadius: CGFloat = 8

    func body(content: Content) -> some View {
        content
            .glassSurface(cornerRadius: cornerRadius,
                          bloom: 0.65,
                          tint: StudioTheme.surfaceElevated,
                          accent: StudioTheme.cyan,
                          isInteractiveGlass: true)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(StudioTheme.brandGradient.opacity(0.34), lineWidth: 1)
            }
    }
}

private struct StudioHoverModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered && !reduceMotion ? 1.008 : 1)
            .offset(y: isHovered && !reduceMotion ? -1 : 0)
            .animation(reduceMotion ? nil : Motion.standard, value: isHovered)
            .onHover { isHovered = $0 }
    }
}

extension View {
    func studioPanel(cornerRadius: CGFloat = 8, accent: Color = StudioTheme.cyan) -> some View {
        modifier(StudioPanel(cornerRadius: cornerRadius, accent: accent))
    }

    func studioFeaturedPanel(cornerRadius: CGFloat = 8) -> some View {
        modifier(StudioFeaturedPanel(cornerRadius: cornerRadius))
    }

    func studioHoverable() -> some View {
        modifier(StudioHoverModifier())
    }
}

struct StudioPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var gradient: LinearGradient = StudioTheme.brandGradient

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .foregroundStyle(isEnabled ? Color.black.opacity(0.86) : StudioTheme.textFaint)
            .padding(.vertical, 10)
            .padding(.horizontal, 15)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isEnabled ? gradient : StudioTheme.quietGradient)
                    .overlay(alignment: .top) {
                        Color.white.opacity(isEnabled ? 0.30 : 0.08).frame(height: 1)
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Color.white.opacity(isEnabled ? 0.22 : 0.07), lineWidth: 1)
            }
            .shadow(color: StudioTheme.cyan.opacity(isEnabled ? 0.16 : 0),
                    radius: configuration.isPressed ? 3 : 8,
                    x: 0,
                    y: configuration.isPressed ? 1 : 4)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : Motion.fast, value: configuration.isPressed)
    }
}

struct StudioSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var accent: Color = StudioTheme.cyan

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .foregroundStyle(isEnabled ? Color.primary : StudioTheme.textFaint)
            .padding(.vertical, 9)
            .padding(.horizontal, 13)
            .frame(minHeight: 38)
            .glassSurface(cornerRadius: 7,
                          bloom: configuration.isPressed ? 0.15 : 0.35,
                          tint: StudioTheme.surfaceElevated,
                          accent: isEnabled ? accent : .gray,
                          isInteractiveGlass: true)
            .opacity(isEnabled ? 1 : 0.54)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : Motion.fast, value: configuration.isPressed)
    }
}

@MainActor
struct StudioProgressBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var value: Double
    var gradient: LinearGradient = StudioTheme.brandGradient
    var height: CGFloat = 7

    var body: some View {
        GeometryReader { geometry in
            let safeValue = value.isFinite ? max(0, min(1, value)) : 0
            ZStack(alignment: .leading) {
                Capsule().fill(StudioTheme.surfaceDeep.opacity(0.90))
                Capsule().fill(Color.white.opacity(0.045))
                Capsule()
                    .fill(gradient)
                    .frame(width: safeValue * geometry.size.width)
                    .shadow(color: StudioTheme.cyan.opacity(0.15), radius: 3, y: 1)
            }
            .overlay { Capsule().strokeBorder(StudioTheme.hairline, lineWidth: 1) }
            .animation(reduceMotion ? nil : Motion.standard, value: safeValue)
        }
        .frame(height: height)
        .accessibilityValue("\(Int(max(0, min(1, value.isFinite ? value : 0)) * 100)) Prozent")
    }
}

@MainActor
struct StudioStatNumber: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let value: String
    var gradient: LinearGradient = StudioTheme.heroGradient

    var body: some View {
        Text(value)
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(gradient)
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .contentTransition(.numericText())
            .animation(reduceMotion ? nil : Motion.standard, value: value)
    }
}

@MainActor
struct StudioSegmentedPills: View {
    let options: [String]
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 3) {
            ForEach(options, id: \.self) { option in
                let active = option == selection
                Button {
                    withAnimation(Motion.fast) { selection = option }
                } label: {
                    Text(option)
                        .font(.subheadline.weight(.semibold))
                        .padding(.vertical, 7)
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(active ? Color.black.opacity(0.86) : StudioTheme.textMuted)
                        .background {
                            if active {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(StudioTheme.brandGradient)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(active ? .isSelected : [])
            }
        }
        .padding(4)
        .background(StudioTheme.surfaceDeep.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(StudioTheme.hairline, lineWidth: 1))
    }
}

@MainActor
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
        .padding(.vertical, 4)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(color.opacity(0.28), lineWidth: 1))
    }
}

@MainActor
struct StudioLiveIndicator: View {
    var color: Color = StudioTheme.lime
    var isActive = true

    var body: some View {
        ZStack {
            Circle()
                .fill((isActive ? color : StudioTheme.textFaint).opacity(0.16))
                .frame(width: 13, height: 13)
            Circle()
                .fill(isActive ? color : StudioTheme.textFaint)
                .frame(width: 7, height: 7)
                .shadow(color: isActive ? color.opacity(0.55) : .clear, radius: 4)
        }
        .frame(width: 16, height: 16)
        .accessibilityHidden(true)
    }
}

struct StudioGlassTile: ViewModifier {
    var cornerRadius: CGFloat = 8
    var accent: Color = StudioTheme.cyan
    var opacity: Double = 1

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(StudioTheme.surface.opacity(0.58 * opacity))
                    .overlay(alignment: .top) {
                        Color.white.opacity(0.10 * opacity).frame(height: 1)
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [Color.white.opacity(0.17 * opacity),
                                                accent.opacity(0.12 * opacity),
                                                Color.white.opacity(0.045 * opacity)],
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing),
                        lineWidth: 1
                    )
            }
    }
}

extension View {
    func studioGlassTile(cornerRadius: CGFloat = 8,
                         accent: Color = StudioTheme.cyan,
                         opacity: Double = 1) -> some View {
        modifier(StudioGlassTile(cornerRadius: cornerRadius, accent: accent, opacity: opacity))
    }
}

@MainActor
struct StudioSectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(StudioTheme.textMuted)
    }
}

@MainActor
struct NovelForgeLogo: View {
    var size: CGFloat = 44

    var body: some View {
        let radius = min(8, size * 0.20)
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(.ultraThinMaterial)
            .frame(width: size, height: size)
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(StudioTheme.glassBase.opacity(0.48))
            }
            .overlay {
                NMonogram()
                    .stroke(StudioTheme.brandGradient,
                            style: StrokeStyle(lineWidth: size * 0.12, lineCap: .round, lineJoin: .round))
                    .padding(.horizontal, size * 0.30)
                    .padding(.vertical, size * 0.25)
            }
            .overlay(alignment: .topTrailing) {
                Image(systemName: "sparkle")
                    .font(.system(size: size * 0.18, weight: .bold))
                    .foregroundStyle(StudioTheme.amber)
                    .padding(size * 0.09)
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(StudioTheme.hairlineBright, lineWidth: 1)
            }
            .shadow(color: StudioTheme.cyan.opacity(0.12), radius: size * 0.12, x: 0, y: size * 0.04)
    }
}

struct NMonogram: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}
