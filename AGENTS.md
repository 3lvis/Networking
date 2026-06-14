# Networking — repo notes

Async HTTP client for Apple platforms. **iOS 18+ / Swift 6** (`swift-tools 6.2`, language mode `[.v6]`).

## Build & test

- `make test` — spins up go-httpbin in Docker, runs the full suite against it, tears it down. **Requires Docker.**
- `make httpbin` / `make httpbin-stop` — run go-httpbin on `:8080` while you iterate with plain `swift test`.
- Integration tests need a server speaking the httpbin protocol; `TestConfig.httpbinBaseURL` defaults to `http://127.0.0.1:8080` (CI sets the same). The offline / `fake*` suites need no server. Without go-httpbin running, integration tests fail fast (connection refused) — that's intended, not a flake.
- CI: `macos-15` / Xcode 26.3 / Swift 6.2.x.

## Architecture (current)

- **`Networking` is a `public actor`.** Safe to share one instance across tasks; isolated members are accessed with `await`. Config is via async setters — `setAuthorizationHeader`, `setHeaderFields`, `setUnauthorizedRequestCallback`, `setErrorLoggingEnabled` (actors forbid external property mutation). No subclassing.
- **Verbs:** `get`/`post`/`put`/`patch`/`delete` → `Result<T, NetworkingError>`. Pick `T`: any `Decodable` model, `Data`, `Void`, or `JSONResponse` (`{ statusCode, headers, body }`) when you want metadata.
- **Typed bodies — no `Any`.** The encoding is chosen by the method, not an untyped `parameters:`/`parameterType:` pair (`Networking+HTTPRequests.swift`): `post`/`put`/`patch` take `body:` (any `Encodable` → JSON, ISO-8601 dates), `form:` (any flat `Encodable` → url-encoded), `parts:`+`fields:` (multipart), or `data:contentType:` (raw); `get`/`delete` take `query:` (a `[URLQueryItem]` for ordering/dupes, or any flat `Encodable`). `form:`/`query:` flatten an `Encodable` to `[String: String]` via `formFields` in `Networking+FormEncoding.swift` (JSON bridge + scalar re-decode so `Bool`→"true", not NSNumber "1"). Bodies flow through the typed `RequestBody` enum in `Networking+New.swift`.
- **Downloads:** `downloadImage`/`downloadData` → `Result<T, NetworkingError>` where `T` is the payload (`Image`/`Data`) or an envelope (`ImageResponse`/`DataResponse`).
- **Fakes (testing):** `fakeGET`/`fakePOST`/… take `response:` over any `Encodable` (encoded to JSON), a no-body overload for status-only fakes, or `fileName:` for bundled raw `Data`; `FakeRequest` holds a typed `Payload` enum.
- **Errors (`NetworkingError.swift`):** categorized by where the failure happened — `invalidRequest(InvalidRequestReason)`, `transport(URLError)`, `http(HTTPError)`, `decoding(DecodingError, ResponseMetadata)`, `invalidResponse`, `cancelled`. `HTTPError` carries `statusCode`/`serverMessage`/`isClientError`/`isServerError`/`metadata`; cross-cutting `statusCode`, `responseMetadata`, and conservative `isRetryable` (transient transport + 408/429/5xx). Construction lives in `Networking+New.swift` (`handleResponse`/`handleSuccessfulResponse`/`mapThrownError`).

## Roadmap

`docs/roadmap.md`. The async/`Result`/Swift-6 modernization is done; #1 (typed request API — fully off `Any`) and #2 (richer error model) have landed. Next up (highest-leverage, dependency-free): structured observability replacing `print` (#3).

## Conventions

- **Public-API change → update the README in the same PR.** Its snippets are copy-paste docs and must compile under the actor (isolated members need `await`).
- These were breaking changes vs the last release (7.0.0); the next tag is a major bump (roadmap #8).
