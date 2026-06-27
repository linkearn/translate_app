import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var keyInput = ""
    @State private var saved = false
    @State private var axTrusted = AXIsProcessTrusted()

    private let models = [
        "claude-sonnet-4-6",
        "claude-opus-4-8",
        "claude-haiku-4-5-20251001"
    ]

    var body: some View {
        ZStack {
            Cyber.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("// SETTINGS")
                        .font(.system(.title2, design: .monospaced).weight(.bold))
                        .foregroundStyle(Cyber.cyan)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Cyber.dim).font(.title3)
                    }.buttonStyle(.plain)
                }

                // API KEY
                group("ANTHROPIC API KEY", color: Cyber.cyan) {
                    SecureField("sk-ant-...", text: $keyInput)
                        .textFieldStyle(.plain)
                        .font(Cyber.mono)
                        .foregroundStyle(Cyber.text)
                        .padding(10)
                        .neonPanel(Cyber.cyan.opacity(0.4))
                    HStack {
                        Button("保存") {
                            KeychainStore.save(keyInput.trimmingCharacters(in: .whitespacesAndNewlines))
                            state.refreshKeyState()
                            saved = true
                            keyInput = ""
                        }.buttonStyle(CyberButtonStyle(tint: Cyber.green))
                        if state.hasKey {
                            Label("登録済み", systemImage: "checkmark.shield.fill")
                                .foregroundStyle(Cyber.green).font(.system(.caption, design: .monospaced))
                            Button("削除") {
                                KeychainStore.delete(); state.refreshKeyState(); saved = false
                            }.buttonStyle(GhostButtonStyle(tint: Cyber.magenta))
                        }
                        Spacer()
                        if saved { Text("✓ 保存しました").foregroundStyle(Cyber.green).font(.caption) }
                    }
                    Text("キーは macOS キーチェーンにローカル保存されます。")
                        .font(.system(size: 10, design: .monospaced)).foregroundStyle(Cyber.dim)
                }

                // MODEL
                group("MODEL", color: Cyber.magenta) {
                    Picker("", selection: $state.model) {
                        ForEach(models, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    Text("翻訳・辞書・文再構築に使用するモデル。Sonnet が速度と品質のバランス◎")
                        .font(.system(size: 10, design: .monospaced)).foregroundStyle(Cyber.dim)
                }

                // CAPTURE
                group("CAPTURE", color: Cyber.green) {
                    Toggle(isOn: $state.autoCapture) {
                        Text("クリップボード自動取込（コピーで即翻訳）")
                            .font(.system(.callout, design: .monospaced)).foregroundStyle(Cyber.text)
                    }.tint(Cyber.green)

                    HStack(spacing: 8) {
                        Image(systemName: axTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(axTrusted ? Cyber.green : Cyber.amber)
                        Text(axTrusted
                             ? "アクセシビリティ許可済み（⌃⌥Tで選択範囲を自動コピー）"
                             : "選択範囲の自動コピーには「アクセシビリティ」許可が必要")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(axTrusted ? Cyber.green : Cyber.amber)
                    }
                    if !axTrusted {
                        Button("アクセシビリティを許可") {
                            HotKeyManager.ensureAccessibility(prompt: true)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                axTrusted = AXIsProcessTrusted()
                            }
                        }.buttonStyle(GhostButtonStyle(tint: Cyber.amber))
                    }
                    Text("グローバルショートカット: ⌃⌥T（他アプリで文字選択中に押すと取り込み→翻訳）")
                        .font(.system(size: 10, design: .monospaced)).foregroundStyle(Cyber.dim)
                }

                Spacer()
                Text("LEVEL: B2 — 英訳は CEFR B2 に合わせて生成されます。")
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(Cyber.dim)
            }
            .padding(24)
        }
        .frame(width: 560, height: 620)
    }

    @ViewBuilder
    private func group<Content: View>(_ title: String, color: Color, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 10, design: .monospaced).weight(.bold)).tracking(2)
                .foregroundStyle(color)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .neonPanel(color.opacity(0.4), glow: color)
    }
}
