import Foundation
import WebKit

/// 把 app://local/xxx 映射到 App 包内的资源文件。
/// 用自定义 scheme（带 host）而不是 file://，页面才有正常的 origin，localStorage 才能用。
final class BundleSchemeHandler: NSObject, WKURLSchemeHandler {

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else { return }

        var path = url.path
        if path.isEmpty || path == "/" {
            path = "/index.html"
        }
        let filename = (path as NSString).lastPathComponent
        var ext = (filename as NSString).pathExtension
        if ext.isEmpty { ext = "html" }
        let base = (filename as NSString).deletingPathExtension

        guard let fileURL = Bundle.main.url(forResource: base, withExtension: ext),
              let data = try? Data(contentsOf: fileURL) else {
            respond(task: urlSchemeTask, url: url, status: 404, mime: "text/plain", body: Data("Not Found".utf8))
            return
        }

        respond(task: urlSchemeTask, url: url, status: 200, mime: mimeType(ext), body: data)
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        // 单次响应，无需处理取消
    }

    private func respond(task: WKURLSchemeTask, url: URL, status: Int, mime: String, body: Data) {
        guard let response = HTTPURLResponse(url: url,
                                             statusCode: status,
                                             httpVersion: "HTTP/1.1",
                                             headerFields: [
                                                "Content-Type": mime,
                                                "Content-Length": String(body.count),
                                                "Cache-Control": "no-store"
                                             ]) else { return }
        task.didReceive(response)
        task.didReceive(body)
        task.didFinish()
    }

    private func mimeType(_ ext: String) -> String {
        switch ext.lowercased() {
        case "html", "htm": return "text/html; charset=utf-8"
        case "js":          return "application/javascript; charset=utf-8"
        case "css":         return "text/css; charset=utf-8"
        case "json":        return "application/json; charset=utf-8"
        case "png":         return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "svg":         return "image/svg+xml"
        case "woff", "woff2": return "font/woff2"
        default:            return "application/octet-stream"
        }
    }
}
