import SwiftUI

/// Renders the translation output. English => tappable word chips; Japanese => plain text.
struct OutputView: View {
    @EnvironmentObject var state: AppState
    @ObservedObject var speech = SpeechManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(state.outputLang.longName.uppercased(),
                      systemImage: "arrow.down.right.circle")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Cyber.green)
                Spacer()
                if state.outputLang == .english {
                    Text("単語をクリックで詳細")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Cyber.dim)
                }
                speakerButton(text: state.outputText, lang: state.outputLang, tint: Cyber.green)
            }

            if state.outputText.isEmpty {
                Text("// 翻訳結果がここに表示されます")
                    .font(Cyber.mono)
                    .foregroundStyle(Cyber.dim)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if state.outputLang == .english {
                englishTokens
            } else {
                Text(state.outputText)
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(Cyber.text)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let note = state.note {
                Label(note, systemImage: "info.circle")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Cyber.amber)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .neonPanel(Cyber.green.opacity(0.5), glow: Cyber.green)
    }

    private var englishTokens: some View {
        FlowLayout(spacing: 6, lineSpacing: 9) {
            ForEach(Array(Tokenizer.chunks(state.outputText).enumerated()), id: \.offset) { _, chunk in
                WordChip(
                    chunk: chunk,
                    focused: isFocused(chunk),
                    action: { state.focusWord(chunk) }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func isFocused(_ chunk: String) -> Bool {
        guard let f = state.focusedToken else { return false }
        let core = chunk.trimmingCharacters(in: CharacterSet.letters.inverted)
        return core.caseInsensitiveCompare(f) == .orderedSame
    }

    @ViewBuilder
    func speakerButton(text: String, lang: Lang, tint: Color) -> some View {
        Button {
            if speech.speaking { speech.stop() }
            else { speech.speak(text, lang: lang) }
        } label: {
            Image(systemName: speech.speaking ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                .foregroundStyle(tint)
                .neonGlow(tint, radius: 4)
        }
        .buttonStyle(.plain)
        .help("読み上げ")
        .disabled(text.isEmpty)
    }
}

/// One tappable word in the English output.
struct WordChip: View {
    let chunk: String
    let focused: Bool
    let action: () -> Void

    private var hasLetters: Bool {
        chunk.rangeOfCharacter(from: .letters) != nil
    }

    var body: some View {
        if hasLetters {
            Button(action: action) {
                Text(chunk)
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(focused ? Cyber.bg : Cyber.text)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(focused ? Cyber.cyan : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Cyber.cyan.opacity(focused ? 0 : 0.0), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
        } else {
            Text(chunk)
                .font(.system(.title3, design: .rounded))
                .foregroundStyle(Cyber.text)
        }
    }
}
