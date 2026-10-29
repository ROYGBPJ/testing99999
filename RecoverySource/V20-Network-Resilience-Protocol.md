# Nova Video v20 — Network Resilience and Recovery Protocol

Status: source-scaffold changes only. This is not yet a shipped or signed app release.

## Version label
- User-facing recovery UI label: **Nova Video — Version 20**.
- Do not change the bundle identifier or claim the installed IPA is v20 until an integrated build has been produced, signed, installed, and verified on-device.
- The current packaging workflow repackages the precompiled `Payload/Y.app`; it does not compile the recovery Swift sources.

## Failure-safe behavior
1. **Explicit action only:** keyboard Return, focus changes, or dismissing the keyboard must never trigger a download. Only the Download button may start one.
2. **Single-flight guard:** disable the action while a request is in progress; prevent duplicate concurrent requests.
3. **Bounded request timeout:** use finite request timeouts. Do not retry indefinitely or simply increase the timeout to hide a blocked connection.
4. **Error classification:** distinguish timeout, no internet/network loss, DNS/host lookup failure, HTTP 401/403 (authorization/forbidden), HTTP 429 (rate limit), server errors, unsupported URL, and response/schema errors.
5. **Safe retry policy:** at most one retry for clearly transient network errors or HTTP 5xx, with a short delay and cancellation support. Do not automatically retry 401/403/429, invalid input, or deterministic parsing errors. Respect any `Retry-After` response. A retry must not attempt to evade school or organizational filtering.
6. **Useful UI:** replace generic “Error, try again” with a clear explanation and next step. Always stop the spinner on success, failure, or cancellation. Keep the input visible and editable after an error.
7. **No false success:** only show success after a nonempty downloaded file is validated and safely moved into its destination. Remove partial temporary files on failure.
8. **Privacy-safe diagnostics:** log request stage, elapsed time, sanitized host, HTTP status, and error code. Never log API keys, authorization headers, cookies, full signed media URLs, or private user data.
9. **Network comparison:** test the same URL and app version on home Wi-Fi, seminary Wi-Fi, school Wi-Fi, and cellular if permitted. If YouTube also fails in Safari only on school Wi-Fi, record that as evidence of a network-specific issue—not proof of a particular filter rule.
10. **Respect network policy:** if a required YouTube or resolver endpoint is filtered, explain that access may be restricted and ask the network administrator whether it should be allowed. Do not change DNS/proxy settings to circumvent policy or build a bypass.
11. **Service health:** verify resolver endpoint availability, API key status, quota, response status, and response schema separately from reachability. Never embed a reusable provider secret in a public client build; rotate any key exposed in a binary.
12. **Accessibility:** show an accessible error message, preserve keyboard navigation, and announce status changes without leaving a permanent loading indicator.

## Diagnostic decision tree
- `apple.com` fails too: troubleshoot general Wi-Fi access/captive portal first.
- `apple.com` loads but YouTube fails in Safari on school Wi-Fi only: ask school IT whether YouTube and its required video/API hosts are filtered; provide timestamp and device OS, not credentials.
- YouTube works in Safari but Nova Video fails: inspect the app/resolver request, HTTP status, authentication/quota, and parser compatibility.
- Same app fails on every network: prioritize service outage, expired/revoked API credentials, API quota, resolver response changes, and app bugs.
- HTTP 403/429: show a policy/authorization or rate-limit explanation; do not spin/retry indefinitely.
- Timeout/DNS failure: offer one manual retry and a diagnostic hint; never claim the school intentionally blocked it unless confirmed by the administrator.

## Release acceptance checks for v20
- [ ] UI displays “Version 20” only in a build that actually contains the updated source.
- [ ] Download cannot be started by keyboard Return or by tapping twice rapidly.
- [ ] Timeout, offline, DNS failure, HTTP 403, HTTP 429, HTTP 5xx, invalid URL, malformed response, and cancellation each produce a distinct actionable error.
- [ ] Spinner ends on every path; retry is user initiated after a terminal failure.
- [ ] No secrets, cookies, or signed URL tokens appear in logs.
- [ ] Temporary files are cleaned up on every failure path; success requires a validated nonempty media file.
- [ ] Tests run on home, seminary, and school networks where permitted; no test attempts to bypass filtering.
- [ ] Build, signing, installation, and on-device checks are complete before calling v20 released.

## Important implementation boundary
The current repository contains recovery Swift files but not the original Xcode project. The packaged `Payload/Y.app` is a precompiled binary and is not rebuilt by the current packaging workflow. These source changes and this protocol cannot alter the currently installed IPA until integrated into a real Xcode app target and built. Do not describe this branch as a fixed or released IPA.
