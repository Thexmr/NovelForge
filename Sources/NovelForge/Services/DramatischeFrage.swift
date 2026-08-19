import Foundation

/// DIE FRAGE, DIE DAS BUCH STELLT – vom Stichwort zum Maßstab.
///
/// **Was war.** `plotArchitekturMaengel` prüft, ob im Plot-Dokument die Zeichenkette
/// „dramatische frage" vorkommt. Das ist eine Suche nach dem Etikett, nicht nach der
/// Sache: Ein Plot mit der Zeile „Zentrale Frage: Wird sie es schaffen?" besteht die
/// Prüfung, ein hervorragender Plot, der seine Frage anders nennt, fällt durch. Und was
/// noch schwerer wiegt: Die Frage wurde nach dieser Prüfung nie wieder verwendet. Sie
/// stand im Plotdokument und kam beim Schreiber nie an.
///
/// **Warum das ein 500-Seiten-Problem ist.** Ein Roman ist nicht die Summe seiner Szenen.
/// Er ist eine einzige Frage, die 500 Seiten lang offen gehalten wird – „Kommen die
/// beiden zusammen?", „Erfährt sie, wer ihre Mutter getötet hat?", „Kann er zurück, ohne
/// zu verlieren, wofür er gegangen ist?" Jede Szene schiebt diese Frage ein Stück weiter,
/// verschärft sie oder scheint sie zu beantworten. Fehlt der Bezug, kann ein Buch 250
/// handwerklich saubere Szenen haben und sich trotzdem lesen wie eine Aufzählung. Genau
/// dieser Eindruck ist an den ausgelieferten Büchern beschrieben worden.
///
/// **Was diese Datei tut.** Sie holt die Frage aus dem Plot heraus und legt sie dem
/// Schreiber in jede Szene. Mehr nicht – und bewusst nicht mehr: Ob eine Szene die Frage
/// wirklich vorantreibt, ist eine Bewertung, keine Messung. Sie deterministisch zu
/// behaupten hieße, eine Zahl zu erfinden. Die Prävention im Prompt ist hier die ganze
/// Wirkung, und nach Projektregel 4 die wirksamere Hälfte ohnehin.
enum DramatischeFrage {

    /// Sucht die zentrale Frage im Plotdokument.
    ///
    /// Zwei Wege, in dieser Reihenfolge:
    /// 1. Eine als solche bezeichnete Zeile („Zentrale dramatische Frage: …"). Das ist der
    ///    Normalfall, weil der Plot-Prompt sie ausdrücklich verlangt.
    /// 2. Sonst der erste Fragesatz des Dokuments, der lang genug ist, um eine Buchfrage
    ///    zu sein. Das rettet Pläne, die die Frage stellen, ohne sie zu etikettieren –
    ///    also genau die Fälle, an denen die reine Stichwortsuche scheitert.
    static func finde(in plot: String) -> String? {
        if let markiert = ausMarkierterZeile(plot) { return markiert }
        return ersterFragesatz(plot)
    }

    private static let marker = [
        "zentrale dramatische frage", "dramatische frage", "zentrale frage", "hauptfrage",
        "leitfrage", "erzählfrage", "erzaehlfrage",
    ]

    private static func ausMarkierterZeile(_ plot: String) -> String? {
        for zeile in plot.components(separatedBy: .newlines) {
            let klein = zeile.folding(options: [.caseInsensitive, .diacriticInsensitive],
                                      locale: .current)
            guard marker.contains(where: { klein.contains($0) }) else { continue }
            // Alles nach dem Doppelpunkt ist die Frage; ohne Doppelpunkt die ganze Zeile
            // ohne ihre Überschrift.
            let inhalt: String
            if let doppelpunkt = zeile.firstIndex(of: ":") {
                inhalt = String(zeile[zeile.index(after: doppelpunkt)...])
            } else {
                inhalt = zeile
            }
            let sauber = bereinigt(inhalt)
            if sauber.wordCount >= 4 { return sauber }
        }
        return nil
    }

    private static func ersterFragesatz(_ plot: String) -> String? {
        // EINZELNE ZEILENUMBRÜCHE SIND KEINE SATZGRENZEN.
        //
        // Die erste Fassung setzte bei jedem „\n" zurück. In einem umbrochenen
        // Plotdokument steht die Buchfrage aber fast immer über zwei Zeilen – und dann
        // fand die Suche nur ihr Ende („dieselben Fehler zu machen wie er?") statt der
        // ganzen Frage. Ein Absatzwechsel (Leerzeile) trennt weiterhin, ein Umbruch
        // innerhalb des Absatzes nicht.
        let normalisiert = plot
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\n\n", with: ". ")
            .replacingOccurrences(of: "\n", with: " ")

        var satz = ""
        for zeichen in normalisiert {
            if zeichen == "?" {
                let kandidat = bereinigt(satz) + "?"
                // Kurze Fragen sind Zwischenüberschriften oder rhetorische Einwürfe,
                // sehr lange sind Absätze mit einem Fragezeichen darin.
                if (5...30).contains(kandidat.wordCount) { return kandidat }
                satz = ""
                continue
            }
            if zeichen == "." || zeichen == "!" { satz = ""; continue }
            satz.append(zeichen)
        }
        return nil
    }

    private static func bereinigt(_ text: String) -> String {
        text.trimmingCharacters(in: CharacterSet(charactersIn: " \t\n-–—*•>„“\"'"))
    }

    /// Der Block für den Schreib-Prompt.
    ///
    /// Bewusst kurz und ohne Aufzählung: Diese Zeile steht neben zwanzig anderen
    /// Anweisungen. Sie wirkt, wenn sie die Frage nennt und eine einzige Forderung stellt,
    /// nicht wenn sie eine weitere Regelliste eröffnet.
    static func promptBlock(frage: String?) -> String {
        guard let frage, !frage.isEmpty else { return "" }
        return """

        DIE FRAGE DES BUCHES: \(frage)
        Alles in diesem Roman hängt daran. Diese Szene bringt sie ein Stück weiter, \
        verschärft sie oder lässt sie für einen Moment beantwortet scheinen — beantwortet \
        wird sie erst am Schluss. Eine Szene ohne Bezug zu dieser Frage ist Beiwerk, \
        gleichgültig wie gut sie geschrieben ist.
        """
    }
}
