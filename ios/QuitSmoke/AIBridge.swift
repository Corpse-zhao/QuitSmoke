import Foundation
import WebKit

/// 网页里 fetch 会被 CORS 拦（该接口预检直接 403），所以 AI 请求走原生 URLSession。
/// 页面通过 window.webkit.messageHandlers.ai 发起，原生回来后调用 window.__aiReply(id, text, ok)。
final class AIBridge: NSObject, WKScriptMessageHandler {

    weak var webView: WKWebView?
    private var retried = Set<String>()

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let id = body["id"] as? String,
              let urlString = body["url"] as? String,
              let url = URL(string: urlString) else { return }

        let key = (body["key"] as? String) ?? ""

        // kind == "models"：拉取可用模型列表
        if (body["kind"] as? String) == "models" {
            fetchModels(id: id, url: url, key: key)
            return
        }

        let messages = (body["messages"] as? [[String: Any]]) ?? []

        var payload: [String: Any] = [
            "messages": messages,
            "temperature": (body["temperature"] as? Double) ?? 1.0,
            "max_tokens": (body["maxTokens"] as? Int) ?? 120
        ]
        if let model = body["model"] as? String, !model.isEmpty {
            payload["model"] = model
        }

        request(url: url, key: key, payload: payload) { [weak self] text, status in
            guard let self = self else { return }
            // 网关并发/限流时重试一次
            if text == nil && (status == 429 || status == 503) && !self.retried.contains(id) {
                self.retried.insert(id)
                DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
                    self.request(url: url, key: key, payload: payload) { text2, _ in
                        self.reply(id: id, text: text2)
                    }
                }
                return
            }
            self.reply(id: id, text: text)
        }
    }

    /// 拉模型列表：把原始 JSON 原样交给页面解析
    private func fetchModels(id: String, url: URL, key: String) {
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = 15
        if !key.isEmpty {
            req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        URLSession.shared.dataTask(with: req) { data, _, _ in
            let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let js = "window.__aiModels(\(self.jsLiteral(id)), \(self.jsLiteral(body)));"
                self.webView?.evaluateJavaScript(js, completionHandler: nil)
            }
        }.resume()
    }

    private func request(url: URL,
                         key: String,
                         payload: [String: Any],
                         completion: @escaping (String?, Int) -> Void) {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 20
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !key.isEmpty {
            req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload, options: [])

        URLSession.shared.dataTask(with: req) { data, response, _ in
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            var text: String?
            if let data = data,
               let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let msg = choices.first?["message"] as? [String: Any],
               let content = msg["content"] as? String {
                let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { text = trimmed }
            }
            completion(text, status)
        }.resume()
    }

    private func reply(id: String, text: String?) {
        let ok = (text != nil)
        let js = "window.__aiReply(\(jsLiteral(id)), \(jsLiteral(text ?? "")), \(ok));"
        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript(js, completionHandler: nil)
        }
    }

    /// 生成安全的 JS 字符串字面量
    private func jsLiteral(_ value: String) -> String {
        if let data = try? JSONSerialization.data(withJSONObject: [value], options: []),
           let text = String(data: data, encoding: .utf8),
           text.hasPrefix("["), text.hasSuffix("]") {
            return String(text.dropFirst().dropLast())
        }
        return "\"\""
    }
}
