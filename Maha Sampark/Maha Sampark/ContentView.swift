import SwiftUI
import Network

struct ContentView: View {
    @State private var isLoading = true
    @State private var showAlert = false
    @State private var alertMessage = ""
    @Environment(\.scenePhase) private var scenePhase
    private let networkMonitor = NWPathMonitor()
    
    var body: some View {
        ZStack {
            WebView(isLoading: $isLoading,
                   url: URL(string: "https://mahasampark.in")!)
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
}
