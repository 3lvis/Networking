# Networking — repo notes

Async HTTP client for Apple platforms. **iOS 18+ / Swift 6** (`swift-tools 6.2`, language mode `[.v6]`).

## Build & test

- `make test` — spins up go-httpbin in Docker, runs the full suite against it, tears it down. **Requires Docker.**
- `make httpbin` / `make httpbin-stop` — run go-httpbin on `:8080` while you iterate with plain `swift test`.
- Integration tests need a server speaking the httpbin protocol; `TestConfig.httpbinBaseURL` defaults to `http://127.0.0.1:8080` (CI sets the same). The offline / `fake*` suites need no server. Without go-httpbin running, integration tests fail fast (connection refused) — that's intended, not a flake.
- CI: `macos-15` / Xcode 26.3 / Swift 6.2.x.

## Architecture (current)

- **`Networking` is a `public actor`.** Safe to share one instance across tasks; isolated members are accessed with `await`. Config is via async setters — `setAuthorizationHeader`, `setHeaderFields`, `setUnauthorizedRequestCallback`, `setErrorLoggingEnabled` (actors forbid external property mutation). No subclassing.
- **Verbs:** `get`/`post`/`put`/`patch`/`delete` → `Result<T, NetworkingError>`. Pick `T`: any `Decodable` model, `Data`, `Void`, or `JSONResponse` (`{ statusCode, headers, body }`) when you want metadata. `post`/`put`/`patch` also take `parameterType:` (JSON/form-URL-encoded/custom) and multipart `parts:`.
- **Downloads:** `downloadImage`/`downloadData` → `Result<T, NetworkingError>` where `T` is the payload (`Image`/`Data`) or an envelope (`ImageResponse`/`DataResponse`).
- **Fakes (testing):** `fakeGET`/`fakePOST`/… register canned responses; the `fileName:` variants load a bundled file as raw `Data`. Errors are `NetworkingError`.
- Request `parameters` and fake responses are still `Any?` — see roadmap #1 (typed `Encodable` bodies) for the planned fix.

## Roadmap

`docs/roadmap.md`. The async/`Result`/Swift-6 modernization is done; next up (highest-leverage, dependency-free): typed `Encodable` request bodies (#1), a richer error model (#2), structured observability replacing `print` (#3).

## Conventions

- **Public-API change → update the README in the same PR.** Its snippets are copy-paste docs and must compile under the actor (isolated members need `await`).
- These were breaking changes vs the last release (7.0.0); the next tag is a major bump (roadmap #8).
