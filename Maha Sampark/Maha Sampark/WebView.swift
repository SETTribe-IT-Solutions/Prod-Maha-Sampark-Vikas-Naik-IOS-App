import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    @Binding var isLoading: Bool
    var url: URL

    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let preferences = WKPreferences()
        
        // Deprecated in iOS 14, but works for older versions
        preferences.javaScriptEnabled = true

        let configuration = WKWebViewConfiguration()
        configuration.preferences = preferences
        configuration.userContentController.add(context.coordinator, name: "shareDetails")
        configuration.userContentController.add(context.coordinator, name: "getNumber")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        // Pull to refresh
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(context.coordinator, action: #selector(WebViewCoordinator.refresh(_:)), for: .valueChanged)
        webView.scrollView.refreshControl = refreshControl

        webView.scrollView.minimumZoomScale = 1.0
        webView.scrollView.maximumZoomScale = 1.0
        webView.scrollView.zoomScale = 1.0

        context.coordinator.webView = webView
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if !context.coordinator.hasLoaded {
            let request = URLRequest(url: url)
            webView.load(request)
            context.coordinator.hasLoaded = true
        }
    }
}
