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
        
        if let apnsToken = UserDefaults.standard.string(forKey: "APNsToken") {
            queryItems.append(URLQueryItem(name: "pushToken", value: apnsToken))
        }
        if let fcmToken = UserDefaults.standard.string(forKey: "FCMToken") {
            queryItems.append(URLQueryItem(name: "fcmToken", value: fcmToken))
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
            setupNetworkMonitoring()
            requestNotificationPermission()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("APNsTokenUpdated"))) { notification in
            if let token = notification.userInfo?["token"] as? String {
                updateURLWithToken(token: token, isFCM: false)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("FCMTokenUpdated"))) { notification in
            if let token = notification.userInfo?["token"] as? String {
                updateURLWithToken(token: token, isFCM: true)
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
                // App became inactive
            } else if newPhase == .background {
                // App moved to background
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
    
    private func updateURLWithToken(token: String, isFCM: Bool) {
        var components = URLComponents(url: webViewURL, resolvingAgainstBaseURL: true)
        var queryItems = components?.queryItems ?? []
        
        let paramName = isFCM ? "fcmToken" : "pushToken"
        
        // Only update and reload if the token is actually new or changed
        if let existingIndex = queryItems.firstIndex(where: { $0.name == paramName }) {
            if queryItems[existingIndex].value == token {
                return // Token is unchanged, do not reload
            }
            queryItems[existingIndex].value = token
        } else {
            queryItems.append(URLQueryItem(name: paramName, value: token))
        }
        
        components?.queryItems = queryItems
        if let newURL = components?.url {
            DispatchQueue.main.async {
                self.webViewURL = newURL
                print("🔄 Updated URL with \(paramName): \(newURL.absoluteString)")
            }
        }
    }
}
