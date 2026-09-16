# Networking — repo notes

Async HTTP client for Apple platforms. **iOS 18+ / Swift 6** (`swift-tools 6.2`, language mode `[.v6]`).
The iOS-shared and global conventions in the parent `AGENTS.md` files still apply; this layer adds only
what's specific to this repo. Release history and the v8 (major) notes live in `CHANGELOG.md`.

[`LEARNINGS.md`](LEARNINGS.md) holds what sessions keep running into, searched by symptom. Yours goes in a
file of its own, `LEARNINGS/<YYYY-MM-DD-HHMM>-<slug>.md`, so branches writing at once stay clear of each
other. Leave the filing, the grouping and the graduating to the periodic pass that document describes.

[`VOICE.md`](VOICE.md) is how we write — PRs, commits, comments, docs, error copy — and it carries the
Swift API Design Guidelines whole, so a naming question is answered by reading it. Read it before you write.

## Build & test

- `make test` — spins up go-httpbin in Docker, runs the full suite, tears it down. **Requires Docker.**
- `make httpbin` / `make httpbin-stop` — run go-httpbin on `:8080` to iterate with plain `swift test`.
- `swift build` — library only; CI also fails on any first-party `warning:`.
- Integration tests need go-httpbin (`TestConfig.httpbinBaseURL`, default `http://127.0.0.1:8080`). Without it
  they fail fast (connection refused) — intended behaviour rather than a flake. The offline / `fake*` suites run on their own.
- Formatting: `.swift-format` (120 cols, 4-space). Run `./scripts/setup.sh` once per clone to enable the
  `.githooks/pre-commit` hook (formats staged Swift files); CI's format check is the backstop.
- CI: the `xcode-27` runner image / Xcode 27 / Swift 6.4, the same toolchain as local — CI is the gate.
  Jobs: swift-format check, build & test (go-httpbin), a warnings gate, and a dead-doc-link check
  (`scripts/check-doc-links.py`).

## Source map

- `Networking.swift` — the `public actor`: config (auth/headers/interceptors/log/`cacheTTL` via async
  setters), `events()`, URL composition, public cache entry points (`clearCache`/`reset`/`destinationURL`).
- `Networking+HTTPRequests.swift` — the public surface: verb overloads (`get`/`post`/…), `downloadImage`/
  `downloadData`, and the `fake*` helpers.
- `Networking+New.swift` — request execution: the `RequestBody` enum, `createRequest`, the interceptor fold
  (`perform`), response→`Result` mapping, the completion funnel (`complete`/`logCompletion`), `mapThrownError`.
- `Networking+Private.swift` — download handlers + the cache shims that delegate to `CacheStore`.
- `Networking+FormEncoding.swift` — flat-`Encodable` → `[String: String]` for forms/queries.
- `CacheStore.swift` / `CacheExpiry.swift` — the two-tier disk cache (layout, sharding, sweep, TTL).
- `HTTPInterceptor.swift` — the middleware seam + `AuthRefreshInterceptor` / `RetryInterceptor` /
  `ResponseValidatorInterceptor`.
- `NetworkingError.swift` — the categorized error model + `ResponseMetadata`.
- `NetworkingEvent.swift` — the `events()` types (`NetworkingEvent` / `RequestContext` / `Outcome` /
  `TransactionMetrics`).
- `JSONResponse` · `DownloadResponse` · `FakeRequest` · `FormDataPart` · `Image` · `Helpers` — supporting types.

## Architecture invariants

Cross-file contracts an agent must hold; the *why* lives in each file's comments.

- **Actor isolation.** `Networking` is an actor — isolated members need `await`, config is async setters
  (mutation goes through them alone), and the type is final.
- **Typed bodies, chosen by the method.** The method picks the encoding (`body:` JSON / `form:` url-encoded /
  `parts:`+`fields:` multipart / `data:contentType:` raw; `query:` for get/delete), via the `RequestBody`
  enum. `T` ∈ any `Decodable` · `Data` · `Void` · `JSONResponse`.
- **Errors say *where* it failed**, each a typed case; the core hands the error body on untouched —
  `ResponseMetadata.body` is the full bytes, the caller decodes its own envelope.
- **Interceptors are an onion *below* the decode layer**, over a raw `HTTPExchange`; registered
  outermost-first, `next` replays. Downloads route through too; a GET cache hit flows back out through the
  chain (the cache is the innermost layer).
- **Cache reads are pure.** `.memory`/`.none` stay in memory, so a read leaves a durable
  `.memoryAndFile` copy — purging belongs to the write path and `clearCache`. Sliding TTL keyed on file
  mtime; sharded layout; one-shard-per-launch background sweep. The `NSCache` warm tier can be evicted by
  iOS at any time — disk is the durable fallback.
- **Observability is one hook:** `events()` (multi-consumer `AsyncStream`). Built-in logging is separate,
  synchronous, gated by `logLevel`; redaction is log-path only, so `events()` carries the real headers.
- **Region-isolation trap (Swift 6.2):** before building the `@Sendable` interceptor chain, read actor
  state (`session`/`collector`) into locals, so the closure captures values alone.

## Boundaries

- **Always** run `make test` (Docker) to green and keep the build warning-free before claiming done.
- **Always** update `README.md` and `CHANGELOG.md` in the same PR as any public-API change — the README
  snippets are copy-paste docs and must compile under the actor (`await`).
- **Ask first** before adding a third-party dependency — the core is intentionally dependency-free.
- **Keep cache purging off the read path**: `.memory`/`.none` reads must stay pure, or an
  evicted warm tier turns a recoverable miss into permanent loss.
