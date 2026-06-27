import SwiftUI

/// The dictionary panel shown when an English word is focused.
struct WordDetailView: View {
    @EnvironmentObject var state: AppState
    @ObservedObject var speech = SpeechManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(Cyber.magenta.opacity(0.4))
            if state.loadingWord {
                loading
            } else if let d = state.wordDetail {
                content(d)
            }
        }
        .neonPanel(Cyber.magenta.opacity(0.6), glow: Cyber.magenta)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var header: some View {
        HStack {
            Image(systemName: "waveform.circle.fill").foregroundStyle(Cyber.magenta)
            Text(state.focusedToken ?? "")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(Cyber.text)
            Spacer()
            Button { state.dismissWord() } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(Cyber.dim)
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private var loading: some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small).tint(Cyber.magenta)
            Text("辞書データを取得中…")
                .font(Cyber.mono).foregroundStyle(Cyber.dim)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func content(_ d: WordDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Phonetics row
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    pill(d.ipa, color: Cyber.cyan)
                    pill(d.stress, color: Cyber.amber)
                    pill(d.pos, color: Cyber.green)
                    Button {
                        speech.speak(d.word, lang: .english, rate: 0.4)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .foregroundStyle(Cyber.cyan).neonGlow(Cyber.cyan, radius: 4)
                    }.buttonStyle(.plain).help("発音")
                }

                Text(d.meaning_ja)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Cyber.text)

                section("EXAMPLES", color: Cyber.cyan) {
                    ForEach(d.examples) { ex in exampleRow(ex) }
                }

                section("ALTERNATIVES", color: Cyber.magenta) {
                    if state.rebuilding {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small).tint(Cyber.magenta)
                            Text("文章を再構築中…").font(Cyber.mono).foregroundStyle(Cyber.dim)
                        }
                    }
                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(d.alternatives) { alt in
                            altChip(alt)
                        }
                    }
                }
            }
            .padding(16)
        }
        .frame(maxHeight: 320)
    }

    private func pill(_ s: String, color: Color) -> some View {
        Text(s)
            .font(.system(.callout, design: .monospaced))
            .foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(color.opacity(0.6), lineWidth: 1))
    }

    private func exampleRow(_ ex: WordDetail.Example) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top, spacing: 8) {
                Text("▸").foregroundStyle(Cyber.cyan)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ex.en).foregroundStyle(Cyber.text)
                        .font(.system(.callout, design: .rounded))
                    Text(ex.ja).foregroundStyle(Cyber.dim)
                        .font(.system(size: 11, design: .rounded))
                }
                Spacer(minLength: 0)
                Button { speech.speak(ex.en, lang: .english) } label: {
                    Image(systemName: "speaker.wave.2").foregroundStyle(Cyber.cyan)
                }.buttonStyle(.plain)
            }
        }
    }

    private func altChip(_ alt: WordDetail.Alternative) -> some View {
        Button {
            state.applyAlternative(alt.word)
        } label: {
            VStack(alignment: .leading, spacing: 1) {
                Text(alt.word)
                    .font(.system(.callout, design: .monospaced).weight(.medium))
                    .foregroundStyle(Cyber.magenta)
                Text(alt.nuance_ja)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(Cyber.dim)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Cyber.magenta.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(state.rebuilding)
        .help("クリックで「\(state.focusedToken ?? "")」を置き換えて文を再構築")
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, color: Color, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, design: .monospaced).weight(.bold))
                .tracking(2)
                .foregroundStyle(color.opacity(0.8))
            content()
        }
    }
}
