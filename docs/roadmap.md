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

3. ~~**Structured observability — remove `print`.**~~ ✅ The `print`-based `logError` (and `isErrorLoggingEnabled`/`setErrorLoggingEnabled`) are gone. Two cleanly-separated concerns (`NetworkingEvent.swift`):
    - **Event stream — the one consumer hook.** `events()` returns an `AsyncStream<NetworkingEvent>` that emits `.started(RequestContext)` then `.completed(RequestContext, outcome:duration:metrics:)` for *every* request (verbs and downloads). Multi-consumer; iterate with `for await` and accumulate into plain local state (no `Box`/`@unchecked`). Plumbing (continuations registry + single `emit` fan-out + `onTermination` cleanup + bounded `.bufferingNewest`) is ~15 lines on the actor. `RequestContext` = request-id `UUID` + method + url + the real request headers (raw; redaction is a log-path concern); `.completed` carries `Outcome` (`.success(statusCode:byteCount:)`/`.failure(NetworkingError)`), a measured `Duration`, and `TransactionMetrics` (a `Sendable` distillation of `URLSessionTaskMetrics`) for real network requests.
    - **Built-in logging — out of the box, synchronous/lossless** (in the completion funnel, not a stream consumer). `logLevel` (`Networking.LogLevel`) chooses *which* requests: `.none` / `.failures` (default) / `.all`; logged requests always get full detail — line + request & response headers + request & response bodies (truncated). `.failures` covers the debug case for free (incl. the request body, which catches wrong-shaped payloads); `.all` adds successes (with response body for "succeeded but wrong"). Downloads log line + request headers only (binary payload). **One redaction rule — debug shows, release redacts** (`redactsLogs`, defaulted via `#if DEBUG`): release logs replace both the body lines and the `setRedactedHeaderFields` header values with `<redacted>`. Redaction lives in the log path, so `events()` carries the real headers; it doesn't cover the parsed server message on the failure line.
    - **File sink for CLI/agent runs** (since `os.Logger` isn't in stdout — and `OSLogStore` can't read prior runs on iOS): `setLogFileURL(_:)` — or the `NETWORKING_LOG_FILE` env var (zero code change) — mirrors the same diagnostics to a readable, timestamped text file. A bare filename resolves under Caches (sandbox-safe; CocoaLumberjack's default), so it works in a simulator app too (`SIMCTL_CHILD_NETWORKING_LOG_FILE` + `simctl get_app_container`).

   **3.1 — Observability follow-up (done):** ✅ `events()` `AsyncStream` (the hook) · ✅ scope-based `logLevel` (`.none`/`.failures`/`.all`) · ✅ download-path events (`handleDataRequest`/`handleImageRequest`) · ✅ **simplified to one hook** — dropped the closure `setObserver` (it forced the `Box` dance and duplicated the stream); built-in logging runs in the completion funnel, defaults to failures. Later (own item if pursued): optional `os_signpost` intervals for Instruments.

4. **Request/response middleware.** A composable pipeline around every request — table stakes for a serious client. Best done as a short PR series; the shape of the seam (a single `Interceptor` chain à la Alamofire/OkHttp vs. discrete typed policies on the actor) is the first thing to settle, with a prior-art scan, before building. Planned scope:
    - **4a — Interceptor seam (foundation).** One async hook to inspect/mutate the outgoing `URLRequest` and observe/transform the response before it's mapped to `Result`. Everything below composes on this.
    - **4b — Auth-refresh, and the removal of `unauthorizedRequestCallback`.** On 401/403, run a refresh step then **replay** the original request with the new credential. This is what the current `setUnauthorizedRequestCallback` *wanted* to be — a fire-and-forget `@Sendable () -> Void` can only notify, never retry. So this PR **deletes `unauthorizedRequestCallback`/`setUnauthorizedRequestCallback`** and, with it, the test-only `Box<T>: @unchecked Sendable` (the unsound shared-mutable cell that exists solely to observe that void callback). Pure "notify me on 401" needs no special API — it's already a `.completed(_, .failure)` with `error.statusCode == 401` on `events()`.
    - **4c — Retry policy.** Exponential backoff + jitter, max-attempts cap, `Retry-After` support, driven by the `isRetryable` classifier built in #2 (transient transport + 408/429/5xx).
    - **4d — Timeout policy.** Per-request and client-wide deadlines, surfaced through `NetworkingError.transport`.
    - **4e — Response validators.** Pluggable "is this response acceptable?" beyond the status code (content-type, envelope shape) — turns a 2xx-but-wrong into a typed failure.

5. **Optional `swift-http-types` substrate.** Apple's [`swift-http-types`](https://github.com/apple/swift-http-types) (version-independent `HTTPRequest`/`HTTPResponse`/`HTTPFields`; v1.6.0, Jun 2026) is now the standard low-level Swift HTTP currency. Add a lower-level request API built on it as a **separate SPM product**, so the core stays dependency-free.

6. **OpenAPI interoperability.** Apple's [Swift OpenAPI Generator](https://github.com/apple/swift-openapi-generator) is the type-safe-from-spec path (3.0/3.1, streaming, multipart, `OpenAPIURLSession` transport). Either offer an interop/transport example, or document clearly where Networking sits relative to it (the hand-written-client tier).

7. **HTTP cache semantics (evaluate).** The hand-rolled disk + `NSCache` (`cacheOrPurge*`) is fine for image/data caching but isn't HTTP caching: ETag/Last-Modified, `Cache-Control`, stale-while-revalidate, size limits, eviction. Decide whether to adopt `URLCache`/HTTP semantics or keep the bespoke cache scoped to downloads and say so.

8. **Package polish & release.** DocC docs, Swift Package Index metadata (`.spi.yml`), an examples app/package, a **CHANGELOG + semver notes** for the v8 breaking changes (major bump from 7.0.0), and a compatibility/benchmark matrix.

Each item is its own PR (some a short series).
