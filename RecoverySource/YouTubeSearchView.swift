import SwiftUI

/// Search-screen scaffold for a future Nova Video Xcode target.
/// This file is not part of the currently packaged precompiled IPA.
struct YouTubeSearchView: View {
    let service: YouTubeSearchService

    @State private var query = ""
    @State private var results: [YouTubeSearchResult] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var errorMessage: String?
    @FocusState private var searchFieldFocused: Bool

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var youtubeSearchURL: URL? {
        guard !trimmedQuery.isEmpty,
              var components = URLComponents(string: "https://www.youtube.com/results") else {
            return nil
        }
        components.queryItems = [URLQueryItem(name: "search_query", value: trimmedQuery)]
        return components.url
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                TextField("Search video title", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.webSearch)
                    .submitLabel(.search)
                    .focused($searchFieldFocused)
                    .onSubmit { Task { await runSearch() } }
                    .onChange(of: query) { _, _ in errorMessage = nil }

                Button {
                    Task { await runSearch() }
                } label: {
                    HStack(spacing: 6) {
                        if isSearching { ProgressView() }
                        Text(isSearching ? "Searching…" : "Search")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSearching || trimmedQuery.isEmpty)
                .accessibilityLabel("Search video titles")
            }

            if let youtubeSearchURL {
                Link(destination: youtubeSearchURL) {
                    Label("Search on YouTube instead", systemImage: "play.rectangle")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.subheadline)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !hasSearched && !isSearching {
                ContentUnavailableView(
                    "Find a YouTube video",
                    systemImage: "magnifyingglass",
                    description: Text("Enter a video title or keywords. Search lists matching videos here when the API is configured.")
                )
            } else if hasSearched && results.isEmpty && errorMessage == nil && !isSearching {
                ContentUnavailableView(
                    "No videos found",
                    systemImage: "video.slash",
                    description: Text("Try different keywords or use Search on YouTube instead.")
                )
            }

            List(results) { result in
                if let url = result.watchURL {
                    Link(destination: url) {
                        HStack(spacing: 12) {
                            if let thumbnailURL = result.thumbnailURL {
                                AsyncImage(url: thumbnailURL) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(.quaternary)
                                        .overlay {
                                            Image(systemName: "play.rectangle")
                                                .foregroundStyle(.secondary)
                                        }
                                }
                                .frame(width: 112, height: 63)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.snippet.title)
                                    .font(.headline)
                                    .lineLimit(2)
                                Text(result.snippet.channelTitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } else {
                    Text(result.snippet.title)
                }
            }
            .listStyle(.plain)
        }
        .padding()
    }

    @MainActor
    private func runSearch() async {
        let term = trimmedQuery
        guard !term.isEmpty, !isSearching else { return }

        searchFieldFocused = false
        isSearching = true
        hasSearched = true
        errorMessage = nil
        results = []
        defer { isSearching = false }

        do {
            results = try await service.searchVideos(query: term)
            if results.isEmpty {
                errorMessage = "No matching videos returned. Try different keywords or search on YouTube."
            }
        } catch {
            errorMessage = "\(error.localizedDescription) You can still use Search on YouTube instead."
        }
    }
}
