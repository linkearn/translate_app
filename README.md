# Cyber·Translate

ローカルでビルドして使う、ネイティブ macOS 翻訳アプリ（英訳 ⇄ 日訳）。
サイバーパンク調 UI、選択テキストの自動取込、発音記号・例文・代替単語、読み上げ対応。

## 機能

- **自動言語判定** — 入力が英語か日本語かを判定し、もう一方へ翻訳（`AUTO`）。判定が誤る場合は `EN` / `JA` を手動指定可。
- **選択 → コピー → 自動取込** — 他アプリで文字を選択し **⌃⌥T**（Option+Command+C）を押すと、選択範囲を取り込んで即翻訳。`設定 > CAPTURE` で「クリップボード自動取込」をオンにすると、ふつうのコピー（⌘C）でも自動翻訳。
- **CEFR B2 に最適化** — 英訳は B2 レベルの自然で明快な英語で生成。
- **英単語の詳細（出力が英語のとき）** — 出力の単語をクリックすると、IPA 発音記号・アクセント・品詞・日本語訳・B2 例文・**代替単語**を表示。代替単語をクリックすると、その語に置き換えて文章を自動再構築。
- **読み上げ** — スピーカーマークで入力／出力／例文を音声再生（オフライン）。

## 必要なもの

- macOS 14 以降（開発機は macOS 26 / Apple Silicon で確認）
- Xcode（コマンドラインツール含む）
- Anthropic API キー（翻訳・辞書・再構築に使用）

## ビルドと起動

```bash
cd CyberTranslate
./build.sh run      # ビルドして起動（または ./build.sh で dist/CyberTranslate.app を生成）
```

`dist/CyberTranslate.app` を `/Applications` にドラッグすれば通常アプリとして使えます。

開発時は `swift build && swift run` でも起動できます（バンドル外実行のため、アクセシビリティ許可は app バンドル版で行ってください）。

## 初回セットアップ

1. アプリ右上の ⚙ から **設定** を開く。
2. **ANTHROPIC API KEY** に `sk-ant-...` を入力して「保存」。キーは macOS キーチェーンにローカル保存されます（外部送信は Anthropic API の翻訳リクエストのみ）。
3. `MODEL` を選択（既定は `claude-sonnet-4-6`：速度と品質のバランス）。
4. 選択範囲の自動コピー（⌃⌥T）を使うには `CAPTURE` で **アクセシビリティを許可**。
   - 許可しない場合でも、⌃⌥T は「現在クリップボードにある内容」を取り込みます。

## 使い方

- テキストを入力して **TRANSLATE**（または ⌘Return）。
- 他アプリで選択中に **⌃⌥T** → 自動で取り込み翻訳し、ウィンドウが前面に。
- 出力が英語なら単語をクリック → 詳細パネル。代替単語クリックで文を再構築。
- メニューバーのアイコンから「クリップボードを翻訳」「ウィンドウ表示」も可能。ウィンドウを閉じても常駐し続けます（⌃⌥T 待受のため）。終了はメニューバー → 終了。

## 構成

| ファイル | 役割 |
|---|---|
| `CyberTranslateApp.swift` | エントリポイント、メニューバー、常駐 |
| `AppState.swift` | 状態管理・翻訳/辞書/再構築のオーケストレーション |
| `ClaudeClient.swift` | Anthropic Messages API クライアント＋プロンプト |
| `HotKeyManager.swift` | グローバル ⌃⌥T（Carbon）＋選択コピー＋クリップボード監視 |
| `Models.swift` | 言語判定（NaturalLanguage）・データモデル |
| `SpeechManager.swift` | 読み上げ（AVSpeechSynthesizer、オフライン） |
| `KeychainStore.swift` | API キーのローカル保存 |
| `ContentView` / `OutputView` / `WordDetailView` / `SettingsView` | UI |
| `Theme.swift` / `FlowLayout.swift` | サイバー調スタイル・単語チップ折返し |

## 注意

- 翻訳・辞書・再構築は Anthropic API を呼ぶためネットワークと API 利用料が発生します。
- アプリ自体はローカル動作で、入力テキストは翻訳リクエスト以外に外部送信しません。
