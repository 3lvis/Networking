# Networking — roadmap

The legacy callback/`old*` → modern async/`Result`/Swift-6 migration is **complete** (shipped across PRs #284–#303). This doc now tracks the next horizon: closing the gap between *modern* and *best-in-class*.

**Convention — keep the README in sync.** Any public-API change updates `README.md` in the **same** PR; its snippets are copy-paste docs, so a stale example is a broken one — and on the `actor` they must actually compile (isolated members need `await`). Run the suite with `make test` (local go-httpbin in Docker).

## Completed — the modernization

Condensed; full detail is in PRs #284–#303 and git history.

- **One typed async API.** Callback/`old*` verbs replaced by `get`/`post`/`put`/`patch`/`delete` → `Result<T, NetworkingError>` over any `Decodable` (or `JSONResponse` for status/headers, or `Data`). The entire `old*` + `JSONResult`/`NetworkingResult`/`Response` legacy hierarchy is deleted.
- **Downloads unified.** `downloadImage`/`downloadData` → `Result<T, NetworkingError>` where `T` is the bare payload (`Image`/`Data`) or an envelope (`ImageResponse`/`DataResponse`) carrying status/headers; `T` constrained by marker protocols.
- **Concurrency-safe.** `Networking` is a `public actor` (compiler-verified isolation; async config setters; no subclassing). Swift 6 language mode, `swift-tools 6.2`, iOS 18 minimum.
- **Deterministic tests.** Local `go-httpbin` (`make test`), zero `httpbin.org` references, CI on `macos-15` / Xcode 26.3.

These were breaking vs 7.0.0 → next tag is a major bump (see item 8 for the changelog/semver work).

## Roadmap — toward best-in-class

External review: the foundation is solid, but a top-tier Swift HTTP library would go further. Prioritized; 1–3 are the highest-leverage and add no dependency.

0. ~~**Fix README correctness.**~~ ✅ Stale `actor` examples (fake/config calls missing `await`) fixed so snippets compile.

1. ~~**Typed request bodies & builders — get off `Any`.**~~ ✅ The `parameters: Any?` + `ParameterType` pair and `fake*(response: Any?)` are gone, replaced by distinct labelled typed methods where the wrong combination can't be expressed (`Networking+HTTPRequests.swift`):
    - **Bodies** (`post`/`put`/`patch`): `body:` over any `Encodable` (JSON, `application/json`, ISO-8601 dates), `form:` over any flat `Encodable` (url-encoded; a `[String: String]` or your own model), `parts:`+`fields:` (multipart), `data:contentType:` (raw). Each returns `Result<T, NetworkingError>` or `Result<Void, …>`.
    - **Query** (`get`/`delete`): `query:` as a `[URLQueryItem]` (ordering/duplicate keys) or any flat `Encodable` model. `form:`/`query:` share `formFields` (`Networking+FormEncoding.swift`), which flattens via a JSON bridge + scalar re-decode so `Bool` stringifies to "true", not NSNumber's "1".
    - **Fakes:** `fake*(response:)` takes any `Encodable` (encoded to JSON), plus a no-body overload and the existing `fileName:` variant; `FakeRequest` stores a typed `Payload` enum. Internals (`handle`/`createRequest`/`httpBody`, `RequestBody`, `URLRequest` init `contentType:`, `logError`) carry no `Any`.
    - Header *values* were already `[String: String]`; a typed header-*name* vocabulary (enum of well-known keys) is a possible future ergonomics nicety, not an `Any` fix. The only remaining `Any` is the download cache substrate (`NSCache<AnyObject, AnyObject>`) and `AnyCodable` response bodies — both out of scope here.

2. ~~**Richer error model.**~~ ✅ `NetworkingError` (`NetworkingError.swift`) is now categorized by where the failure happened, preserving the underlying cause:
    - `invalidRequest(InvalidRequestReason)` (bad URL / un-encodable body or params), `transport(URLError)`, `http(HTTPError)`, `decoding(DecodingError, ResponseMetadata)`, `invalidResponse`, `cancelled`.
    - `HTTPError` carries `statusCode`, `serverMessage` (parsed from the error body), `isClientError`/`isServerError`, and `ResponseMetadata` (headers + a truncated, log-friendly body snippet). `decoding` keeps the live `DecodingError` (Sendable in this SDK) + metadata.
    - Cross-cutting conveniences: `statusCode`, `responseMetadata`, and a conservative `isRetryable` (transient transport failures + HTTP 408/429/5xx only).
    - The old flat `clientError`/`serverError`/`unexpectedError`/`invalidURL` cases and the `ParameterType`-era `[String: any Sendable]` details bag are gone.

3. ~~**Structured observability — remove `print`.**~~ ✅ The `print`-based `logError` (and `isErrorLoggingEnabled`/`setErrorLoggingEnabled`) are gone. A consumer sets one observer (`setObserver`, a `@Sendable (NetworkingEvent) -> Void`) and receives a `.started` and a `.completed` per request (`NetworkingEvent.swift`):
    - `RequestContext` (request-id `UUID`, method, url, redacted headers) is shared by both events; `.completed` carries the `Outcome` (`.success(statusCode:byteCount:)` / `.failure(NetworkingError)`), a measured `Duration`, and `TransactionMetrics` (a `Sendable` distillation of `URLSessionTaskMetrics` — DNS/connect/TLS/request/response timings, byte counts, redirect count, cache hit) for real network requests.
    - Header redaction (`Authorization`/auth-key/`Cookie`/`Set-Cookie` by default, `setRedactedHeaderFields` to change).
    - **Built-in logging stays out-of-the-box**, just off `print`: the library logs request starts and *every* failure (incl. HTTP 4xx/5xx) to `os.Logger` (request-id-stamped, redacted body snippet) automatically — visible in Xcode/Console, filterable, privacy-aware. `setLogLevel(.none)` silences it (the observer still fires).
    - **File sink for CLI/agent runs** (since `os.Logger` isn't in stdout — and `OSLogStore` can't read prior runs on iOS): `setLogFileURL(_:)` — or the `NETWORKING_LOG_FILE` env var (zero code change) — mirrors the same diagnostics to a readable, timestamped text file. A bare filename resolves under Caches (sandbox-safe; CocoaLumberjack's default), so it works in a simulator app too (`SIMCTL_CHILD_NETWORKING_LOG_FILE` + `simctl get_app_container`). The observer is our Alamofire-`EventMonitor`-style seam.

   **3.1 — Observability follow-up (in progress):**
   - ✅ **`AsyncStream<NetworkingEvent>` observer** via `events()`, *keeping* the closure `setObserver`. The closure suits fire-and-forget side effects (activity indicator); the stream suits accumulation/transformation (`for await event in networking.events()`) — and removes the `Box`/`@unchecked` dance consumers (and tests) need to collect events from a `@Sendable` closure. The continuation plumbing (a continuations registry + a single `emit` fan-out + `onTermination` cleanup + bounded `.bufferingNewest`) is ~15 lines hidden inside the actor; multi-consumer.
   - ✅ **Verbosity `Level`, à la OkHttp's `HttpLoggingInterceptor`.** `isLoggingEnabled` bool → `logLevel` (`Networking.LogLevel`): `.none` / `.basic` (today's lines, default) / `.headers` (also redacted headers) / `.body` (also truncated bodies — opt-in, the level OkHttp warns about; redaction still applies). Gates/shapes only the built-in `os.Logger`/file output; the observer + stream always carry full structured events.
   - **Observer/stream events on the download paths** (`downloadImage`/`downloadData`) — currently only the verb path emits `.started`/`.completed`.
   - Later: optional `os_signpost` intervals for Instruments, behind the same level gate.

4. **Request/response middleware.** Composable retry/backoff, timeout policy, auth-refresh, request adapters/interceptors, and response validators — table stakes for a serious client.

5. **Optional `swift-http-types` substrate.** Apple's [`swift-http-types`](https://github.com/apple/swift-http-types) (version-independent `HTTPRequest`/`HTTPResponse`/`HTTPFields`; v1.6.0, Jun 2026) is now the standard low-level Swift HTTP currency. Add a lower-level request API built on it as a **separate SPM product**, so the core stays dependency-free.

6. **OpenAPI interoperability.** Apple's [Swift OpenAPI Generator](https://github.com/apple/swift-openapi-generator) is the type-safe-from-spec path (3.0/3.1, streaming, multipart, `OpenAPIURLSession` transport). Either offer an interop/transport example, or document clearly where Networking sits relative to it (the hand-written-client tier).

7. **HTTP cache semantics (evaluate).** The hand-rolled disk + `NSCache` (`cacheOrPurge*`) is fine for image/data caching but isn't HTTP caching: ETag/Last-Modified, `Cache-Control`, stale-while-revalidate, size limits, eviction. Decide whether to adopt `URLCache`/HTTP semantics or keep the bespoke cache scoped to downloads and say so.

8. **Package polish & release.** DocC docs, Swift Package Index metadata (`.spi.yml`), an examples app/package, a **CHANGELOG + semver notes** for the v8 breaking changes (major bump from 7.0.0), and a compatibility/benchmark matrix.

Each item is its own PR (some a short series).
