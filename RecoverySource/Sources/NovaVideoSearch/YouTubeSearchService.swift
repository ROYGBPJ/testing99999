import Foundation

public struct YouTubeSearchResult: Decodable, Identifiable {
    public struct VideoID: Decodable, Hashable { public let videoId: String? }
    public struct Snippet: Decodable {
        public let title: String
        public let channelTitle: String
        public let description: String
        public let thumbnails: Thumbnails?
    }
    public struct Thumbnails: Decodable {
        public struct Image: Decodable { public let url: URL? }
        public let medium: Image?
        public let high: Image?
        public let thumbnail: Image?
        enum CodingKeys: String, CodingKey {
            case medium, high
            case thumbnail = "default"
        }
    }

    public let id: VideoID
    public let snippet: Snippet
    public var videoID: String? { id.videoId }
    public var watchURL: URL? {
        guard let videoID, !videoID.isEmpty else { return nil }
        var components = URLComponents(string: "https://www.youtube.com/watch")
        components?.queryItems = [URLQueryItem(name: "v", value: videoID)]
        return components?.url
    }
    public var thumbnailURL: URL? {
        snippet.thumbnails?.high?.url
        ?? snippet.thumbnails?.medium?.url
        ?? snippet.thumbnails?.thumbnail?.url
    }
}

private struct SearchResponse: Decodable { let items: [YouTubeSearchResult] }

public enum YouTubeSearchError: LocalizedError, Equatable {
    case missingAPIKey, emptyQuery, invalidResponse, apiError(String)
    public var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "YouTube search is not configured."
        case .emptyQuery: return "Enter a video title or keywords."
        case .invalidResponse: return "YouTube returned an unexpected response."
        case .apiError(let message): return message
        }
    }
}

public struct YouTubeSearchService {
    public let apiKey: String
    public let session: URLSession

    public init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    public func searchVideos(query rawQuery: String, maxResults: Int = 15) async throws -> [YouTubeSearchResult] {
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
