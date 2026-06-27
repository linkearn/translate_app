import Foundation
import NaturalLanguage

/// The two supported languages.
enum Lang: String, CaseIterable, Identifiable, Codable {
    case english = "en"
    case japanese = "ja"

    var id: String { rawValue }
    var display: String { self == .english ? "EN" : "JA" }
    var longName: String { self == .english ? "English" : "Japanese" }
    var nativeName: String { self == .english ? "英語" : "日本語" }
    var opposite: Lang { self == .english ? .japanese : .english }
    var ttsVoice: String { self == .english ? "en-US" : "ja-JP" }
}

/// Source selector: may be auto-detected or forced.
enum LangSel: Equatable {
    case auto
    case fixed(Lang)

    var fixedValue: Lang? {
        if case .fixed(let l) = self { return l }
        return nil
    }
}

/// Result of a translation request.
struct TranslationResult: Codable {
    var translation: String
    var note: String?
}

/// Detailed dictionary info for a single English word.
struct WordDetail: Codable, Identifiable {
    var word: String
    var ipa: String
    var stress: String
    var pos: String
    var meaning_ja: String
    var examples: [Example]
    var alternatives: [Alternative]

    var id: String { word.lowercased() }

    struct Example: Codable, Identifiable {
        var en: String
        var ja: String
        var id: String { en }
    }
    struct Alternative: Codable, Identifiable {
        var word: String
        var nuance_ja: String
        var id: String { word }
    }
}

/// Offline language detection via Apple's NaturalLanguage framework.
enum LanguageDetector {
    static func detect(_ text: String) -> Lang? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Fast path: any Japanese script => Japanese.
        if trimmed.unicodeScalars.contains(where: { isJapaneseScalar($0) }) {
            return .japanese
        }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmed)
        switch recognizer.dominantLanguage {
        case .japanese: return .japanese
        case .english:  return .english
        default:
            // Default to English for latin text we cannot otherwise place.
            return .english
        }
    }

    private static func isJapaneseScalar(_ s: Unicode.Scalar) -> Bool {
        switch s.value {
        case 0x3040...0x30FF,   // Hiragana + Katakana
             0x4E00...0x9FFF,   // CJK unified ideographs
             0x3400...0x4DBF,   // CJK ext A
             0xFF66...0xFF9D:   // half-width katakana
            return true
        default:
            return false
        }
    }
}
