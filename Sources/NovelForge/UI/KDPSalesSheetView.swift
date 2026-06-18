import SwiftUI

struct KDPSalesSheetView: View {
    let project: Project

    private var sheet: KDPSalesSheet {
        KDPSalesSheet.make(for: project)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Label("KDP-Verkaufsseite", systemImage: "cart.badge.plus")
                    .font(.headline)
                    .foregroundStyle(StudioTheme.heroGradient)
                Spacer()
                StudioStatusPill(text: sheet.hasGeneratedMetadata ? "bereit" : "wartet",
                                 systemImage: sheet.hasGeneratedMetadata ? "checkmark.seal" : "clock",
                                 color: sheet.hasGeneratedMetadata ? StudioTheme.lime : StudioTheme.amber)
            }

            VStack(alignment: .leading, spacing: 10) {
                salesField("Verkaufstitel", sheet.title, accent: StudioTheme.cyan)
                if !sheet.hook.isEmpty {
                    salesField("Untertitel / Hook", sheet.hook, accent: StudioTheme.violet)
                }
                if !sheet.salesDescription.isEmpty {
                    salesField("Verkaufstext", sheet.salesDescription, accent: StudioTheme.magenta)
                }
                if !sheet.keywords.isEmpty {
                    salesField("Keywords", sheet.keywords, accent: StudioTheme.lime)
                }
                if !sheet.categories.isEmpty {
                    salesField("Kategorien", sheet.categories, accent: StudioTheme.amber)
                }
                if !sheet.authorProfile.isEmpty {
                    salesField("Autorprofil", sheet.authorProfile, accent: StudioTheme.cyan)
                }
                if !sheet.hasGeneratedMetadata {
                    Label("Verkaufstext, Keywords und Kategorien entstehen automatisch in der KDP-Formatierung.",
                          systemImage: "sparkles")
                        .font(.caption)
                        .foregroundStyle(StudioTheme.textMuted)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .studioGlassTile(cornerRadius: 8, accent: StudioTheme.cyan, opacity: 0.9)
        }
    }

    private func salesField(_ label: String, _ value: String, accent: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accent)
                .frame(width: 3)
                .padding(.top, 3)

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(StudioTheme.textFaint)
                Text(value)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .help("\(label) kopieren")
        }
    }
}
