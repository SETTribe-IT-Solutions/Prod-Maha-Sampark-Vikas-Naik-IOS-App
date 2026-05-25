import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    @Binding var isLoading: Bool
    var url: URL

    // Shared process pool ensures cookies persist across WebView recreations
    private static let sharedProcessPool = WKProcessPool()

    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let preferences = WKPreferences()
        preferences.javaScriptEnabled = true

        let configuration = WKWebViewConfiguration()
        configuration.preferences = preferences
        
        // Use shared process pool for cookie consistency
        configuration.processPool = WebView.sharedProcessPool
        
        // Use the default persistent data store (cookies saved to disk)
        let dataStore = WKWebsiteDataStore.default()
        configuration.websiteDataStore = dataStore
        
        // Accept all cookies
        HTTPCookieStorage.shared.cookieAcceptPolicy = .always
        
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
        
        // Restore any previously saved cookies into WKWebView before loading
        restoreCookies(into: dataStore) {
            let request = URLRequest(url: url)
            webView.load(request)
            context.coordinator.hasLoaded = true
            context.coordinator.lastLoadedURL = url
        }
        
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if context.coordinator.lastLoadedURL != url {
            let request = URLRequest(url: url)
            webView.load(request)
            context.coordinator.hasLoaded = true
            context.coordinator.lastLoadedURL = url
        }
    }
    
    // MARK: - Cookie Persistence
    
    /// Restore cookies from HTTPCookieStorage into WKWebsiteDataStore
    private func restoreCookies(into dataStore: WKWebsiteDataStore, completion: @escaping () -> Void) {
        let cookies = HTTPCookieStorage.shared.cookies ?? []
        let cookieStore = dataStore.httpCookieStore
        
        guard !cookies.isEmpty else {
            completion()
            return
        }
        
        let dispatchGroup = DispatchGroup()
        for cookie in cookies {
            dispatchGroup.enter()
            cookieStore.setCookie(cookie) {
                dispatchGroup.leave()
            }
        }
        dispatchGroup.notify(queue: .main) {
            print("🍪 Restored \(cookies.count) cookies into WKWebView")
            completion()
        }
    }
    
    /// Save cookies from WKWebsiteDataStore to HTTPCookieStorage (call on app background)
    static func saveCookies() {
        let dataStore = WKWebsiteDataStore.default()
        dataStore.httpCookieStore.getAllCookies { cookies in
            for cookie in cookies {
                HTTPCookieStorage.shared.setCookie(cookie)
            }
            print("🍪 Saved \(cookies.count) cookies to HTTPCookieStorage")
        }
    }
}

