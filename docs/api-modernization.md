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

- [x] Add `statusCode` to `JSONResponse` (populated from the HTTP response).
- [x] Add `cachingLevel:` to the new `get` and wire response caching into the async `handle()` path (+ real cache-hit test; fixed a latent `remove(at:)` cache-miss bug).

Then, one verb per PR — migrate the `old*` test call sites to the new API and delete that verb's `old*`/`cancelOld*`:

- [x] `oldGet` → `get` (incl. the 3 GET cache tests); removed `oldGet`/`cancelOldGET`; updated README GET/auth/cancellation/faking examples.
- [x] `oldPost` → `post`. Extended the async `post`/`handle()` to full parity — optional params, `parameterType:` (form-URL-encoded/custom), and multipart `parts:` (new `httpBody(...)` serializer in the async path) — then migrated all sites and removed `oldPost`/`cancelOldPOST`; updated README POST examples.
- [x] `oldPut` → `put`. Extended `put` to `parameterType:`/optional params (reusing the `handle()` body path from the POST work; no multipart — `oldPut` had none); migrated all sites and removed `oldPut`/`cancelOldPUT`. No README PUT examples to update.
- [x] `oldPatch` → `patch`. Same shape as PUT — extended `patch` to `parameterType:`/optional params (no multipart), migrated all sites, removed `oldPatch`/`cancelOldPATCH`. No README PATCH examples to update.
- [x] `oldDelete` → `delete`. Gave `delete` optional-params overloads (`delete<T>` + `Result<Void>`, `parameters: Any? = nil`) so a no-param DELETE can still read its body/status/headers (params route to the query, like GET); migrated all sites and removed `oldDelete`/`cancelOldDELETE`. **This removes the last `old*` verb — the legacy request API is gone.** No README DELETE examples to update.
- [x] Remove `cancel(_ requestID:)` (dead matcher — nothing sets `taskDescription`) and the now-unused `handleJSONRequest`. Also stripped `requestData`'s body-serialization `switch` and its `parameterType`/`parameters`/`parts` params: its only remaining callers are the downloads, which always pass nil, so that block (the legacy twin of the new `httpBody(...)`) was dead — `httpBody` is now the sole serializer. Verified the rest stays live: `requestData`/`handleDataRequest`/`handleImageRequest` (downloads), `handleFakeRequest`/`cacheOrPurgeJSON` (the async fake path), `cancelRequest` (image cancel), `cancelAllRequests` (cancellation suite) — so `cacheOrPurgeJSON` was *not* removable, contrary to the earlier guess.
- [x] **Remove `JSONResult` and its result-model cluster.** Decoupled the async fake path: `handleFakeRequest` now serializes the fake `response: Any?` to `Data` inline (success/failure routes off the fake's HTTP status code, as before). Then deleted `JSONResult`, the already-dead `GenericResult`/`VoidResult`, and the now-orphaned `JSONResponse`/`SuccessJSONResponse`/`FailureJSONResponse` (+ the 6 `JSONResult` `ResultTests`). Kept the `NetworkingResult` protocol and `ImageResult`/`DataResult` (+ their response types) — still used by the data/image downloads — so the plan's "remove `NetworkingResult`" was too broad. (The `JSON` enum was left in place here, then removed in #299 once it proved to have no callers.)
## Remaining work (in priority order)

1. **Migrate the downloads to `Result`, payload-or-envelope, then delete the legacy result/response hierarchy.** `downloadImage`/`downloadData` are the only remaining users of the bespoke result model — and they're oddly `async throws -> ImageResult`/`DataResult` (throwing *and* returning a result enum). Give them the same shape as the verbs: `Result<T, NetworkingError>` where you pick the bare payload **or** an envelope that also carries `statusCode`/`headers`:
   - New envelopes `ImageResponse` (`{ statusCode, headers, image }`) and `DataResponse` (`{ statusCode, headers, data }`).
   - `downloadImage<T>(...) -> Result<T, NetworkingError>` with `T = Image` or `T = ImageResponse`; `downloadData<T>(...)` with `T = Data` or `T = DataResponse`. **Constrain `T`** via marker protocols (e.g. `ImageDownloadable`/`DataDownloadable`, each with a factory `make(payload:statusCode:headers:)`) so only the valid types compile — no unconstrained generic, no runtime "unknown T" fallback. (Cleaner than the verbs' current `T.self ==` dispatch; could retrofit the verbs later.)
   - A failure always carries the status via `NetworkingError`.
   - Tests cover **both** forms (bare payload + envelope) for each, to lock the contract and guard regressions.
   - Then delete the `NetworkingResult` protocol, `ImageResult`, `DataResult`, and the `Response`/`SuccessImageResponse`/`SuccessDataResponse`/`FailureResponse` classes. Public API change → its own PR.
   - *Why first:* highest value — completes the modernization's core promise (one `Result<…, NetworkingError>` everywhere, payload-or-envelope), removes the largest remaining chunk of legacy types, and unblocks #3.

2. ~~**Rename `NetworkingResponse` → `JSONResponse`.**~~ ✅ Done. Renamed the type (and `NetworkingResponse.swift` → `JSONResponse.swift`) and all ~100 references across sources, tests, and the README — symmetric with `ImageResponse`/`DataResponse`. Pure mechanical rename; suite stayed green.

3. ~~**Purge the public httpbin host from the test suite.**~~ ✅ Done — handled by role:
   1. **Integration fallback** — `TestConfig.httpbinBaseURL` now defaults to `"http://127.0.0.1:8080"` (matching CI's go-httpbin), so a bare local `swift test` fails fast with connection-refused instead of flaking against the public host.
   2. **Offline suites** (`GETTests`, `NewNetworkingTests`, `FakeRequestTests`, `UnauthorizedCallbackTests`) — `baseURL` now reads `TestConfig.httpbinBaseURL` (faked requests; host never contacted).
   3. **`NetworkingTests.swift`** — URL-composition / cache-filename sample data switched to `example.com` (input and expected sides together).
   4. **README** — every public-host snippet switched to `http://example.com` too, so there's zero reference left anywhere in the repo.
   - DX: added a `Makefile` (`make test` spins up go-httpbin in Docker, runs the suite, tears it down; `make httpbin`/`httpbin-stop` for iterating) + a "Running the tests" README section, now that the default is `127.0.0.1:8080`.

4. ~~**Drop the internal `JSON` enum.**~~ ✅ Done — and simpler than expected: the `JSON` enum had **no production callers left** (its last user, the old `JSONResponse` class, went in #295; `FileManager.json`/`cacheOrPurgeJSON` use `JSONSerialization` + `Data.toJSON()` directly, not the enum). So it was dead code — deleted the enum and its `==`, plus the enum-only `JSONTests`. Kept `ParsingError`, `FileManager.json`, and `Data.toJSON()` for the moment.
   - **Follow-up (audit):** those three turned out to be over-built too. They existed only to back the file-based fake feature (`fakeGET(_:fileName:)` etc.), by parsing the file to `Any?` — which the async fake path then *re-serialized* back to `Data` (a pointless `Data → Any? → Data` round-trip), and `Data.toJSON()` was needlessly `public`. Changed `registerFake(fileName:)` to load the file as raw `Data` and store it directly (the async path serves `Data` as-is), then deleted all of `JSON.swift` (`ParsingError`/`FileManager.json`/`Data.toJSON`) and the helper-only `JSONTests`/`JSONIntegrationTests`. The feature stays covered by the existing `*UsingFile` fake tests. Trade-off: invalid-JSON fixtures now fail at decode time rather than at registration — fine for a test helper.

5. ~~**Bump to iOS 18 + drop the `@available` annotations.**~~ ✅ Done. `platforms` raised to `.iOS(.v18)`/`.macOS(.v15)`/`.tvOS(.v18)`/`.watchOS(.v11)`, all 8 `@available(iOS 15.0, …)` annotations removed. `.iOS(.v18)` required `swift-tools-version: 6.0`, which defaults to Swift 6 language mode — pinned `swiftLanguageModes: [.v5]` to keep this a pure platform bump, not a concurrency migration (that's #7). CI (`macos-15`, Xcode 26.2) already supports tools 6.0, so no CI change needed.

6. ~~**Evaluate: give the verbs the same constrained-`T` treatment as the downloads.**~~ ✅ Evaluated — **decision: keep the verbs as-is, don't constrain.** The pattern doesn't transfer:
   - Downloads have a *closed* set (`{Image, ImageResponse}` / `{Data, DataResponse}`) whose members **aren't `Decodable`** — a custom protocol was needed anyway, so it added real compile-time safety (only valid types compile) at zero cost to callers (the types are ours).
   - The verbs accept an *open* set — **any `Decodable`** (the point: callers decode into their own models). Every valid `T` is already `Decodable` (`Data` and `JSONResponse` both conform), so there's **no invalid `T` to reject**. A marker protocol would force every caller's model to conform to a bespoke protocol instead of plain `Decodable` — strictly worse ergonomics — for zero safety gain, and the `Data`/`JSONResponse` special cases would fight Swift's static-dispatch-on-protocol-extension rules.
   - The two `T.self ==` checks in `handleSuccessfulResponse` are cheap, localized *semantic* special-casing (return empty `Data`; build the envelope), not a type-safety gap. Leave them.

7. ~~**Full tooling upgrade — Swift 6 language mode, keep iOS 18.**~~ ✅ Done, and more contained than feared (one PR, not a series). Flipped `swiftLanguageModes` to `[.v6]`. The strict-concurrency fallout was small and centred on `Sendable`:
   - Response/error types made `Sendable`: `JSONResponse`/`DataResponse` (plain `Sendable`), `AnyCodable`/`ImageResponse` (`@unchecked Sendable` — immutable boxes whose only un-provable field is `Any`/the platform `Image`), and `NetworkingError.serverError`'s `details: [String: Any]?` → `[String: any Sendable]?` (its values were always `String`/`[String: [String]]`).
   - `Networking` → `@unchecked Sendable`: `URLSession`/`NSCache` are thread-safe and the mutable config/fakes are set before requests run, so sharing across tasks is safe in practice (a full `actor` rewrite would change the whole API surface — deliberately not done).
   - One test (`testFakeDELETEMultiple`) converted from `Task` + `waitForExpectations` to `async`/`await`, removing a non-`Sendable` `self` capture.
   - Pinned `swift-tools-version: 6.2` — the latest CI's toolchain supports (`macos-15` / Xcode 26.2 / Swift 6.2.3, confirmed from the CI `Versions` log); 6.3 would break CI since a 6.2 toolchain can't parse a 6.3 manifest. No workflow change needed.

8. **Consider rewriting `Networking` as an `actor` (replace the `@unchecked Sendable`).** #7 made `Networking` `@unchecked Sendable` — a *promise* the compiler doesn't verify. It holds today (`URLSession`/`NSCache` are thread-safe; `headerFields`/`token`/`fakeRequests` are set before requests), but nothing stops a future change from mutating `fakeRequests`/config concurrently with in-flight requests and racing. An `actor` would make that safety **compiler-checked** instead of asserted. Cost: it reshapes the public surface — every property/method access becomes `await`-isolated, `fakeXXX(...)` registration and `headerFields`/`token` setters included, and `open class` subclassing goes away (actors can't be subclassed). Evaluate whether the stronger guarantee is worth the API churn, or whether the `@unchecked` pragmatic stance is acceptable for this library. (Same question applies to the `@unchecked Sendable` on `AnyCodable`/`ImageResponse`, though those are immutable and far lower-risk.)
