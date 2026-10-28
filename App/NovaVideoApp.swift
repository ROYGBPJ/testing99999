import SwiftUI

@main
struct NovaVideoApp: App {
    var body: some Scene {
        WindowGroup { SearchView() }
    }
}

struct VideoResult: Identifiable, Decodable {
    struct APIID: Decodable { let videoId: String? }
    struct Snippet: Decodable {
        let title: String
        let channelTitle: String
        let thumbnails: Thumbnails?
    }
    struct Thumbnails: Decodable {
        struct ImageInfo: Decodable { let url: String }
        let medium: ImageInfo?
        let high: ImageInfo?
    }
    let apiID: APIID
    let snippet: Snippet
    var id: String { apiID.videoId ?? snippet.title }
    var watchURL: URL? { apiID.videoId.flatMap { URL(string: "https://www.youtube.com/watch?v=\($0)") } }
    enum CodingKeys: String, CodingKey { case apiID = "id", snippet }
}

struct SearchResponse: Decodable { let items: [VideoResult] }

struct SearchView: View {
    @State private var query = ""
    @State private var results: [VideoResult] = []
    @State private var busy = false
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack {
                    TextField("Search YouTube video name", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .focused($focused)
                        .onSubmit { Task { await search() } }
                    Button { Task { await search() } } label: {
                        if busy { ProgressView() } else { Image(systemName: "magnifyingglass") }
                    }
                    .disabled(busy || query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Search")
                }
                .textFieldStyle(.roundedBorder)
                if let error {
                    Text(error).font(.footnote).foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if results.isEmpty && !busy && error == nil {
                    ContentUnavailableView("Search videos", systemImage: "play.rectangle",
                        description: Text("Enter a title and tap Search or press Search on the keyboard."))
                }
                List(results) { item in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.snippet.title).font(.headline)
                        Text(item.snippet.channelTitle).font(.caption).foregroundStyle(.secondary)
                        if let url = item.watchURL {
                            Link("Open on YouTube", destination: url)
                        }
                    }.padding(.vertical, 4)
                }
                .listStyle(.plain)
            }
            .padding()
            .navigationTitle("Nova Video")
        }
    }

    @MainActor
    private func search() async {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty, !busy else { return }
        focused = false
        busy = true
        error = nil
        results = []
        defer { busy = false }
        guard let key = Bundle.main.object(forInfoDictionaryKey: "YOUTUBE_API_KEY") as? String,
              !key.isEmpty, key != "$(YOUTUBE_API_KEY)" else {
            error = "Search is not configured. Add a YouTube Data API key to the build settings."
            return
        }
        do {
            var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/search")!
            components.queryItems = [
                URLQueryItem(name: "part", value: "snippet"),
                URLQueryItem(name: "type", value: "video"),
                URLQueryItem(name: "maxResults", value: "25"),
                URLQueryItem(name: "q", value: term),
                URLQueryItem(name: "key", value: key)
            ]
            let (data, response) = try await URLSession.shared.data(from: components.url!)
            guard let http = response as? HTTPURLResponse else { throw SearchError.badResponse }
            guard http.statusCode == 200 else {
                throw SearchError.api("YouTube search returned HTTP \(http.statusCode). Check the API key, quota, and API enablement.")
            }
            let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
            results = decoded.items
            if results.isEmpty { error = "No videos found. Try another title." }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
enum SearchError: LocalizedError {
    case badResponse
    case api(String)
    var errorDescription: String? {
        switch self {
        case .badResponse: return "The search service returned an invalid response."
        case .api(let message): return message
        }
    }
}
