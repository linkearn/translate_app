import SwiftUI
import AppKit

@MainActor
final class AppState: ObservableObject {
    // Input / output
    @Published var inputText = ""
    @Published var outputText = ""
    @Published var outputLang: Lang = .english
    @Published var note: String?

    // Language selection
    @Published var source: LangSel = .auto
    @Published var detected: Lang?

    // Status
    @Published var isTranslating = false
    @Published var errorMessage: String?

    // Word focus (English output only)
    @Published var focusedToken: String?
    @Published var wordDetail: WordDetail?
    @Published var loadingWord = false
    @Published var rebuilding = false

    // Settings
    @AppStorage("model") var model: String = "claude-sonnet-4-6"
    @AppStorage("autoCapture") var autoCapture: Bool = false {
        didSet { clipboard.enabled = autoCapture }
    }
    @Published var hasKey: Bool = KeychainStore.load()?.isEmpty == false

    private let clipboard = ClipboardWatcher()
    private var lastSourceText = ""   // text we actually translated, for word rebuilds

    init() {
        clipboard.enabled = autoCapture
        clipboard.onChange = { [weak self] text in
            Task { @MainActor in self?.capture(text) }
        }
        clipboard.start()

        HotKeyManager.shared.onCapture = { [weak self] text in
            Task { @MainActor in self?.capture(text) }
        }
        HotKeyManager.shared.register()
    }

    // MARK: - Derived

    var effectiveSource: Lang {
        source.fixedValue ?? detected ?? LanguageDetector.detect(inputText) ?? .english
    }
    var effectiveTarget: Lang { effectiveSource.opposite }

    private func client() -> ClaudeClient? {
        guard let key = KeychainStore.load(), !key.isEmpty else { return nil }
        return ClaudeClient(apiKey: key, model: model)
    }

    func refreshKeyState() { hasKey = KeychainStore.load()?.isEmpty == false }

    // MARK: - Capture (hotkey / clipboard)

    func capture(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != inputText else { return }
        inputText = trimmed
        source = .auto
        detectNow()
        NSApp.activate(ignoringOtherApps: true)
        translate()
    }

    // MARK: - Language detection

    func detectNow() {
        detected = LanguageDetector.detect(inputText)
    }

    // MARK: - Translate

    func translate() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard let client = client() else {
            errorMessage = ClaudeClient.ClientError.noKey.errorDescription
            return
        }
        detectNow()
        let src = effectiveSource
        let dst = src.opposite

        // Reset word focus on a fresh translation.
        focusedToken = nil
        wordDetail = nil
        errorMessage = nil
        isTranslating = true

        Task {
            defer { isTranslating = false }
            do {
                let result = try await client.translate(text, from: src, to: dst)
                self.outputText = result.translation
                self.outputLang = dst
                self.lastSourceText = text
                self.note = (result.note?.isEmpty == false) ? result.note : nil
            } catch {
                self.errorMessage = (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
            }
        }
    }

    func swapDirection() {
        // Move output into input and re-detect so the user can translate back.
        guard !outputText.isEmpty else { return }
        inputText = outputText
        source = .fixed(outputLang)
        outputText = ""
        wordDetail = nil
        focusedToken = nil
        detectNow()
    }

    func clearAll() {
        inputText = ""; outputText = ""; note = nil
        wordDetail = nil; focusedToken = nil; errorMessage = nil
        detected = nil
    }

    // MARK: - Word focus (English output)

    func focusWord(_ rawToken: String) {
        let word = rawToken.trimmingCharacters(in: CharacterSet.letters.inverted)
        guard !word.isEmpty, outputLang == .english else { return }
        guard let client = client() else {
            errorMessage = ClaudeClient.ClientError.noKey.errorDescription
            return
        }
        focusedToken = word
        wordDetail = nil
        loadingWord = true
        let context = outputText

        Task {
            defer { loadingWord = false }
            do {
                let detail = try await client.wordDetail(word: word, context: context)
                // Ignore if focus changed meanwhile.
                if self.focusedToken == word { self.wordDetail = detail }
            } catch {
                if self.focusedToken == word {
                    self.errorMessage = (error as? LocalizedError)?.errorDescription
                        ?? error.localizedDescription
                }
            }
        }
    }

    func dismissWord() {
        focusedToken = nil
        wordDetail = nil
    }

    /// Replace the focused word with an alternative and rebuild the sentence.
    func applyAlternative(_ replacement: String) {
        guard let word = focusedToken, let client = client() else { return }
        rebuilding = true
        let current = outputText
        Task {
            defer { rebuilding = false }
            do {
                let rebuilt = try await client.replaceWord(in: current, word: word, replacement: replacement)
                self.outputText = rebuilt
                self.focusedToken = nil
                self.wordDetail = nil
            } catch {
                self.errorMessage = (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
            }
        }
    }

    // MARK: - Manual source override

    func setSource(_ sel: LangSel) {
        source = sel
        if case .fixed(let l) = sel { detected = l }
        else { detectNow() }
    }
}
