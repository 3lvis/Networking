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

## Open items

- [ ] **Fix or remove `cancel(_ requestID:)`.** It matches `URLSessionTask.taskDescription == requestID`, but nothing in the library ever *sets* `taskDescription`, so it can never match a task — it's currently dead code. Either wire a request ID through the request pipeline (set `taskDescription` when creating the request, expose a way to pass/return the ID) and add a test, or remove the method. Not addressed in the cancellation-suite PR because it needs an API change, not just a test.
- [ ] **Remove the legacy `old*` API and migrate every remaining test to the new API.** Delete `oldGet`/`oldPost`/`oldPut`/`oldPatch`/`oldDelete` and `cancelOld*`; port the `*IntegrationTests` that still use them (GET/POST/PUT/PATCH/DELETE, Download, Networking, Response, Unauthorized) onto `get`/`post`/`put`/`patch`/`delete` + `NetworkingResponse`. This is the larger follow-up the query-param and DELETE work above feeds into.
