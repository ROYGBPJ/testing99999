import SwiftUI

/// Recovery UI scaffold for a future Nova Video Xcode target.
///
/// Important: this file is not part of the currently packaged precompiled IPA.
/// It must be added to a real Xcode target and connected to a real media resolver.
struct DownloadEntryView: View {
    @State private var mediaInput = ""
    @State private var isDownloading = false
    @FocusState private var inputIsFocused: Bool

    let onDownload: (String) async throws -> Void

    var body: some View {
        VStack(spacing: 12) {
            TextField("Paste a video URL", text: $mediaInput, axis: .vertical)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .focused($inputIsFocused)
                .submitLabel(.done)
                // Deliberately no onSubmit download action: pressing Return or
                // opening/dismissing the keyboard must never start a download.
                .onSubmit {
                    inputIsFocused = false
                }

            Button {
                // The only event that starts a download is an explicit button tap.
                guard !isDownloading else { return }
                let value = mediaInput.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !value.isEmpty else { return }
                inputIsFocused = false
                isDownloading = true
                Task {
                    defer { isDownloading = false }
                    do {
                        try await onDownload(value)
                    } catch {
                        // The host view should display the actual error to the user.
                    }
                }
            } label: {
                HStack {
                    if isDownloading {
                        ProgressView()
                    }
                    Text(isDownloading ? "Downloading…" : "Download")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isDownloading || mediaInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
    }
}
