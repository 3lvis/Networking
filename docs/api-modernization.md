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

## Open items

- [ ] **Revive the cancellation test suite on the new API.** Eight tests are currently commented out (`testCancel{GET,POST,PUT,PATCH,DELETE}WithPath`, `testCancelImageDownload`, `testCancelAllRequests`, `testCancelRequestsReturnInMainThread`). They were disabled because cancellation wasn't reliably testable. go-httpbin's `/delay/{n}` endpoint makes it deterministic now: fire a request at `/delay/5`, cancel via `Task.cancel()` / `cancelAllRequests()`, assert the result is a cancellation error. Rewrite to async/await; verify the library actually surfaces `URLError.cancelled` (this may expose unfinished cancel behavior). Use the new endpoints, not `old*`.
- [ ] **Remove the legacy `old*` API and migrate every remaining test to the new API.** Delete `oldGet`/`oldPost`/`oldPut`/`oldPatch`/`oldDelete` and `cancelOld*`; port the `*IntegrationTests` that still use them (GET/POST/PUT/PATCH/DELETE, Download, Networking, Response, Unauthorized) onto `get`/`post`/`put`/`patch`/`delete` + `NetworkingResponse`. This is the larger follow-up the query-param and DELETE work above feeds into.
