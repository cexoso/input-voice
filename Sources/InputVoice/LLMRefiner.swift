import Foundation

class LLMRefiner {
    private let systemPrompt = """
You are a speech recognition post-processor. Your ONLY job is to fix obvious speech recognition errors.

Rules:
- Only fix clear recognition mistakes: homophones, technical terms incorrectly converted (e.g. 配森→Python, 杰森→JSON, 爪哇→Java, 哥图拔→Go to bar)
- NEVER rewrite, rephrase, polish, expand, or remove any content
- NEVER add punctuation, capitalization changes, or formatting unless clearly dictated
- If the text looks correct as-is, return it EXACTLY unchanged
- Return ONLY the corrected text, no explanations, no quotation marks, no extra characters

"""

    func refine(text: String, completion: @escaping (String) -> Void) {
        let apiBase = UserDefaults.standard.string(forKey: "llmAPIBase") ?? ""
        let apiKey = UserDefaults.standard.string(forKey: "llmAPIKey") ?? ""
        let model = UserDefaults.standard.string(forKey: "llmModel") ?? "gpt-4o-mini"

        guard !apiBase.isEmpty, !apiKey.isEmpty, !text.isEmpty else {
            completion(text)
            return
        }

        var urlString = apiBase
        if !urlString.hasSuffix("/") { urlString += "/" }
        urlString += "chat/completions"

        guard let url = URL(string: urlString) else {
            completion(text)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ],
            "max_tokens": 500,
            "temperature": 0.0
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            completion(text)
            return
        }
        request.httpBody = bodyData

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let first = choices.first,
                  let message = first["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                completion(text)
                return
            }
            let refined = content.trimmingCharacters(in: .whitespacesAndNewlines)
            completion(refined.isEmpty ? text : refined)
        }.resume()
    }

    func test(apiBase: String, apiKey: String, model: String, completion: @escaping (Bool, String) -> Void) {
        var urlString = apiBase
        if !urlString.hasSuffix("/") { urlString += "/" }
        urlString += "chat/completions"

        guard let url = URL(string: urlString) else {
            completion(false, "Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let body: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": "Reply with OK"]],
            "max_tokens": 5,
            "temperature": 0.0
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            completion(false, "JSON encoding failed")
            return
        }
        request.httpBody = bodyData

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(false, error.localizedDescription)
                return
            }
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                completion(true, "Connection successful")
            } else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                completion(false, "HTTP \(code)")
            }
        }.resume()
    }
}
