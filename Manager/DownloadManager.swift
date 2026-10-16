//
//  DownloadManager.swift
//  Ovra
//
//  Created by Ovra on 2/28/26.
//

import SwiftUI
import WebKit

/// Owns every download for the whole app. It is the WKDownloadDelegate itself:
/// WKDownload only holds its delegate weakly, so a per-tab delegate disappeared
/// as soon as the tab's web view was torn down and the download stalled.
final class DownloadManager: NSObject, ObservableObject, WKDownloadDelegate {
    static let shared = DownloadManager()
    
    @Published var downloads: [DownloadItem] = []
    @Published var hasActiveDownloads: Bool = false

    private var items: [ObjectIdentifier: DownloadItem] = [:]
    private var progressObservers: [ObjectIdentifier: NSKeyValueObservation] = [:]
    
    private override init() {}

    /// Called when a navigation turns into a download.
    func attach(_ download: WKDownload) {
        download.delegate = self
    }
    
    func addDownload(filename: String, url: URL?, download: WKDownload?) -> DownloadItem {
        let item = DownloadItem(filename: filename, url: url, download: download)
        DispatchQueue.main.async {
            self.downloads.insert(item, at: 0)
            self.updateActiveState()
            GuidedTipController.shared.showContextualTip(.downloads)
        }
        return item
    }
    
    func updateProgress(for item: DownloadItem, received: Int64, total: Int64) {
        DispatchQueue.main.async {
            guard item.state == .downloading else { return }
            item.receivedBytes = received
            if total > 0 { item.totalBytes = total }
        }
    }
    
    func markCompleted(_ item: DownloadItem, at url: URL?) {
        DispatchQueue.main.async {
            item.destinationURL = url
            if item.totalBytes > 0 { item.receivedBytes = item.totalBytes }
            else if let url, let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                item.receivedBytes = Int64(size)
                item.totalBytes = Int64(size)
            }
            item.state = .completed
            self.updateActiveState()
        }
    }
    
    func markFailed(_ item: DownloadItem, error: String, resumeData: Data?) {
        DispatchQueue.main.async {
            // A cancel also reports a failure; keep it as "Cancelled".
            if item.state != .cancelled {
                item.errorMessage = error
                item.state = .failed
            }
            item.resumeData = resumeData
            self.updateActiveState()
        }
    }

    func markCancelled(_ item: DownloadItem) {
        DispatchQueue.main.async {
            item.state = .cancelled
            self.updateActiveState()
        }
    }
    
    func clearCompleted() {
        DispatchQueue.main.async {
            self.downloads.removeAll { $0.state == .completed || $0.state == .failed || $0.state == .cancelled }
            self.updateActiveState()
        }
    }
    
    func clearAll() {
        DispatchQueue.main.async {
            for item in self.downloads where item.state == .downloading {
                item.cancel()
            }
            self.downloads.removeAll()
            self.updateActiveState()
        }
    }
    
    private func updateActiveState() {
        hasActiveDownloads = downloads.contains { $0.state == .downloading }
    }

    // MARK: - WKDownloadDelegate

    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse,
                  suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        let safeName = Self.sanitizedFilename(suggestedFilename)
        let destURL = Self.uniqueURL(for: safeName, in: downloadsDir)

        let item = addDownload(filename: destURL.lastPathComponent, url: response.url ?? download.originalRequest?.url, download: download)
        item.destinationURL = destURL
        if response.expectedContentLength > 0 {
            item.totalBytes = response.expectedContentLength
        }

        let key = ObjectIdentifier(download)
        items[key] = item
        // WebKit reports progress through `download.progress`, not a delegate call.
        progressObservers[key] = download.progress.observe(\.completedUnitCount, options: [.initial, .new]) { [weak self, weak item] progress, _ in
            guard let self, let item else { return }
            self.updateProgress(for: item, received: progress.completedUnitCount, total: progress.totalUnitCount)
        }

        completionHandler(destURL)
    }

    func downloadDidFinish(_ download: WKDownload) {
        let key = ObjectIdentifier(download)
        guard let item = items[key] else { return }
        markCompleted(item, at: item.destinationURL)
        cleanUp(key)
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        let key = ObjectIdentifier(download)
        guard let item = items[key] else { return }
        markFailed(item, error: error.localizedDescription, resumeData: resumeData)
        cleanUp(key)
    }

    func download(_ download: WKDownload, willPerformHTTPRedirection response: HTTPURLResponse,
                  newRequest request: URLRequest, decisionHandler: @escaping (WKDownload.RedirectPolicy) -> Void) {
        decisionHandler(.allow)
    }

    private func cleanUp(_ key: ObjectIdentifier) {
        progressObservers[key]?.invalidate()
        progressObservers[key] = nil
        items[key] = nil
    }

    // MARK: - File names

    private static func sanitizedFilename(_ name: String) -> String {
        let cleaned = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // Never let a site create a hidden file or an empty name.
        let trimmed = cleaned.drop { $0 == "." }
        return trimmed.isEmpty ? "download" : String(trimmed)
    }

    private static func uniqueURL(for filename: String, in directory: URL) -> URL {
        var url = directory.appendingPathComponent(filename)
        let base = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        var counter = 1
        while FileManager.default.fileExists(atPath: url.path) {
            let name = ext.isEmpty ? "\(base) (\(counter))" : "\(base) (\(counter)).\(ext)"
            url = directory.appendingPathComponent(name)
            counter += 1
        }
        return url
    }
}
