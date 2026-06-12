import SwiftUI

enum StudioTheme {
    static let ink = Color(red: 0.035, green: 0.047, blue: 0.070)
    static let panel = Color(red: 0.075, green: 0.090, blue: 0.120)
    static let panelRaised = Color(red: 0.105, green: 0.125, blue: 0.165)
    static let cyan = Color(red: 0.18, green: 0.82, blue: 0.92)
    static let lime = Color(red: 0.60, green: 0.95, blue: 0.58)
    static let amber = Color(red: 1.0, green: 0.68, blue: 0.22)
}

struct StudioBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [StudioTheme.ink, Color.black.opacity(0.92)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [StudioTheme.cyan.opacity(0.18), .clear],
                           center: .topTrailing, startRadius: 20, endRadius: 520)
            RadialGradient(colors: [StudioTheme.lime.opacity(0.08), .clear],
                           center: .bottomLeading, startRadius: 20, endRadius: 520)
        }
        .ignoresSafeArea()
    }
}

struct StudioPanel: ViewModifier {
    var cornerRadius: CGFloat = 14
    var accent: Color = StudioTheme.cyan

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(StudioTheme.panel.opacity(0.82))
                    .overlay(alignment: .topLeading) {
                        LinearGradient(colors: [accent.opacity(0.32), .clear],
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(height: 1)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.10))
                    }
            )
            .shadow(color: accent.opacity(0.10), radius: 20, x: 0, y: 10)
    }
}

extension View {
    func studioPanel(cornerRadius: CGFloat = 14, accent: Color = StudioTheme.cyan) -> some View {
        modifier(StudioPanel(cornerRadius: cornerRadius, accent: accent))
    }
}
