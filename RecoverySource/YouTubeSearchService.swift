import Foundation

struct YouTubeSearchResult: Decodable, Identifiable {
    struct VideoID: Decodable, Hashable { let videoId: String? }
    struct Snippet: Decodable {
        let title: String
        let channelTitle: String
        let description: String
        let thumbnails: Thumbnails?
    }
    struct Thumbnails: Decodable {
        struct Image: Decodable { let url: URL? }
        let medium: Image?
        let high: Image?
        let thumbnail: Image?
        enum CodingKeys: String, CodingKey {
            case medium, high
            case thumbnail = "default"
        }
    }

    let id: VideoID
    let snippet: Snippet
    var videoID: String? { id.videoId }
    var watchURL: URL? {
        guard let videoID, !videoID.isEmpty else { return nil }
        return URL(string: "https://www.youtube.com/watch?v=\(videoID)")
    }
    var thumbnailURL: URL? {
        snippet.thumbnails?.high?.url
        ?? snippet.thumbnails?.medium?.url
        ?? snippet.thumbnails?.thumbnail?.url
    }
}

private struct SearchResponse: Decodable { let items: [YouTubeSearchResult] }

enum YouTubeSearchError: LocalizedError {
    case missingAPIKey, emptyQuery, invalidResponse, apiError(String)
    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "YouTube search is not configured."
        case .emptyQuery: return "Enter a video title or keywords."
        case .invalidResponse: return "YouTube returned an unexpected response."
        case .apiError(let message): return message
        }
    }
}

/// Requires a YouTube Data API v3 key supplied by secure configuration.
struct YouTubeSearchService {
    let apiKey: String
    let session: URLSession

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    func searchVideos(query rawQuery: String, maxResults: Int = 15) async throws -> [YouTubeSearchResult] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { throw YouTubeSearchError.emptyQuery }
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw YouTubeSearchError.missingAPIKey
        }
        guard var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/search") else {
            throw YouTubeSearchError.invalidResponse
        }
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "maxResults", value: String(min(max(maxResults, 1), 50))),
            URLQueryItem(name: "safeSearch", value: "moderate"),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "key", value: apiKey)
        ]
        guard let url = components.url else { throw YouTubeSearchError.invalidResponse }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw YouTubeSearchError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let error = json?["error"] as? [String: Any]
            throw YouTubeSearchError.apiError((error?["message"] as? String) ?? "YouTube search failed (HTTP \(http.statusCode)).")
        }
        return try JSONDecoder().decode(SearchResponse.self, from: data).items
            .filter { $0.videoID != nil && $0.watchURL != nil }
    }
}
