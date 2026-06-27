import Foundation

/// Thin async client for the Anthropic Messages API.
struct ClaudeClient {
    var apiKey: String
    var model: String

    enum ClientError: LocalizedError {
        case noKey
        case http(Int, String)
        case badResponse
        case parse(String)

        var errorDescription: String? {
            switch self {
            case .noKey:               return "APIキーが設定されていません。⚙ 設定から登録してください。"
            case .http(let c, let m):  return "API エラー (\(c)): \(m)"
            case .badResponse:         return "サーバーから不正な応答が返りました。"
            case .parse(let s):        return "応答の解析に失敗しました: \(s)"
            }
        }
    }

    // MARK: - Public operations

    /// Translate `text` from `src` into `dst`. English output is calibrated to CEFR B2.
    func translate(_ text: String, from src: Lang, to dst: Lang) async throws -> TranslationResult {
        let system = """
        You are a precise, natural EN⇄JA translator serving a CEFR B2 English learner.
        When translating INTO English: produce natural, idiomatic English calibrated to CEFR B2 —
        clear and correct, avoiding rare/advanced vocabulary, obscure idioms and overly complex syntax.
        When translating INTO Japanese: produce natural, fluent Japanese.
        Preserve meaning, tone and line breaks. Output ONLY a JSON object, no prose, no code fences.
        """
        let user = """
        Translate the following text from \(src.longName) to \(dst.longName).
        Return JSON exactly: {"translation": string, "note": string}
        - "note": a short Japanese note (max ~20 chars) on any nuance/ambiguity, or "" if none.
        TEXT:
        \"\"\"
        \(text)
        \"\"\"
        """
        let raw = try await send(system: system, user: user, maxTokens: 2048)
        return try decodeJSON(TranslationResult.self, from: raw)
    }

    /// Dictionary detail for one English `word` as used in `context`.
    func wordDetail(word: String, context: String) async throws -> WordDetail {
        let system = """
        You are an English vocabulary coach for a CEFR B2 Japanese learner.
        Output ONLY a JSON object, no prose, no code fences.
        """
        let user = """
        For the English word "\(word)" as used in this sentence:
        \"\"\"
        \(context)
        \"\"\"
        Return JSON exactly:
        {
          "word": "\(word)",
          "ipa": "IPA transcription inside slashes, e.g. /ɪɡˈzɑːmpəl/",
          "stress": "syllabified with the STRESSED syllable in CAPS, e.g. ex-AM-ple",
          "pos": "part of speech in this context (English)",
          "meaning_ja": "concise Japanese meaning IN THIS CONTEXT",
          "examples": [ {"en": "B2-level example sentence using the word", "ja": "日本語訳"} ],
          "alternatives": [ {"word": "synonym usable in place here", "nuance_ja": "ニュアンスの違い(日本語)"} ]
        }
        Provide exactly 3 examples (CEFR B2) and 4 alternatives.
        """
        let raw = try await send(system: system, user: user, maxTokens: 1600)
        return try decodeJSON(WordDetail.self, from: raw)
    }

    /// Replace `word` with `replacement` inside `text` and rebuild it naturally at B2.
    func replaceWord(in text: String, word: String, replacement: String) async throws -> String {
        struct Rebuilt: Codable { var rebuilt: String }
        let system = """
        You rewrite English text for a CEFR B2 learner. Output ONLY a JSON object, no code fences.
        """
        let user = """
        In the following English text, replace the word "\(word)" with "\(replacement)" and rewrite the
        affected sentence so it stays natural, grammatically correct and at CEFR B2. Keep the overall
        meaning and all other content unchanged. Adjust articles/conjugation as needed.
        Return JSON exactly: {"rebuilt": "the full updated text"}
        TEXT:
        \"\"\"
        \(text)
        \"\"\"
        """
        let raw = try await send(system: system, user: user, maxTokens: 2048)
        return try decodeJSON(Rebuilt.self, from: raw).rebuilt
    }

    // MARK: - Transport

    private struct APIRequest: Encodable {
        let model: String
        let max_tokens: Int
        let system: String
        let messages: [[String: String]]
    }
    private struct APIResponse: Decodable {
        struct Block: Decodable { let type: String; let text: String? }
        let content: [Block]
    }
    private struct APIError: Decodable {
        struct E: Decodable { let message: String }
        let error: E
    }

    private func send(system: String, user: String, maxTokens: Int) async throws -> String {
        guard !apiKey.isEmpty else { throw ClientError.noKey }
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "content-type")

        let body = APIRequest(
            model: model,
            max_tokens: maxTokens,
            system: system,
            messages: [["role": "user", "content": user]]
        )
        req.httpBody = try JSONEncoder().encode(body)
        req.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw ClientError.badResponse }
        guard (200..<300).contains(http.statusCode) else {
            let msg = (try? JSONDecoder().decode(APIError.self, from: data).error.message)
                ?? String(data: data, encoding: .utf8)
                ?? "unknown"
            throw ClientError.http(http.statusCode, msg)
        }
        let decoded = try JSONDecoder().decode(APIResponse.self, from: data)
        let text = decoded.content.compactMap { $0.text }.joined()
        guard !text.isEmpty else { throw ClientError.badResponse }
        return text
    }

    // MARK: - JSON extraction

    /// Decode a JSON object that may be wrapped in stray prose or ```json fences.
    private func decodeJSON<T: Decodable>(_ type: T.Type, from raw: String) throws -> T {
        let json = Self.extractJSONObject(raw) ?? raw
        guard let data = json.data(using: .utf8) else {
            throw ClientError.parse("encoding")
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw ClientError.parse(String(describing: error))
        }
    }

    /// Return the first balanced `{ ... }` block, ignoring braces inside strings.
    static func extractJSONObject(_ s: String) -> String? {
        let chars = Array(s)
        guard let start = chars.firstIndex(of: "{") else { return nil }
        var depth = 0
        var inString = false
        var escaped = false
        var i = start
        while i < chars.count {
            let c = chars[i]
            if inString {
                if escaped { escaped = false }
                else if c == "\\" { escaped = true }
                else if c == "\"" { inString = false }
            } else {
                if c == "\"" { inString = true }
                else if c == "{" { depth += 1 }
                else if c == "}" {
                    depth -= 1
                    if depth == 0 { return String(chars[start...i]) }
                }
            }
            i += 1
        }
        return nil
    }
}
