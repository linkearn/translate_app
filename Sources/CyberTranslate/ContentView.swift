import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @ObservedObject var speech = SpeechManager.shared
    @State private var showSettings = false

    var body: some View {
        ZStack {
            background
            VStack(spacing: 14) {
                header
                if !state.hasKey { apiKeyBanner }
                languageBar
                inputPanel
                actionRow
                if let err = state.errorMessage { errorBar(err) }
                ScrollView {
                    VStack(spacing: 14) {
                        OutputView()
                        if state.focusedToken != nil {
                            WordDetailView()
                        }
                    }
                }
            }
            .padding(18)
        }
        .frame(minWidth: 640, minHeight: 720)
        .animation(.easeOut(duration: 0.2), value: state.focusedToken)
        .animation(.easeOut(duration: 0.2), value: state.wordDetail?.id)
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(state)
        }
        .onAppear { state.refreshKeyState() }
    }

    // MARK: - Pieces

    private var background: some View {
        ZStack {
            Cyber.bg.ignoresSafeArea()
            LinearGradient(
                colors: [Cyber.magenta.opacity(0.10), .clear, Cyber.cyan.opacity(0.10)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ).ignoresSafeArea()
            GridShape().stroke(Cyber.cyan.opacity(0.05), lineWidth: 0.5).ignoresSafeArea()
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundStyle(Cyber.cyan).neonGlow(Cyber.cyan)
                (Text("CYBER").foregroundStyle(Cyber.cyan)
                 + Text("·TRANSLATE").foregroundStyle(Cyber.magenta))
                    .neonGlow(Cyber.cyan, radius: 4)
            }
            .font(.system(.title2, design: .monospaced).weight(.heavy))
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill").foregroundStyle(Cyber.text)
                    .font(.title3)
            }.buttonStyle(.plain).help("設定")
        }
    }

    private var apiKeyBanner: some View {
        Button { showSettings = true } label: {
            HStack {
                Image(systemName: "key.fill")
                Text("Anthropic API キーが未設定です。クリックして登録 →")
                    .font(.system(.callout, design: .monospaced))
                Spacer()
            }
            .foregroundStyle(Cyber.amber)
            .padding(12)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Cyber.amber.opacity(0.6), lineWidth: 1))
        }.buttonStyle(.plain)
    }

    private var languageBar: some View {
        HStack(spacing: 10) {
            // Source selector (auto / EN / JA)
            HStack(spacing: 6) {
                langButton("AUTO", active: state.source == .auto) { state.setSource(.auto) }
                langButton("EN", active: state.source == .fixed(.english)) { state.setSource(.fixed(.english)) }
                langButton("JA", active: state.source == .fixed(.japanese)) { state.setSource(.fixed(.japanese)) }
            }
            if state.source == .auto, let d = state.detected {
                Text("検出: \(d.nativeName)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Cyber.green)
            }
            Spacer()
            // Direction display
            HStack(spacing: 6) {
                Text(state.effectiveSource.display).foregroundStyle(Cyber.cyan)
                Image(systemName: "arrow.right").foregroundStyle(Cyber.dim)
                Text(state.effectiveTarget.display).foregroundStyle(Cyber.magenta)
            }
            .font(.system(.callout, design: .monospaced).weight(.bold))

            Button { state.swapDirection() } label: {
                Image(systemName: "arrow.up.arrow.down").foregroundStyle(Cyber.text)
            }.buttonStyle(.plain).help("入出力を入れ替え").disabled(state.outputText.isEmpty)
        }
    }

    private func langButton(_ title: String, active: Bool, _ action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(GhostButtonStyle(tint: Cyber.cyan, active: active))
    }

    private var inputPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("INPUT", systemImage: "arrow.up.right.circle")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Cyber.cyan)
                Spacer()
                speakInputButton
                Text("\(state.inputText.count)")
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(Cyber.dim)
            }
            TextEditor(text: $state.inputText)
                .font(.system(.title3, design: .rounded))
                .foregroundStyle(Cyber.text)
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(height: 120)
                .neonPanel(Cyber.cyan.opacity(0.5), glow: Cyber.cyan)
                .onChange(of: state.inputText) { _, _ in
                    if state.source == .auto { state.detectNow() }
                }
        }
    }

    private var speakInputButton: some View {
        Button {
            let lang = state.effectiveSource
            if speech.speaking { speech.stop() } else { speech.speak(state.inputText, lang: lang) }
        } label: {
            Image(systemName: "speaker.wave.2.fill").foregroundStyle(Cyber.cyan)
        }.buttonStyle(.plain).disabled(state.inputText.isEmpty).help("入力を読み上げ")
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button {
                state.translate()
            } label: {
                HStack(spacing: 8) {
                    if state.isTranslating {
                        ProgressView().controlSize(.small).tint(Cyber.bg)
                    } else {
                        Image(systemName: "bolt.fill")
                    }
                    Text(state.isTranslating ? "TRANSLATING…" : "TRANSLATE")
                }
            }
            .buttonStyle(CyberButtonStyle(tint: Cyber.cyan))
            .disabled(state.isTranslating || state.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .keyboardShortcut(.return, modifiers: .command)

            Button("CLEAR") { state.clearAll() }
                .buttonStyle(GhostButtonStyle(tint: Cyber.dim))

            Spacer()

            HStack(spacing: 6) {
                Circle().fill(state.autoCapture ? Cyber.green : Cyber.dim)
                    .frame(width: 7, height: 7)
                Text(state.autoCapture ? "AUTO-CAPTURE ON" : "⌃⌥T で取込")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(state.autoCapture ? Cyber.green : Cyber.dim)
            }
        }
    }

    private func errorBar(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message).font(.system(size: 11, design: .monospaced))
            Spacer()
            Button { state.errorMessage = nil } label: {
                Image(systemName: "xmark")
            }.buttonStyle(.plain)
        }
        .foregroundStyle(Cyber.magenta)
        .padding(10)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Cyber.magenta.opacity(0.6), lineWidth: 1))
    }
}

/// Faint background grid.
struct GridShape: Shape {
    var step: CGFloat = 34
    func path(in rect: CGRect) -> Path {
        var p = Path()
        var x: CGFloat = 0
        while x < rect.width { p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: rect.height)); x += step }
        var y: CGFloat = 0
        while y < rect.height { p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: rect.width, y: y)); y += step }
        return p
    }
}
