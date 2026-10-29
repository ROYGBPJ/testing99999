# Original Nova Video binary: YouTube/download investigation

**Scope:** Static analysis of the existing `Payload/Y.app` executable. This report does not modify or replace the original app. It records what can be established from the binary; it does not claim a runtime test was performed.

## Confirmed request flow

- The app's `ProgressVC.downloadAPIVideo(videoURL:)` constructs a GET request to `https://full-downloader-social-media.p.rapidapi.com/?url=<encoded input>`.
- Request timeout is 30 seconds.
- The request uses a static HTTP-header dictionary compiled into the binary and sends it via `setAllHTTPHeaderFields:`.
- The callback logs the raw response text, then calls `parseVideoURLAndCaption(url:caption:headers:data:)`.
- If parsing returns a URL, the app logs `Final download URL:` and calls `startVideoDownload(from:headers:)`.
- It logs HTTP status codes. For 429 and 403 it displays “Please wait a moment and try again.”
- If data is absent it logs “No data received from API”; if parsing fails it logs “All parsers failed” and “Could not extract video. The video may be private or the link is unsupported.”

## Response compatibility clues

The binary contains fallback-parser strings for several response layouts, including:

- `download_links` arrays of dictionaries
- `download_links` arrays with a success flag
- `array[0].download_url`
- `result.links` and `result.download_url`
- `data.links` and `data.download_url`
- `links` arrays and `download_url` fields
- `hosting` and `quality` metadata

This suggests the app was written to tolerate multiple historical API response shapes. It does **not** establish which shape the live endpoint currently returns. A runtime response or a known-good API fixture is needed to confirm compatibility.

## Authentication status

The request's headers are loaded from a compiled static dictionary (three key/value pairs are constructed before `setAllHTTPHeaderFields:`). The binary contains the header name `x-rapidapi-key`, so the request appears designed to use RapidAPI key authentication. I have not reproduced or published the credential value. Static analysis cannot establish whether that value is still valid, whether the account still has quota, or whether the service has changed its required headers. Do not print, commit, or share any embedded API secret. If a key is found to be exposed in the binary, treat it as public and rotate it through the provider.

## Most likely failure points, in test order

1. **API authorization / quota / endpoint availability:** an HTTP 403 or 429 has an explicit app branch. The bundled key may be expired, revoked, quota-limited, or otherwise rejected; this requires a real response status to distinguish.
2. **API response schema drift:** the app supports several old JSON layouts, but a new response can miss every recognized path. The app's own logs should then include “All parsers failed” and the raw response.
3. **Resolver output is not a usable media URL:** a parser can extract a URL that later fails validation or download. The app logs the final URL and later download errors.
4. **Title search is not implemented by the inspected resolver:** the resolver accepts a URL string and sends it as the `url` query parameter to the RapidAPI endpoint. It is a URL-to-media resolver, not a YouTube title/keyword search API. The binary has a `btnFind` action, but the resolver implementation alone cannot produce a list of videos from search keywords. The title-search button's complete call path remains unproven, so the strongest current conclusion is that the resolver cannot, by itself, satisfy title-search behavior.

## Repair boundary

The repository's current workflow packages the precompiled `Payload/Y.app`; it does not compile `RecoverySource/*.swift`. Therefore editing recovery scaffold files alone cannot change the installed app. No blind binary patch is recommended until a reproducible failure is identified.

## Safe validation plan

- Capture the app's HTTP status and sanitized response body from a test request. Remove any API key, authorization value, personal data, or signed URL query tokens before sharing logs.
- Compare the response's JSON paths with the parser cases above.
- If authorization/quota is the failure, configure a valid key through a backend/proxy you control rather than embedding a reusable secret in the IPA.
- If the response schema is the failure, update a source-level parser with a fixture from the current API and tests for the known response layouts.
- Keep the original IPA unchanged; create and device-test any candidate build separately.


## Follow-up: Find-button disassembly

A targeted disassembly of the `btnFind` action at the current binary's mapped addresses shows the action body branching to `adShown()` or `displayAd()`, with no visible call from that action to a YouTube search endpoint or a search-results controller in the inspected function. The related `btnSelVideo` action is routed through the same thunk with a different selector argument. This strengthens the conclusion that the compiled Find action, as currently analyzed, is not wired to a title-search implementation; it does not prove that no search logic exists anywhere else in the binary.

**Practical consequence:** adding the recovered `YouTubeSearchView` to `RecoverySource/` still cannot alter `Payload/Y.app`. The current repository has no original Xcode project/source to recompile, and the packaging workflow only repackages that binary. A working fix requires either recovering the original project/source or building a separate replacement app from the recovery sources. No binary patch or fixed IPA has been produced.
