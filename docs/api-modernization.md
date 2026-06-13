# API modernization plan

Tracking the move from the legacy callback/`old*` API to the async/await typed API,
and the test work that depends on it. CI runs the full suite against a local
`go-httpbin` (see `.github/workflows/ci.yml`), so integration tests are deterministic.

**Keep the README in sync.** Any change to the public API (a migrated verb, a
renamed method, a changed return type) must update `README.md` in the same PR —
its code samples are the docs users copy, so a stale example is a broken one. Each
per-verb migration below includes swapping that verb's `old*` README examples to
the new API.

## Done

- [x] Migrate CI to GitHub Actions + local go-httpbin; remove dead CircleCI/Travis/buddybuild config & webhooks.
- [x] Split offline vs `*IntegrationTests`; revive multipart image-upload test.
- [x] Revive GET query-parameter tests on the new `get(_:parameters:)` API (incl. percent-encoding).
- [x] Fix new-API query handling: a query embedded in the path (e.g. `get("/x?a=1", parameters:)`) is now merged instead of being percent-encoded into the path (was a 404).
- [x] Add `delete(_:parameters:)` to the new API (DELETE params routed to the query, matching GET) + test.
- [x] Revive the cancellation suite on the new API (`CancellationIntegrationTests`): GET/POST/PUT/PATCH/DELETE via `Task.cancel()`, image download (thrown `URLError.cancelled`), and `cancelAllRequests()`, all deterministic via go-httpbin `/delay`. Added a `NetworkingError.cancelled` case so cancellation surfaces cleanly instead of as a generic `.unexpectedError`. Retired `testCancelRequestsReturnInMainThread` — "callback returns on the main thread" is an old-callback concept with no async/await equivalent.

## Removing the legacy `old*` API

Decisions: add caching + statusCode to the new API; migrate per-verb in separate PRs.

Foundation (this PR):

- [x] Add `statusCode` to `NetworkingResponse` (populated from the HTTP response).
- [x] Add `cachingLevel:` to the new `get` and wire response caching into the async `handle()` path (+ real cache-hit test; fixed a latent `remove(at:)` cache-miss bug).

Then, one verb per PR — migrate the `old*` test call sites to the new API and delete that verb's `old*`/`cancelOld*`:

- [x] `oldGet` → `get` (incl. the 3 GET cache tests); removed `oldGet`/`cancelOldGET`; updated README GET/auth/cancellation/faking examples.
- [x] `oldPost` → `post`. Extended the async `post`/`handle()` to full parity — optional params, `parameterType:` (form-URL-encoded/custom), and multipart `parts:` (new `httpBody(...)` serializer in the async path) — then migrated all sites and removed `oldPost`/`cancelOldPOST`; updated README POST examples.
- [x] `oldPut` → `put`. Extended `put` to `parameterType:`/optional params (reusing the `handle()` body path from the POST work; no multipart — `oldPut` had none); migrated all sites and removed `oldPut`/`cancelOldPUT`. No README PUT examples to update.
- [x] `oldPatch` → `patch`. Same shape as PUT — extended `patch` to `parameterType:`/optional params (no multipart), migrated all sites, removed `oldPatch`/`cancelOldPATCH`. No README PATCH examples to update.
- [x] `oldDelete` → `delete`. Gave `delete` optional-params overloads (`delete<T>` + `Result<Void>`, `parameters: Any? = nil`) so a no-param DELETE can still read its body/status/headers (params route to the query, like GET); migrated all sites and removed `oldDelete`/`cancelOldDELETE`. **This removes the last `old*` verb — the legacy request API is gone.** No README DELETE examples to update.
- [x] Remove `cancel(_ requestID:)` (dead matcher — nothing sets `taskDescription`) and the now-unused `handleJSONRequest`. Verified the rest stays live: `requestData`/`handleDataRequest`/`handleImageRequest` (downloads), `handleFakeRequest`/`cacheOrPurgeJSON` (the async fake path), `cancelRequest` (image cancel), `cancelAllRequests` (cancellation suite) — so `cacheOrPurgeJSON` was *not* removable, contrary to the earlier guess.
- [ ] **Remove `JSONResult` / `NetworkingResult`.** The new API replaced it with `Result<T, NetworkingError>`, but it's not purely an old-path type yet: the async fake-request path still builds the fake response `Data` through `JSONResult(body:response:error:)` (`Networking+New.swift`, `handleFakeRequest`). Removing `JSONResult` needs that one usage decoupled first — serialize the fake `response: Any?` to `Data` inline — then delete `JSONResult` once the `old*` verbs (its only other users) are gone.

