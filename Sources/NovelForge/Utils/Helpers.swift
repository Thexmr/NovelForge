import Foundation
import SwiftUI

struct AppConstants {
    static let appName = "NovelForge"
    static let appVersion = "1.0.0"
    static let maxPageCount = 500
    static let minPageCount = 50
    static let wordsPerPage = 250
    static let defaultTemperature = 0.7
    static let defaultMaxTokens = 4000
    static let heartbeatInterval: TimeInterval = 30
    static let maxRetries = 3
    static let retryDelay: UInt64 = 2_000_000_000 // 2 seconds
}

struct QualityThresholds {
    static let minStructureScore = 0.7
    static let minCharacterScore = 0.7
    static let minStyleScore = 0.7
    static let minConsistencyScore = 0.8
    static let minKDPScore = 0.9
    static let wordCountTolerance = 0.2 // 20%
}

enum AppError: LocalizedError {
    case invalidInput(String)
    case pipelineError(String)
    case exportError(String)
    case providerError(AIError)
    
    var errorDescription: String? {
        switch self {
        case .invalidInput(let msg):
            return "Ungültige Eingabe: \(msg)"
        case .pipelineError(let msg):
            return "Pipeline-Fehler: \(msg)"
        case .exportError(let msg):
            return "Export-Fehler: \(msg)"
        case .providerError(let error):
            return error.localizedDescription
        }
    }
}

extension Date {
    func formattedString() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: self)
    }
}

extension String {
    func truncated(to length: Int, trailing: String = "...") -> String {
        if self.count > length {
            return String(self.prefix(length)) + trailing
        }
        return self
    }
    
    func estimatedTokenCount() -> Int {
        // Rough estimate: ~4 characters per token for German/English
        return self.count / 4
    }
}

struct FormattingHelpers {
    static func formatWordCount(_ count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }
    
    static func formatPageCount(_ count: Int) -> String {
        return "\(count) Seiten"
    }
    
    static func formatCost(_ cost: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: NSNumber(value: cost)) ?? "\(cost) USD"
    }
    
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }
}

// MARK: - Copyright Protection

struct CopyrightChecker {
    private static let forbiddenTerms = [
        "bestsellerautor", "kopiere", "fortsetzung von", "wie j.k. rowling",
        "wie stephen king", "wie george r.r. martin", "wie dan brown",
        "harry potter", "herr der ringe", "game of thrones",
        "star wars", "star trek", "marvel", "dc comics"
    ]
    
    private static let allowedStyles = [
        "düster", "literarisch", "dialogstark", "humorvoll", "episch",
        "emotional", "schnell erzählt", "minimalistisch", "atmosphärisch",
        "actionreich", "psychologisch"
    ]
    
    static func checkInput(title: String, style: String) -> (isValid: Bool, warnings: [String]) {
        var warnings: [String] = []
        let input = "\(title) \(style)".lowercased()
        
        for term in forbiddenTerms {
            if input.contains(term) {
                warnings.append("Copyright-Risiko erkannt: '\(term)'")
            }
        }
        
        let styleLower = style.lowercased()
        let isAllowedStyle = allowedStyles.contains { styleLower.contains($0) }
        
        if !isAllowedStyle && !style.isEmpty {
            warnings.append("Stilprofil sollte ein abstraktes Stilkriterium sein.")
        }
        
        return (warnings.isEmpty, warnings)
    }
    
    static func checkPlot(_ plot: String) -> [String] {
        var issues: [String] = []
        let plotLower = plot.lowercased()
        
        // Check for direct plot copies
        let knownPlots = [
            "harry potter": "Magierschule mit Zauberstab",
            "herr der ringe": "Ring muss vernichtet werden",
            "game of thrones": "Thronkonflikt in Fantasiewelt"
        ]
        
        for (key, description) in knownPlots {
            if plotLower.contains(key) {
                issues.append("Mögliche Ähnlichkeit zu bekanntem Werk: \(description)")
            }
        }
        
        return issues
    }
}

// MARK: - Validation

struct InputValidator {
    static func validateProject(_ project: Project) -> (isValid: Bool, errors: [String]) {
        var errors: [String] = []
        
        if project.title.isEmpty {
            errors.append("Titel ist erforderlich")
        }
        
        if project.authorName.isEmpty {
            errors.append("Autorname ist erforderlich")
        }
        
        if project.genre.isEmpty {
            errors.append("Genre ist erforderlich")
        }
        
        if project.targetPageCount < AppConstants.minPageCount || project.targetPageCount > AppConstants.maxPageCount {
            errors.append("Seitenzahl muss zwischen \(AppConstants.minPageCount) und \(AppConstants.maxPageCount) liegen")
        }
        
        if project.styleProfile.isEmpty {
            errors.append("Stilprofil ist erforderlich")
        }
        
        let copyrightCheck = CopyrightChecker.checkInput(title: project.title, style: project.styleProfile)
        if !copyrightCheck.isValid {
            errors.append(contentsOf: copyrightCheck.warnings)
        }
        
        return (errors.isEmpty, errors)
    }
}