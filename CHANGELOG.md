# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [8.0.0] — unreleased

A major, fully breaking release. The library was modernized from the callback-based API to
async/`await` + `Result`, Swift 6 strict concurrency, typed request bodies, a categorized error
model, a structured event stream, and composable request interceptors.

**Requirements:** Swift 6.2+, and iOS 18 / macOS 15 / tvOS 18 / watchOS 11.

### Added

- **Async API.** Every verb — `get`/`post`/`put`/`patch`/`delete` — is `async` and returns
  `Result<T, NetworkingError>`, where `T` is any `Decodable`, `Data`, `Void`, or `JSONResponse`
  (status code + headers + body) when you want the response metadata.
- **Typed request bodies (no `Any`).** `post`/`put`/`patch` take `body:` (any `Encodable` → JSON),
  `form:` (any flat `Encodable` → url-encoded), `parts:` + `fields:` (multipart), or
  `data:contentType:` (raw). `get`/`delete` take `query:` (a `[URLQueryItem]` or any flat `Encodable`).
- **Categorized errors.** `NetworkingError` is now `invalidRequest` / `transport` / `http` /
  `decoding` / `validation` / `invalidResponse` / `cancelled`, each preserving the underlying cause.
  `HTTPError` carries `statusCode` / `serverMessage` / `metadata`; cross-cutting conveniences
  `statusCode`, `responseMetadata`, and a conservative `isRetryable`.
- **Event stream.** `events()` returns an `AsyncStream<NetworkingEvent>` emitting `.started` then
  `.completed` for every request (verbs *and* downloads) — multi-consumer, carrying the outcome,
  duration, and `URLSessionTaskMetrics`.
- **Built-in logging.** `logLevel` (`.none` / `.failures` (default) / `.all`), release-safe
  redaction (`redactsLogs`, `setRedactedHeaderFields`), and an optional plain-text file sink
  (`setLogFileURL` / the `NETWORKING_LOG_FILE` env var) on top of `os.Logger`.
- **Request interceptors.** `HTTPInterceptor` — an async `intercept(_:next:)` seam registered via
  `setInterceptors`, wrapping verbs and downloads. Built-ins: `AuthRefreshInterceptor` (401/403 →
  refresh + replay once, concurrent refreshes deduped), `RetryInterceptor` (exponential backoff +
  jitter, `Retry-After`, idempotent methods only by default), and `ResponseValidatorInterceptor`
  (reject a 2xx that isn't acceptable → `.validation`).
- **Download envelopes.** `downloadImage` / `downloadData` can return `ImageResponse` / `DataResponse`
  (payload + status code + headers) in addition to the bare `Image` / `Data`.

### Changed

- **`Networking` is now an `actor`**, so concurrent use is compiler-checked. Configuration is via
  async setters (`setAuthorizationHeader`, `setHeaderFields`, `setInterceptors`, …); the type can no
  longer be subclassed.
- **Fakes take `Encodable`** (`fakeGET` / `fakePOST` / …), with a no-body overload and the existing
  `fileName:` variant — no more `Any`.
- Minimum platforms raised to iOS 18 / macOS 15 / tvOS 18 / watchOS 11; Swift 6.2 language mode.

### Removed

- The callback-based API and the `old*` verbs, along with `JSONResult` / `NetworkingResult` /
  `Response`.
- `parameters: Any?` and `ParameterType` — replaced by the typed body/query methods above.
- `print`-based error logging: `isErrorLoggingEnabled` / `setErrorLoggingEnabled` — replaced by
  `events()` and `logLevel`.
- `unauthorizedRequestCallback` / `setUnauthorizedRequestCallback` — replaced by
  `AuthRefreshInterceptor` (pure "notify me on 401" is available on `events()`).

---

Versions **7.0.0 and earlier** predate this changelog; see the
[GitHub releases](https://github.com/3lvis/Networking/releases) and git history.

[8.0.0]: https://github.com/3lvis/Networking/releases/tag/8.0.0