## Platform: raise the deployment target

- [ ] **Bump the minimum to iOS 18 and delete the `@available` annotations.** `Package.swift` targets `.iOS(.v16)/.macOS(.v13)/.tvOS(.v16)/.watchOS(.v9)`, and 8 `@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)` annotations guard the async API (`Networking.swift`, `Networking+Private.swift`, `Networking+HTTPRequests.swift` ×6). They're already redundant at iOS 16 and pure dead weight once the floor moves up. Raise `platforms` to `.iOS(.v18)` (+ matching `.macOS(.v15)` / `.tvOS(.v18)` / `.watchOS(.v11)`) and remove every such annotation.

## Open items

- [ ] **The test suite still references `http://httpbin.org`.** CI is deterministic because it sets `HTTPBIN_BASE_URL` to a local go-httpbin, but the string still appears in three different roles:
  1. **Integration fallback** — `TestConfig.httpbinBaseURL` falls back to `"http://httpbin.org"` when the env var is unset, so a bare local `swift test` sends the `*IntegrationTests` to the public host, which rate-limits to HTTP 503 and flakes. These tests need a server speaking the httpbin protocol; the suite exercises `/get`, `/post`, `/put`, `/patch`, `/delete`, `/status/N`, `/delay/N`, `/uuid`, `/image/png`, `/basic-auth/...`, `/user-agent`.
  2. **Offline suites** (`GETTests`, `NewNetworkingTests`, `FakeRequestTests`, `UnauthorizedCallbackTests`) — `let baseURL = "http://httpbin.org"` is an arbitrary base string for *faked* requests; the host is never contacted or asserted.
  3. **`NetworkingTests.swift`** — `httpbin.org` is sample data coupled to assertions about URL composition / cache-filename derivation (`composedURL` → `http://httpbin.org/hello`, `destinationURL.lastPathComponent` → `http:--httpbin.org-image-png`, `splitBaseURLAndRelativePath`). No server is involved.
- [ ] **Remove `cancel(_ requestID:)`** (recommended). History (`git show 3b35350`, 2016): request methods returned a `UUID` that was stamped onto `URLSessionTask.taskDescription`, and `cancel(requestID:)` matched on it — its purpose was cancelling *one* of several concurrent requests to the *same URL*, which path-based cancel can't disambiguate. The async/await migration (#268) removed the ID-returning API and the `taskDescription` writer; a later commit re-added only the matcher, so it's been dead code (nothing sets `taskDescription`). The capability it provided is now covered natively by holding each request's `Task` and calling `.cancel()` — proven by `CancellationIntegrationTests.testCancelOneOfTwoConcurrentRequestsToSameURL`. Re-wiring `taskDescription` would just duplicate what `Task` already gives, so remove the method during the `old*` cleanup.
- [ ] **Remove the legacy `old*` API and migrate every remaining test to the new API.** Delete `oldGet`/`oldPost`/`oldPut`/`oldPatch`/`oldDelete` and `cancelOld*`; port the `*IntegrationTests` that still use them (GET/POST/PUT/PATCH/DELETE, Download, Networking, Response, Unauthorized) onto `get`/`post`/`put`/`patch`/`delete` + `NetworkingResponse`. This is the larger follow-up the query-param and DELETE work above feeds into.
