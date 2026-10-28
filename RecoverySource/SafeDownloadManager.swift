import Foundation

enum SafeDownloadError: LocalizedError {
    case invalidURL, unsupportedResponse, httpStatus(Int), emptyFile, notVideoContent(String?)
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "The media URL is invalid."
        case .unsupportedResponse: return "The server returned an unsupported response."
        case .httpStatus(let code): return "The download failed (HTTP \(code))."
        case .emptyFile: return "The server returned an empty file; nothing was saved."
        case .notVideoContent(let type): return "The response is not recognized as video content (\(type ?? "unknown type"))."
        }
    }
}

/// Downloads a direct media URL, not a YouTube watch-page URL.
struct SafeDownloadManager {
    let session: URLSession
    init(session: URLSession = .shared) { self.session = session }

    func downloadDirectVideo(from url: URL, to destination: URL) async throws -> URL {
        guard let scheme = url.scheme?.lowercased(),
              ["https", "http"].contains(scheme), url.host != nil else {
            throw SafeDownloadError.invalidURL
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        request.setValue("video/*, application/octet-stream;q=0.8", forHTTPHeaderField: "Accept")
        let (temporaryURL, response) = try await session.download(for: request)
        guard let http = response as? HTTPURLResponse else {
            try? FileManager.default.removeItem(at: temporaryURL)
            throw SafeDownloadError.unsupportedResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            try? FileManager.default.removeItem(at: temporaryURL)
            throw SafeDownloadError.httpStatus(http.statusCode)
        }
        let mime = http.value(forHTTPHeaderField: "Content-Type")?
            .split(separator: ";", maxSplits: 1).first?
            .trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard mime?.hasPrefix("video/") == true || mime == "application/octet-stream" else {
            try? FileManager.default.removeItem(at: temporaryURL)
            throw SafeDownloadError.notVideoContent(mime)
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: temporaryURL.path)
        let bytes = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        guard bytes > 0 else {
            try? FileManager.default.removeItem(at: temporaryURL)
            throw SafeDownloadError.emptyFile
        }
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        return destination
    }
}
