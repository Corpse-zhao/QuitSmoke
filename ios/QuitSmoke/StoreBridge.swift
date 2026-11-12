import Foundation
import WebKit

/// 网页数据落盘到 UserDefaults 的通道。
/// WKWebView 里 localStorage 可能被限制，这条通道保证记录不会丢。
/// 页面启动时注入 window.__NATIVE_STATE__，每次保存时回写。
final class StoreBridge: NSObject, WKScriptMessageHandler {

    private let defaultsKey = "quit.smoke.webstate"
    private let lock = NSLock()

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let key = body["key"] as? String,
              let value = body["value"] as? String else { return }

        lock.lock()
        var all = loadAll()
        all[key] = value
        saveAll(all)
        lock.unlock()
    }

    func preloadScript() -> WKUserScript {
        lock.lock()
        let all = loadAll()
        lock.unlock()

        var json = "{}"
        if let data = try? JSONSerialization.data(withJSONObject: all, options: []),
           let text = String(data: data, encoding: .utf8) {
            json = text
        }
        let source = "window.__NATIVE_STATE__ = \(json);"
        return WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true)
    }

    private func loadAll() -> [String: String] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return [:] }
        if let obj = try? JSONSerialization.jsonObject(with: data, options: []),
           let dict = obj as? [String: String] {
            return dict
        }
        return [:]
    }

    private func saveAll(_ all: [String: String]) {
        if let data = try? JSONSerialization.data(withJSONObject: all, options: []) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
            UserDefaults.standard.synchronize()
        }
    }
}
