import SwiftUI

/// Search-screen scaffold for a future Nova Video Xcode target.
/// Pass a configured YouTubeSearchService into this view. This file is not
/// included in the currently packaged precompiled IPA.
struct YouTubeSearchView: View {
    let service: YouTubeSearchService

    @State private var query = ""
    @State private var results: [YouTubeSearchResult] = []
    @State private var isSearching = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                TextField("Search video name", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit { Task { await search() } }

                Button {
                    Task { await search() }
                } label: {
                    if isSearching {
                        ProgressView()
                    } else {
                        Image(systemName: "magnifyingglass")
                    }
                }
                .disabled(isSearching || query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Search videos")
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !isSearching && results.isEmpty && errorMessage == nil {
                ContentUnavailableView(
                    "Search for a video",
                    systemImage: "magnifyingglass",
                    description: Text("Enter a title or keywords, then tap Search.")
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
    private func search() async {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty, !isSearching else { return }
        isSearching = true
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
            errorMessage = error.localizedDescription
        }
    }
}
