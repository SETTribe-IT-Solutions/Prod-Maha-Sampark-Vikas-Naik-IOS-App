import UIKit
import WebKit

class WebViewCoordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, WKDownloadDelegate, WKUIDelegate {
    var parent: WebView
    var hasLoaded = false
    var lastLoadedURL: URL?
    weak var webView: WKWebView?
    private var completionHandler: (([URL]?) -> Void)? // Moved here

    init(_ parent: WebView) {
        self.parent = parent
        super.init()
        setupNotificationObservers()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleAPNsTokenUpdate(_:)),
                                               name: Notification.Name("APNsTokenUpdated"),
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleFCMTokenUpdate(_:)),
                                               name: Notification.Name("FCMTokenUpdated"),
                                               object: nil)
    }
    
    @objc private func handleAPNsTokenUpdate(_ notification: Notification) {
        if let userInfo = notification.userInfo, let token = userInfo["token"] as? String {
            injectTokenToWebView(token: token, tokenType: "apns")
        }
    }
    
    @objc private func handleFCMTokenUpdate(_ notification: Notification) {
        if let userInfo = notification.userInfo, let token = userInfo["token"] as? String {
            injectTokenToWebView(token: token, tokenType: "fcm")
        }
    }
    
    private func injectTokenToWebView(token: String, tokenType: String) {
        DispatchQueue.main.async { [weak self] in
            guard let webView = self?.webView else { return }
            
            let jsMethod = tokenType == "apns" ? "window.setPushToken" : "window.setFcmToken"
            let jsString = "if (typeof \(jsMethod) === 'function') { \(jsMethod)('\(token)'); } else { console.log('\(jsMethod) not found, but token obtained: \(token)'); }"
            
            webView.evaluateJavaScript(jsString) { (result, error) in
                if let error = error {
                    print("❌ Error injecting \(tokenType) token: \(error.localizedDescription)")
                } else {
                    print("✅ Successfully injected \(tokenType) token to WebView")
                }
            }
        }
    }

    // MARK: - JavaScript Message Handling
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "shareDetails" {
            if let dict = message.body as? [String: String],
               let name = dict["name"],
               let designation = dict["designation"],
               let phone = dict["phone"] {
                shareDetails(name: name, designation: designation, phone: phone)
            }
        }
        
        if message.name == "customPicker" {
                if message.body as? String == "photoLibrary" {
                    let imagePicker = UIImagePickerController()
                    imagePicker.delegate = self
                    imagePicker.sourceType = .photoLibrary
                    imagePicker.mediaTypes = ["public.image"]
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first,
                       let vc = window.rootViewController {
                        vc.present(imagePicker, animated: true, completion: nil)
                    }
                }
            }

        if message.name == "getNumber" {
            getPhoneNumber()
        }
    }

    private func shareDetails(name: String, designation: String, phone: String) {
        let shareText = "Name: \(name)\nDesignation: \(designation)\nPhone: \(phone)"
        let av = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let vc = window.rootViewController {
            av.popoverPresentationController?.sourceView = vc.view
            vc.present(av, animated: true)
        }
    }

    private func getPhoneNumber() {
        // Placeholder for getPhoneNumber logic
    }

    // MARK: - Navigation
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        parent.isLoading = true
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        parent.isLoading = false
        webView.scrollView.refreshControl?.endRefreshing()
        
        // Inject saved tokens if they exist when webView finishes loading
        if let apnsToken = UserDefaults.standard.string(forKey: "APNsToken") {
            injectTokenToWebView(token: apnsToken, tokenType: "apns")
        }
        if let fcmToken = UserDefaults.standard.string(forKey: "FCMToken") {
            injectTokenToWebView(token: fcmToken, tokenType: "fcm")
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        parent.isLoading = false
        webView.scrollView.refreshControl?.endRefreshing()
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        if navigationAction.navigationType == .linkActivated,
           !url.absoluteString.starts(with: "https://mahasampark.in") {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }

    // MARK: - Refresh
    @objc func refresh(_ sender: UIRefreshControl) {
        webView?.reload()
        sender.endRefreshing()
        hasLoaded = true
    }

    // MARK: - WKDownloadDelegate (iOS 14+)
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }

    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destinationURL = documentsPath.appendingPathComponent(suggestedFilename)
        print("📥 Saving to: \(destinationURL.path)")
        completionHandler(destinationURL)
    }

    func download(_ download: WKDownload, didFinishWithError error: Error?) {
        if let error = error {
            print("❌ Download failed: \(error.localizedDescription)")
        } else {
            print("✅ Download finished successfully")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("DownloadComplete"), object: nil)
            }
        }
    }

    // MARK: - WKUIDelegate
    @available(iOS 18.4, *)
    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        self.completionHandler = completionHandler // Assign to the stored property

        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = .photoLibrary
        imagePicker.allowsEditing = false
        imagePicker.mediaTypes = ["public.image"] // Restrict to images only

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let vc = window.rootViewController {
            vc.present(imagePicker, animated: true, completion: nil)
        }
    }
}

// MARK: - UIImagePickerControllerDelegate
extension WebViewCoordinator: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)

        if let imageURL = info[.imageURL] as? URL {
            completionHandler?([imageURL])
        } else if let image = info[.originalImage] as? UIImage,
                  let imageData = image.jpegData(compressionQuality: 1.0) {
            let tempDirectory = FileManager.default.temporaryDirectory
            let tempFileURL = tempDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
            
            do {
                try imageData.write(to: tempFileURL)
                completionHandler?([tempFileURL])
            } catch {
                print("❌ Failed to save image to temporary file: \(error.localizedDescription)")
                completionHandler?(nil)
            }
        } else {
            completionHandler?(nil)
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
        completionHandler?(nil)
    }
}
