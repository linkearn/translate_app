import AVFoundation

/// Text-to-speech using the built-in synthesizer (fully offline).
@MainActor
final class SpeechManager: NSObject, ObservableObject {
    static let shared = SpeechManager()
    private let synth = AVSpeechSynthesizer()
    @Published var speaking = false

    override init() {
        super.init()
        synth.delegate = self
    }

    func speak(_ text: String, lang: Lang, rate: Float = 0.46) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = bestVoice(for: lang)
        utterance.rate = rate
        utterance.pitchMultiplier = 1.0
        synth.speak(utterance)
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
        speaking = false
    }

    private func bestVoice(for lang: Lang) -> AVSpeechSynthesisVoice? {
        // Prefer a premium/enhanced voice when available.
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(lang.rawValue) }
        if let enhanced = voices.first(where: { $0.quality == .premium })
            ?? voices.first(where: { $0.quality == .enhanced }) {
            return enhanced
        }
        return AVSpeechSynthesisVoice(language: lang.ttsVoice) ?? voices.first
    }
}

extension SpeechManager: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didStart u: AVSpeechUtterance) {
        Task { @MainActor in self.speaking = true }
    }
    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
        Task { @MainActor in self.speaking = false }
    }
    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) {
        Task { @MainActor in self.speaking = false }
    }
}
