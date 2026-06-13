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

1. **Typed request bodies & builders — get off `Any`.** Request `parameters` and fake responses are `Any?` (`Networking+HTTPRequests.swift`), forcing runtime casts on the main path. Add `Encodable` request-body overloads (e.g. `post<Body: Encodable>(_:body:)`), typed query items, and typed headers so the common case is compile-checked. Keep the `Any?` overloads during transition. *No new dependency; biggest ergonomics/safety win.*

2. **Richer error model.** `NetworkingError` (`NetworkingError.swift`) collapses transport, decoding, server payload, cancellation, invalid-response, and "unexpected" into broad cases. Redesign around categories (transport / HTTP / decoding) that **preserve** the underlying `URLError`/`DecodingError`, response metadata, a redaction-safe body snippet, and retryability. Breaking — pairs with the error call sites.

3. **Structured observability — remove `print`.** `logError` writes to the console unconditionally (`Networking+Private.swift`). Replace with consumer-supplied structured logging hooks, `URLSessionTaskMetrics`, request IDs, redaction, and optional signposts. No unconditional printing.

4. **Request/response middleware.** Composable retry/backoff, timeout policy, auth-refresh, request adapters/interceptors, and response validators — table stakes for a serious client.

5. **Optional `swift-http-types` substrate.** Apple's [`swift-http-types`](https://github.com/apple/swift-http-types) (version-independent `HTTPRequest`/`HTTPResponse`/`HTTPFields`; v1.6.0, Jun 2026) is now the standard low-level Swift HTTP currency. Add a lower-level request API built on it as a **separate SPM product**, so the core stays dependency-free.

6. **OpenAPI interoperability.** Apple's [Swift OpenAPI Generator](https://github.com/apple/swift-openapi-generator) is the type-safe-from-spec path (3.0/3.1, streaming, multipart, `OpenAPIURLSession` transport). Either offer an interop/transport example, or document clearly where Networking sits relative to it (the hand-written-client tier).

7. **HTTP cache semantics (evaluate).** The hand-rolled disk + `NSCache` (`cacheOrPurge*`) is fine for image/data caching but isn't HTTP caching: ETag/Last-Modified, `Cache-Control`, stale-while-revalidate, size limits, eviction. Decide whether to adopt `URLCache`/HTTP semantics or keep the bespoke cache scoped to downloads and say so.

8. **Package polish & release.** DocC docs, Swift Package Index metadata (`.spi.yml`), an examples app/package, a **CHANGELOG + semver notes** for the v8 breaking changes (major bump from 7.0.0), and a compatibility/benchmark matrix.

Each item is its own PR (some a short series).
