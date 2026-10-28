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

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                TextField("Search video name", text: $query)
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
                        Text(isSearching ? "Searching" : "Search")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSearching || query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Search videos")
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !hasSearched && !isSearching {
                ContentUnavailableView(
                    "Search for a video",
                    systemImage: "magnifyingglass",
                    description: Text("Enter a video title or keywords, then tap Search or press Search on the keyboard.")
                )
            } else if hasSearched && results.isEmpty && errorMessage == nil && !isSearching {
                ContentUnavailableView(
                    "No videos found",
                    systemImage: "video.slash",
                    description: Text("Try different keywords.")
                )
            }

            List(results) { result in
                if let url = result.watchURL {
                    Link(destination: url) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(result.snippet.title)
                                .font(.headline)
                                .lineLimit(2)
                            Text(result.snippet.channelTitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty, !isSearching else { return }

        searchFieldFocused = false
        isSearching = true
        hasSearched = true
        errorMessage = nil
        results = []
        defer { isSearching = false }

        do {
            let found = try await service.searchVideos(query: term)
            results = found
            if found.isEmpty {
                errorMessage = "No videos found. Try different keywords."
            }
        } catch {
            errorMessage = "Search failed: \(error.localizedDescription)"
        }
    }
}
