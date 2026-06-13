# API modernization plan

Tracking the move from the legacy callback/`old*` API to the async/await typed API,
and the test work that depends on it. CI runs the full suite against a local
`go-httpbin` (see `.github/workflows/ci.yml`), so integration tests are deterministic.

## Done

- [x] Migrate CI to GitHub Actions + local go-httpbin; remove dead CircleCI/Travis/buddybuild config & webhooks.
- [x] Split offline vs `*IntegrationTests`; revive multipart image-upload test.
- [x] Revive GET query-parameter tests on the new `get(_:parameters:)` API (incl. percent-encoding).
- [x] Fix new-API query handling: a query embedded in the path (e.g. `get("/x?a=1", parameters:)`) is now merged instead of being percent-encoded into the path (was a 404).
- [x] Add `delete(_:parameters:)` to the new API (DELETE params routed to the query, matching GET) + test.
- [x] Revive the cancellation suite on the new API (`CancellationIntegrationTests`): GET/POST/PUT/PATCH/DELETE via `Task.cancel()`, image download (thrown `URLError.cancelled`), and `cancelAllRequests()`, all deterministic via go-httpbin `/delay`. Added a `NetworkingError.cancelled` case so cancellation surfaces cleanly instead of as a generic `.unexpectedError`. Retired `testCancelRequestsReturnInMainThread` — "callback returns on the main thread" is an old-callback concept with no async/await equivalent.

## In progress: remove the legacy `old*` API (branch `feature/remove-old-api`)

Plan (decisions: add caching + statusCode to the new API):

- [ ] Add `statusCode` to `NetworkingResponse` (populate from the HTTP response).
- [ ] Add `cachingLevel:` to the new `get` and wire response caching into the async `handle()` path.
- [ ] Migrate all `old*` test call sites (66 across 12 files) to the new `get/post/put/patch/delete` + `NetworkingResponse`, mapping `JSONResult`/`dictionaryBody`/`.error.code` to `Result`/`body`/`NetworkingError`.
- [ ] Delete `oldGet/oldPost/oldPut/oldPatch/oldDelete`, `cancelOld*`, `cancel(_ requestID:)`, and now-unused private helpers.
- [ ] Full suite green against go-httpbin throughout.

## Open items

- [ ] **Remove `cancel(_ requestID:)`** (recommended). History (`git show 3b35350`, 2016): request methods returned a `UUID` that was stamped onto `URLSessionTask.taskDescription`, and `cancel(requestID:)` matched on it — its purpose was cancelling *one* of several concurrent requests to the *same URL*, which path-based cancel can't disambiguate. The async/await migration (#268) removed the ID-returning API and the `taskDescription` writer; a later commit re-added only the matcher, so it's been dead code (nothing sets `taskDescription`). The capability it provided is now covered natively by holding each request's `Task` and calling `.cancel()` — proven by `CancellationIntegrationTests.testCancelOneOfTwoConcurrentRequestsToSameURL`. Re-wiring `taskDescription` would just duplicate what `Task` already gives, so remove the method during the `old*` cleanup.
- [ ] **Remove the legacy `old*` API and migrate every remaining test to the new API.** Delete `oldGet`/`oldPost`/`oldPut`/`oldPatch`/`oldDelete` and `cancelOld*`; port the `*IntegrationTests` that still use them (GET/POST/PUT/PATCH/DELETE, Download, Networking, Response, Unauthorized) onto `get`/`post`/`put`/`patch`/`delete` + `NetworkingResponse`. This is the larger follow-up the query-param and DELETE work above feeds into.
