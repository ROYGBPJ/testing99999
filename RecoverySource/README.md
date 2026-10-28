# Nova Video v15 recovery scaffold

These files are recovery scaffolding, not recovered original source. The repository's current workflow packages the precompiled `Payload/Y.app`; it does not compile these Swift files. Therefore, this commit does **not** change the installed IPA's screens or behavior.

## Requested behavior for the rebuilt app

- Remove plan/subscription/paywall screens and all purchase prompts.
- Do not impose an artificial download count or subscription-based download limit.
- Keep downloads subject to technical limits, available device storage, service/API quotas, and applicable content permissions.
- The keyboard must never start a download by itself. Only an explicit tap on the Download button may start one.
- Do not show success until a nonempty media file has been validated. On failure, remove incomplete temporary files and show a real error.
- Never label an HTML page or an audio-only/video-only fragment as a playable completed video.
- Support YouTube search by title/keywords separately from resolving and downloading media. A YouTube watch URL is an HTML page, not a direct MP4 stream.

## Included source examples

- `DownloadEntryView.swift`: SwiftUI input/button scaffold; Return key and keyboard changes do not initiate downloads. The supplied callback must be connected to a real resolver/downloader, and errors should be displayed by the host view.
- `YouTubeSearchView.swift`: SwiftUI search field and results list scaffold. It displays API errors and links results to their YouTube watch pages. It requires a configured `YouTubeSearchService` and a valid API key.
- `YouTubeSearchService.swift`: YouTube Data API v3 search by title/keywords. Configure an API key securely; do not commit a real key. API quota limits apply.
- `SafeDownloadManager.swift`: direct-media download validation for HTTP status, MIME type, nonzero file size, and safe temporary-file promotion.

## Important limits

- None of these source examples are integrated into the compiled IPA.
- A compatible extractor/resolver must obtain a valid media stream before a download can begin. Some sources use separate audio and video tracks that must be merged into a valid container.
- Unlimited downloads here means no artificial app/subscription counter; it cannot override device storage, source service limits, or content permissions.
- Do not show fake plans, fake progress, or false success messages.

## Required next step

To make these changes affect the app, the original Xcode project/source must be recovered or the app must be rebuilt from source in a real Xcode target. Add these files to that target, implement the actual media resolver and playback/container validation, remove any plan UI and purchase-gating code, then build and test on an iPhone. The current packaging-only workflow cannot compile or integrate these changes.
