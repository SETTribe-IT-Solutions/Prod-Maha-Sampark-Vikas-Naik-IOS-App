import UIKit

class DownloadManager: NSObject, URLSessionDownloadDelegate {
    static let shared = DownloadManager()
    
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()
    
    func downloadFile(from url: URL) {
        let task = session.downloadTask(with: url)
        task.resume()
    }
    
    // Called when download finishes
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let fileManager = FileManager.default
        let fileName = downloadTask.originalRequest?.url?.lastPathComponent ?? UUID().uuidString
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destinationURL = documentsURL.appendingPathComponent(fileName)
        
        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: location, to: destinationURL)
            print("✅ File downloaded to: \(destinationURL.path)")
        } catch {
            print("❌ Error saving file: \(error.localizedDescription)")
        }
    }

    // Called when task completes (whether with success or failure)
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("❌ Download failed: \(error.localizedDescription)")
        } else {
            print("✅ Download completed.")
        }
    }
}
