# Nova Video v15 recovery scaffold

These are new source examples, not recovered original source. The repository's existing workflow packages the precompiled Payload/Y.app; it does not compile Swift files.

## Included source
- `YouTubeSearchService.swift`: YouTube Data API v3 search by title/keywords. Configure an API key securely through build settings or a backend; do not commit a real key. API quota limits apply.
- `SafeDownloadManager.swift`: direct-media download validation for HTTP status, MIME type, nonzero file size, and safe temporary-file promotion.

## Important limits
- This scaffold is not integrated into the compiled IPA and cannot fix the currently installed app by itself.
- A YouTube watch URL is HTML, not a direct MP4 stream. A compatible extractor must resolve a valid media URL before download.
- Do not mark a download successful until the response is valid, the file is nonempty, and the actual media container is verified. Some streams require separate audio/video tracks to be merged.
- Search results can be opened as YouTube watch links. Download is a separate operation and must only be offered when a valid, permitted media URL is available.
- No fake subscription plans, fake progress, or false success messages should be shown.

To integrate: add these files to a real Xcode target, configure the API key securely, implement search-result UI and error states, add unit/device tests, and update the workflow to build an actual Xcode project. The current repository only packages an existing compiled app.