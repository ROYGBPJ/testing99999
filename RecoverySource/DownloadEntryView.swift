import SwiftUI

/// Recovery UI scaffold for Nova Video v20.
/// IMPORTANT: This file is not included in the currently packaged Payload/Y.app.
/// It must be integrated into a real Xcode target before it can affect the installed IPA.
struct DownloadEntryView: View {
    @State private var mediaInput = ""
    @State private var isDownloading = false
    @State private var errorMessage: String?
    @State private var succeeded = false
    @FocusState private var inputIsFocused: Bool

    let onDownload: (String) async throws -> Void

    private var trimmedInput: String {
        mediaInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Nova Video")
                    .font(.headline)
                Spacer()
                Text("Version 20")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Version 20")
            }

            TextField("Paste a video URL", text: $mediaInput, axis: .vertical)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .focused($inputIsFocused)
                .submitLabel(.done)
                // Keyboard submission only dismisses the keyboard; it never downloads.
                .onSubmit { inputIsFocused = false }
                .onChange(of: mediaInput) { _, _ in
                    errorMessage = nil
                    succeeded = false
                }
                .accessibilityLabel("Video URL")

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.updatesFrequently)
            }

            if succeeded {
                Label("Download completed and validated.", systemImage: "checkmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                guard !isDownloading else { return }
                guard let url = URL(string: trimmedInput),
                      let scheme = url.scheme?.lowercased(),
                      ["https", "http"].contains(scheme),
                      url.host != nil else {
                    errorMessage = "Enter a valid http or https video URL."
                    succeeded = false
                    return
                }

                inputIsFocused = false
                isDownloading = true
                errorMessage = nil
                succeeded = false
                Task { @MainActor in
                    defer { isDownloading = false }
                    do {
                        try await onDownload(trimmedInput)
                        succeeded = true
                    } catch {
                        // Never swallow errors or claim success when a request fails.
                        errorMessage = Self.userFacingMessage(for: error)
                    }
                }
            } label: {
                HStack {
                    if isDownloading { ProgressView() }
                    Text(isDownloading ? "Working…" : (errorMessage == nil ? "Download" : "Try Again"))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isDownloading || trimmedInput.isEmpty)

            Text("Network restrictions can prevent access. Retrying cannot override a blocked connection.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
    }

    private static func userFacingMessage(for error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorTimedOut:
                return "The request timed out while fetching video details. Check the connection and try again. If this happens only on school Wi-Fi, ask the network administrator whether the required service is allowed."
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
                return "The internet connection was lost. Reconnect and try again."
            case NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed:
                return "The server could not be found. Check the network or ask its administrator whether the service is filtered."
            case NSURLErrorCancelled:
                return "The request was cancelled. You can try again."
            default:
                break
            }
        }
        return error.localizedDescription.isEmpty
            ? "The request failed. Check your connection and try again."
            : error.localizedDescription
    }
}
