import UIKit
import WebKit

final class WebViewController: UIViewController {

    private var webView: WKWebView!
    private let store = StoreBridge()
    private let ai = AIBridge()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor(red: 0.965, green: 0.98, blue: 0.973, alpha: 1.0)

        let controller = WKUserContentController()
        controller.add(store, name: "store")
        controller.add(ai, name: "ai")
        controller.addUserScript(store.preloadScript())

        let config = WKWebViewConfiguration()
        config.userContentController = controller
        config.setURLSchemeHandler(BundleSchemeHandler(), forURLScheme: "app")
        config.allowsInlineMediaPlayback = true
        config.websiteDataStore = .default()

        let web = WKWebView(frame: .zero, configuration: config)
        web.translatesAutoresizingMaskIntoConstraints = false
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.scrollView.showsVerticalScrollIndicator = false
        web.scrollView.bounces = true
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.backgroundColor = .clear
        if #available(iOS 16.4, *) {
            web.isInspectable = true
        }

        view.addSubview(web)
        NSLayoutConstraint.activate([
            web.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            web.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            web.topAnchor.constraint(equalTo: view.topAnchor),
            web.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        webView = web
        ai.webView = web

        if let url = URL(string: "app://local/index.html") {
            web.load(URLRequest(url: url))
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .default
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        return false
    }
}
