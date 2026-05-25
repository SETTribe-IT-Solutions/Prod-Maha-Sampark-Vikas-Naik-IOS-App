import SwiftUI
import Network

struct ContentView: View {
    @State private var isLoading = true
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var webViewURL: URL = {
        let baseUrl = "https://mahasampark.in"
        var components = URLComponents(string: baseUrl)
        var queryItems = [URLQueryItem]()
        
        if let fcmToken = UserDefaults.standard.string(forKey: "FCMToken") {
            queryItems.append(URLQueryItem(name: "token", value: fcmToken))
        }
        
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        
        return components?.url ?? URL(string: baseUrl)!
    }()
    
    @Environment(\.scenePhase) private var scenePhase
    private let networkMonitor = NWPathMonitor()
    
    var body: some View {
        ZStack {
            WebView(isLoading: $isLoading,
                   url: webViewURL)
                .edgesIgnoringSafeArea(.all)
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
            }
        }
        .onAppear {
            print("📎 Initial WebView URL: \(webViewURL.absoluteString)")
            setupNetworkMonitoring()
            requestNotificationPermission()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("FCMTokenUpdated"))) { notification in
            if let token = notification.userInfo?["token"] as? String {
                print("🔑 FCM Token received: \(token)")
                // Token is injected into WebView via JavaScript by WebViewCoordinator
                // No page reload needed
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("APNsTokenUpdated"))) { notification in
            if let token = notification.userInfo?["token"] as? String {
                print("🔑 APNs Token received: \(token)")
                // Token is injected into WebView via JavaScript by WebViewCoordinator
                // No page reload needed
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Alert"),
                  message: Text(alertMessage),
                  dismissButton: .default(Text("OK")))
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                // App became active
            } else if newPhase == .inactive {
                // Save cookies when app becomes inactive
                WebView.saveCookies()
            } else if newPhase == .background {
                // Save cookies when app moves to background
                WebView.saveCookies()
            }
        }
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                if path.status != .satisfied {
                    showAlert = true
                    alertMessage = "No internet connection"
                }
            }
        }
        networkMonitor.start(queue: DispatchQueue.global())
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                print("Notification permission granted: \(granted)")
            }
    }
}

