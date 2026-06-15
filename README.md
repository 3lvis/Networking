![Networking](https://raw.githubusercontent.com/3lvis/Networking/1702d0e4575947ad12583b8f94a5ba1953804efc/.github/cover-v3.png)

**Networking** was born out of the necessity of having a networking library that has a straightforward API that supports faking requests and caching images out of the box.

- Friendly API
- Singleton free
- No external dependencies
- Minimal implementation
- Fully unit tested
- Simple request cancellation
- Fake requests easily (mocking/stubbing)
- Flexible caching
- Image downloading

## Table of Contents

* [Choosing a configuration](#choosing-a-configuration)
* [Changing request headers](#changing-request-headers)
* [Authenticating](#authenticating)
    * [HTTP basic](#http-basic)
    * [Bearer token](#bearer-token)
    * [Custom authentication header](#custom-authentication-header)
* [Making a request](#making-a-request)
  * [The basics](#the-basics)
  * [The Result type](#the-result-type)
  * [Handling errors](#handling-errors)
  * [Typed request bodies](#typed-request-bodies)
* [Choosing how the body is encoded](#choosing-how-the-body-is-encoded)
    * [JSON](#json)
    * [URL-encoding](#url-encoding)
    * [Multipart](#multipart)
    * [Raw data](#raw-data)
    * [Query items](#query-items)
* [Cancelling a request](#cancelling-a-request)
* [Faking a request](#faking-a-request)
* [Downloading and caching an image](#downloading-and-caching-an-image)
* [Observing requests](#observing-requests)
* [Updating the Network Activity Indicator](#updating-the-network-activity-indicator)
* [Installing](#installing)
* [Author](#author)
* [License](#license)
* [Attribution](#attribution)

## Choosing a configuration

Initializing an instance of **Networking** means you have to select a [URLSessionConfiguration](https://developer.apple.com/documentation/foundation/urlsessionconfiguration). The available types are `.default`, `.ephemeral` and `.background`, if you don't provide any or don't have special needs then `default` will be used.

 - `.default`: The default session configuration uses a persistent disk-based cache (except when the result is downloaded to a file) and stores credentials in the user’s keychain.

- `.ephemeral`: An ephemeral session configuration object is similar to a default session configuration object except that the corresponding session object does not store caches, credential stores, or any session-related data to disk. Instead, session-related data is stored in RAM. The only time an ephemeral session writes data to disk is when you tell it to write the contents of a URL to a file. The main advantage to using ephemeral sessions is privacy. By not writing potentially sensitive data to disk, you make it less likely that the data will be intercepted and used later. For this reason, ephemeral sessions are ideal for private browsing modes in web browsers and other similar situations.

- `.background`: This configuration type is suitable for transferring data files while the app runs in the background. A session configured with this object hands control of the transfers over to the system, which handles the transfers in a separate process. In iOS, this configuration makes it possible for transfers to continue even when the app itself is suspended or terminated.

```swift
// Default
let networking = Networking(baseURL: "http://example.com")

// Ephemeral
let networking = Networking(baseURL: "http://example.com", configuration: .ephemeral)
```

`Networking` is an `actor`, so it's safe to share one instance across tasks. Its members are accessed with `await` (e.g. `await networking.setAuthorizationHeader(...)`), and it can't be subclassed.

## Changing request headers

You can set the `headerFields` in any networking object.

This will append (if not found) or overwrite (if found) what NSURLSession sends on each request.

```swift
await networking.setHeaderFields(["User-Agent": "your new user agent"])
```

## Authenticating

### HTTP basic

To authenticate using [basic authentication](http://www.w3.org/Protocols/HTTP/1.0/spec.html#BasicAA) with a username **"aladdin"** and password **"opensesame"** you only need to do this:

```swift
let networking = Networking(baseURL: "http://example.com")
await networking.setAuthorizationHeader(username: "aladdin", password: "opensesame")
let result: Result<JSONResponse, NetworkingError> = await networking.get("/basic-auth/aladdin/opensesame")
// Successfully authenticated!
```

### Bearer token

To authenticate using a [bearer token](https://tools.ietf.org/html/rfc6750) **"AAAFFAAAA3DAAAAAA"** you only need to do this:

```swift
let networking = Networking(baseURL: "http://example.com")
await networking.setAuthorizationHeader(token: "AAAFFAAAA3DAAAAAA")
let result: Result<JSONResponse, NetworkingError> = await networking.get("/get")
// Successfully authenticated!
```

### Custom authentication header

To authenticate using a custom authentication header, for example **"Token token=AAAFFAAAA3DAAAAAA"** you would need to set the following header field: `Authorization: Token token=AAAFFAAAA3DAAAAAA`. Luckily, **Networking** provides a simple way to do this:

```swift
let networking = Networking(baseURL: "http://example.com")
await networking.setAuthorizationHeader(headerValue: "Token token=AAAFFAAAA3DAAAAAA")
let result: Result<JSONResponse, NetworkingError> = await networking.get("/get")
// Successfully authenticated!
```

Providing the following authentication header `Anonymous-Token: AAAFFAAAA3DAAAAAA` is also possible:

```swift
let networking = Networking(baseURL: "http://example.com")
await networking.setAuthorizationHeader(headerKey: "Anonymous-Token", headerValue: "AAAFFAAAA3DAAAAAA")
let result: Result<JSONResponse, NetworkingError> = await networking.get("/get")
// Successfully authenticated!
```

### Refreshing an expired credential

When a token expires, the server answers `401`/`403`. Rather than failing that request, register an `AuthRefreshInterceptor`: on an unauthorized response it runs your `refresh` closure, then **replays** the request once with the new credential. Return `nil` from `refresh` to give up and let the original failure through.

```swift
let networking = Networking(baseURL: "http://example.com")
await networking.setInterceptors([
    AuthRefreshInterceptor {
        let token = try await myAuth.refreshAccessToken()   // your refresh call
        await networking.setAuthorizationHeader(token: token) // keep future requests authed
        return "Bearer \(token)"                            // …and replay this one with it
    }
])
```

Concurrent requests that all hit `401` at once share a **single** refresh — they wait on the one in flight instead of each firing their own (no token-refresh stampede). For pure *notification* of a `401` (no replay), you don't need an interceptor — it's already a `.completed(_, .failure)` with `error.statusCode == 401` on [`events()`](#observing-requests).

`AuthRefreshInterceptor` is one implementation of the general `HTTPInterceptor` seam — an async `intercept(_:next:)` hook that wraps every verb request. Calling `next` runs the rest of the chain (the innermost being the real network call); calling it again replays.

### Retrying transient failures

`RetryInterceptor` retries a request when it fails transiently — a dropped connection or timeout, or an HTTP status in `retryableStatusCodes` (`408`/`429`/`500`/`502`/`503`/`504` by default, the same set behind [`NetworkingError.isRetryable`](#handling-errors)). It backs off exponentially with full jitter between attempts (capped at `maxDelay`) and honors a server's `Retry-After` header (seconds or HTTP-date) when present.

```swift
await networking.setInterceptors([
    RetryInterceptor(maxAttempts: 3, baseDelay: .milliseconds(500), maxDelay: .seconds(30))
])
```

**Only idempotent methods are retried by default** (`GET`/`HEAD`/`PUT`/`DELETE`/`OPTIONS`/`TRACE`). Retrying a `POST`/`PATCH` after a timeout or 5xx could duplicate a side effect — a second charge, a duplicate mutation — because the server may have already processed the first attempt. If a non-idempotent endpoint is safe to retry (e.g. it takes an idempotency key), opt it in explicitly:

```swift
RetryInterceptor(retryableMethods: ["GET", "HEAD", "PUT", "DELETE", "POST"])
```

Interceptors run outermost-first, so order matters: put `RetryInterceptor` **before** `AuthRefreshInterceptor` to retry around a refreshed credential, or after to refresh around each retry.

```swift
await networking.setInterceptors([
    RetryInterceptor(),                                   // outer: retries the whole thing
    AuthRefreshInterceptor { "Bearer \(try await refresh())" },  // inner: refreshes on 401
])
```

Interceptors apply to **downloads** (`downloadImage`/`downloadData`) as well as the verbs.

## Making a request

### The basics

Making a request is as simple as just calling `get`, `post`, `put`, or `delete`.

**GET example**:

```swift
let networking = Networking(baseURL: "http://example.com")
let result: Result<JSONResponse, NetworkingError> = await networking.get("/get")
switch result {
case .success(let response):
    let body = response.body // [String: AnyCodable]
    let statusCode = response.statusCode
case .failure(let error):
    // Handle error
}
```

**POST example**:

```swift
struct Credentials: Encodable { let username: String; let password: String }

let networking = Networking(baseURL: "http://example.com")
let result: Result<JSONResponse, NetworkingError> = await networking.post("/post", body: Credentials(username: "jameson", password: "secret"))
// On success, response.body holds the echoed JSON below.
 /*
 {
     "json" : {
         "username" : "jameson",
         "password" : "secret"
     },
     "url" : "http://example.com/post",
     "data" : "{"password" : "secret","username" : "jameson"}",
     "headers" : {
         "Accept" : "application/json",
         "Content-Type" : "application/json",
         "Host" : "example.com",
         "Content-Length" : "44",
         "Accept-Language" : "en-us"
     }
 }
 */
```

You can get the response headers and status code inside the success.

```swift
let networking = Networking(baseURL: "http://example.com")
let result: Result<JSONResponse, NetworkingError> = await networking.get("/get")
switch result {
case .success(let response):
    let headers = response.headers // [String: AnyCodable]
    let statusCode = response.statusCode // Int
case .failure(let error):
    // Handle error
}
```

### The Result type

`get` returns Swift's [Result](https://developer.apple.com/documentation/swift/result) with two cases: `.success(let response)` and `.failure(let error)`. The success carries the decoded value, the failure a `NetworkingError`.

`get` is generic over any `Decodable`, so you can decode straight into your own model — no manual JSON digging:

```swift
struct Recipe: Decodable { let title: String }

let networking = Networking(baseURL: "http://fakerecipes.com")
let result: Result<[Recipe], NetworkingError> = await networking.get("/recipes")
switch result {
case .success(let recipes):
    // recipes is [Recipe] — fully typed, no optionals
    print(recipes.map(\.title))
case .failure(let error):
    // error is a NetworkingError — see "Handling errors" below
    print(error.localizedDescription)
}
```

Use `JSONResponse` as the type when you want the raw `statusCode`, `headers`, and `body` instead of a model.

### Handling errors

`NetworkingError` is categorized by *where* the request failed, so you can branch on the cause instead of parsing a message. Each case preserves the underlying error or response:

```swift
switch result {
case .success(let value):
    break
case .failure(let error):
    switch error {
    case .invalidRequest(let reason):
        // Couldn't build/encode the request — a caller-side bug. reason says which.
        break
    case .transport(let urlError):
        // Never reached the server: offline, DNS, TLS, timeout. The underlying URLError is intact.
        break
    case .http(let httpError):
        // A non-2xx response. httpError.statusCode, .serverMessage, .isClientError/.isServerError,
        // and .metadata (headers + a truncated body snippet).
        break
    case .decoding(let decodingError, let metadata):
        // 2xx but the body didn't match your type. The DecodingError and response metadata are preserved.
        break
    case .invalidResponse:
        break
    case .cancelled:
        break
    }
}
```

Two conveniences cut across the cases:

```swift
error.statusCode      // Int? — present for .http and .decoding
error.responseMetadata // ResponseMetadata? — status, headers, redaction-friendly body snippet
error.isRetryable      // Bool — conservative: transient transport failures + HTTP 408/429/5xx
```

`isRetryable` is deliberately conservative: only transport timeouts/connection failures and a small set of status codes (408, 429, 500, 502, 503, 504). A 4xx (other than 408/429), a decoding failure, or an invalid request is never reported as retryable.

### Typed request bodies

Just as the response side is generic over any `Decodable`, the request side is generic over any `Encodable`. `post`, `put`, and `patch` take a `body:` that's JSON-encoded for you and sent with `Content-Type: application/json` — so the body you send is compile-checked, never an untyped `[String: Any]` dictionary:

```swift
struct Credentials: Encodable {
    let username: String
    let password: String
}

let networking = Networking(baseURL: "http://example.com")
let body = Credentials(username: "jameson", password: "secret")

// Decode the response straight into your model…
let result: Result<Account, NetworkingError> = await networking.post("/login", body: body)

// …or ignore it with a Void result when you only care about success/failure.
let ack: Result<Void, NetworkingError> = await networking.put("/account", body: body)
```

`Date`s in the body are encoded as ISO-8601, matching how responses are decoded.

## Choosing how the body is encoded

Each encoding is a distinct, typed method — the method you call picks the `Content-Type`, so there's no untyped `parameters:`/`parameterType:` pair to get wrong.

### JSON

The common case: pass any `Encodable` as `body:`. It's serialized with `JSONEncoder` and sent as `application/json`.

```swift
let networking = Networking(baseURL: "http://example.com")
let result: Result<JSONResponse, NetworkingError> = await networking.post("/post", body: ["name": "jameson"])
// Successful post using `application/json` as `Content-Type`
```

### URL-encoding

Pass `form:` to send `application/x-www-form-urlencoded`; **Networking** percent-encodes it for you ([`Percent-encoding` / `URL-encoding`](https://en.wikipedia.org/wiki/Percent-encoding#The_application.2Fx-www-form-urlencoded_type)). `form:` takes any flat `Encodable` — a `[String: String]` or your own model — and stringifies scalars for you (`Bool` → `"true"`, not `"1"`):

```swift
let networking = Networking(baseURL: "http://example.com")

// A dictionary…
let result: Result<JSONResponse, NetworkingError> = await networking.post("/post", form: ["name": "jameson"])

// …or your own model.
struct SignIn: Encodable { let name: String; let remember: Bool }
let result2: Result<JSONResponse, NetworkingError> = await networking.post("/post", form: SignIn(name: "jameson", remember: true))
// Successful post using `application/x-www-form-urlencoded` as `Content-Type`
```

### Multipart

**Networking** provides a simple model to use `multipart/form-data`. A multipart request consists of appending one or several [FormDataPart](https://github.com/3lvis/Networking/blob/master/Sources/Networking/FormDataPart.swift) items to a request. The simplest multipart request would look like this.

```swift
let networking = Networking(baseURL: "https://example.com")
let imageData = imageToUpload.pngData()!
let part = FormDataPart(data: imageData, parameterName: "file", filename: "selfie.png")
let result: Result<JSONResponse, NetworkingError> = await networking.post("/image/upload", parts: [part])
// Successful upload using `multipart/form-data` as `Content-Type`
```

To send several parts, or string form fields alongside the files, pass `fields:`:

```swift
let networking = Networking(baseURL: "https://example.com")
let part1 = FormDataPart(data: imageData1, parameterName: "file1", filename: "selfie1.png")
let part2 = FormDataPart(data: imageData2, parameterName: "file2", filename: "selfie2.png")
let result: Result<JSONResponse, NetworkingError> = await networking.post("/image/upload", parts: [part1, part2], fields: ["username": "3lvis"])
// Do something
```

**FormDataPart Content-Type**:

`FormDataPart` uses `FormDataPartType` to generate the `Content-Type` for each part. The default `FormDataPartType` is `.Data` which adds the `application/octet-stream` to your part. If you want to use a `Content-Type` that is not available between the existing `FormDataPartType`s, you can use `.Custom("your-content-type)`.

### Raw data

To send bytes verbatim under a `Content-Type` you choose, pass `data:contentType:`.

```swift
let networking = Networking(baseURL: "http://example.com")
let result: Result<JSONResponse, NetworkingError> = await networking.post("/upload", data: imageData, contentType: "application/octet-stream")
// Successful upload using `application/octet-stream` as `Content-Type`
```

### Query items

`get` and `delete` carry their parameters in the URL query string. Pass typed `[URLQueryItem]` when you need ordering or repeated keys, or any flat `Encodable` model:

```swift
let networking = Networking(baseURL: "http://example.com")

// Explicit query items…
let result: Result<JSONResponse, NetworkingError> = await networking.get("/search", query: [URLQueryItem(name: "q", value: "swift")])

// …or a model.
struct Search: Encodable { let q: String; let page: Int }
let result2: Result<JSONResponse, NetworkingError> = await networking.get("/search", query: Search(q: "swift", page: 2))
// GET /search?q=swift&page=2
```

## Cancelling a request

Hold the `Task` running the request and call `cancel()` on it. A cancelled request fails with `NetworkingError.cancelled`.

```swift
let networking = Networking(baseURL: "http://example.com")
let task = Task {
    let result: Result<JSONResponse, NetworkingError> = await networking.get("/get")
    // On cancellation this is .failure(.cancelled)
}

// In another place
task.cancel()
```

## Faking a request

Faking a request means that after calling this method on a specific path, any call to this resource, will return what you registered as a response. This technique is also known as mocking or stubbing.

**Faking with successfull response**:

```swift
struct Story: Codable { let id: Int; let title: String }

let networking = Networking(baseURL: "https://example.com")
await networking.fakeGET("/stories", response: [Story(id: 47333, title: "Site Design: Aquest")])
let result: Result<[Story], NetworkingError> = await networking.get("/stories")
// .success carrying the stories
```

**Faking with contents of a file**:

If your file is not located in the main bundle you have to specify using the bundle parameters, otherwise `NSBundle.mainBundle()` will be used.

```swift
let networking = Networking(baseURL: baseURL)
await networking.fakeGET("/entries", fileName: "entries.json")
let result: Result<JSONResponse, NetworkingError> = await networking.get("/entries")
// Response with the contents of entries.json
```

**Faking with status code**:

If you do not provide a status code for this fake request, the default returned one will be 200 (SUCCESS), but if you do provide a status code that is not 2xx, then **Networking** returns `.failure(.http(HTTPError))` carrying that status code (and any parsed `serverMessage`) — see [Handling errors](#handling-errors).

Use the no-body overload (omit `response:`) for a status-code-only fake:

```swift
let networking = Networking(baseURL: "https://example.com")
await networking.fakeGET("/stories", statusCode: 500)
let result: Result<JSONResponse, NetworkingError> = await networking.get("/stories")
// .failure with status code 500
```

## Downloading and caching an image

**Downloading**:

```swift
let networking = Networking(baseURL: "http://example.com")
let result: Result<Image, NetworkingError> = await networking.downloadImage("/image/png")
switch result {
case .success(let image):
    // Do something with the downloaded image
case .failure(let error):
    // Handle error
}
```

Ask for `ImageResponse` instead of `Image` (or `DataResponse`/`Data` from `downloadData`) when you also need the response's `statusCode` and `headers`:

```swift
let result: Result<ImageResponse, NetworkingError> = await networking.downloadImage("/image/png")
// response.image, response.statusCode, response.headers
```

**Cancelling**:

```swift
let networking = Networking(baseURL: baseURL)
let task = Task {
    let result: Result<Image, NetworkingError> = await networking.downloadImage("/image/png")
    // On cancellation this is .failure(.cancelled)
}

// In another place
try await networking.cancelImageDownload("/image/png")
```

**Caching**:

**Networking** uses a multi-cache architecture when downloading images, the first time the `downloadImage` method is called for a specific path, it will store the results in disk (Documents folder) and in memory (NSCache), so in the next call it will return the cached results without hitting the network.

```swift
let networking = Networking(baseURL: "http://example.com")
let _: Result<Image, NetworkingError> = await networking.downloadImage("/image/png")
// Image from network

let _: Result<Image, NetworkingError> = await networking.downloadImage("/image/png")
// Image from cache
```

If you want to remove the downloaded image you can do it like this:

```swift
let networking = Networking(baseURL: "http://example.com")
let destinationURL = try networking.destinationURL(for: "/image/png")
if FileManager.default.fileExists(atPath: destinationURL.path) {
    try FileManager.default.removeItem(at: destinationURL)
}
```

**Faking**:

```swift
let networking = Networking(baseURL: baseURL)
let pigImage = UIImage(named: "pig.png")!
await networking.fakeImageDownload("/image/png", image: pigImage)
let result: Result<Image, NetworkingError> = await networking.downloadImage("/image/png")
// Here you'll get the provided pig.png image
```

## Observing requests

**Networking** doesn't print to the console. Two separate things give you visibility: a **failure log** that's on by default (next section), and an **event stream** you can hook for the full lifecycle.

`events()` returns an `AsyncStream<NetworkingEvent>` — one `.started` then one `.completed` for **every** request (verbs *and* downloads). Iterate it with `for await`, accumulating into plain local state (no callback-capture gymnastics):

```swift
let stream = await networking.events()
Task {
    for await event in stream {
        switch event {
        case let .started(context):
            print("→ [\(context.id)] \(context.method) \(context.url?.absoluteString ?? "")")
        case let .completed(context, outcome, duration, metrics):
            switch outcome {
            case let .success(statusCode, byteCount):
                print("← [\(context.id)] \(statusCode) (\(byteCount) bytes) in \(duration)")
            case let .failure(error):
                print("✗ [\(context.id)] \(error.localizedDescription) — retryable: \(error.isRetryable)")
            }
            if let metrics { print("   DNS \(metrics.domainLookup ?? 0)s · TLS \(metrics.secureConnection ?? 0)s") }
        }
    }
}
```

- `RequestContext` carries a unique `id` (shared by the request's `.started`/`.completed`, and stamped into the failure logs), plus `method`, `url`, and the real request `headers` (events() is your own data — see *Privacy* below for why these aren't redacted).
- `.completed` carries the `Outcome` (`.success(statusCode:byteCount:)` / `.failure(NetworkingError)`), the measured `duration`, and — for real network requests — `TransactionMetrics` distilled from `URLSessionTaskMetrics` (DNS / connect / TLS / request / response timings, byte counts, redirect count, cache hit).
- Each `events()` call returns its own stream, so multiple consumers can listen independently.

**Which headers count as sensitive.** `Authorization`, the active auth-header key, `Cookie`, and `Set-Cookie` are the default redaction set — replaced with `<redacted>` in the built-in **logs** when redaction is on (release; see *Privacy* below). `events()` is unaffected. Change the set:

```swift
await networking.setRedactedHeaderFields(["Authorization", "X-Api-Key"])
```

### Built-in logging

Out of the box — no setup — the library logs **failures** (HTTP 4xx/5xx, decoding, transport, invalid-request) to Apple's unified logging (`os.Logger`, subsystem `com.elvisnunez.networking`), tagged with the request id. This is the modern replacement for console `print`: it appears automatically in the Xcode console and Console.app, is filterable, and honors privacy annotations.

`setLogLevel` chooses **which requests** are logged — logged requests always get full detail (line, request + response headers, request + response bodies, truncated):

```swift
await networking.setLogLevel(.none)      // nothing
await networking.setLogLevel(.failures)  // default — every failure, full detail
await networking.setLogLevel(.all)       // every request too, success or failure — the opt-in firehose
```

`.failures` is the default: failures are rare, so logging them in full is cheap and it's the case you debug — including the **request body**, the quickest way to catch a wrong-shaped payload. `.all` adds successful requests (with their response body, for "succeeded but returned the wrong thing"). The level gates *only* the built-in logging — `events()` always delivers full structured events regardless. (Downloads — `downloadImage`/`downloadData` — log the line + request headers; their response headers/body are omitted since the payload is binary.)

**Privacy — one rule: debug shows, release redacts.** Requests carry sensitive data (logins, payments, profiles, `Authorization`/`Cookie` headers). `redactsLogs` governs the built-in **logs**: in **debug** builds it shows everything (you're debugging — "is my auth header set?" must be answerable); in **release** it replaces both the body lines *and* the `setRedactedHeaderFields` header values (`Authorization`/`Cookie`/`Set-Cookie` by default) with `<redacted>`. Override either way with `setRedactsLogs(_:)`. Two caveats on what redaction does **not** cover: (1) a failure's log line still includes the server's error **message** (parsed from the response) as diagnostic text — so don't put secrets in server error strings; (2) `events()` always carries the **real** headers — it's your own request data, and redaction is a logging concern, not an observation one. Need more control? `setLogLevel(.none)` or filter `events()` yourself.

**Reading logs from a CLI / test / headless run.** `os.Logger` isn't visible in `swift test` / `swift run` stdout. Point the library at a file and it mirrors the same diagnostics there as plain text:

```swift
await networking.setLogFileURL(URL(fileURLWithPath: "/tmp/networking.log"))
```

Or set it with **no code change** via the `NETWORKING_LOG_FILE` environment variable — handy for CI or an automated agent:

```shell
NETWORKING_LOG_FILE=/tmp/networking.log swift test
cat /tmp/networking.log
# 2026-06-14T20:09:58Z → GET /get [F97CE6EB-…]
# 2026-06-14T20:09:58Z ← 200 (452 bytes) in 0.022s [F97CE6EB-…]
# 2026-06-14T20:09:58Z ✗ GET …/status/404 [C3569F63-…] failed: The server returned status 404 (not found).
```

`NETWORKING_LOG_FILE` accepts an absolute path **or a bare filename** — a bare name resolves under the app's Caches directory (sandbox-safe; the same default location CocoaLumberjack uses). That makes it work inside a **running app on the simulator**, where you inject it at launch and read it back from the app's container:

```shell
# simctl forwards SIMCTL_CHILD_-prefixed vars into the app (prefix stripped)
xcrun simctl launch SIMCTL_CHILD_NETWORKING_LOG_FILE=networking.log <device> <bundle-id>
dir=$(xcrun simctl get_app_container <device> <bundle-id> data)
cat "$dir/Library/Caches/networking.log"
```

(On a physical device there's no `simctl`; fall back to Console.app / `os.Logger`.)

## Installing

**Networking** is available through Swift Package Manager.

## Running the tests

The integration tests exercise the real HTTP stack against a local [go-httpbin](https://github.com/mccutchen/go-httpbin) — the same backend CI uses. With [Docker](https://www.docker.com) installed:

```shell
make test   # starts go-httpbin, runs the suite, tears it down
```

To iterate, start it once and run the suite directly:

```shell
make httpbin      # leaves go-httpbin running on :8080
swift test
make httpbin-stop
```

Tests default to `http://127.0.0.1:8080`; set `HTTPBIN_BASE_URL` to point elsewhere. The offline (faked) suites need no server.

## Author

This library was made with love by [@3lvis](https://twitter.com/3lvis).


## License

**Networking** is available under the MIT license. See the [LICENSE file](https://github.com/3lvis/Networking/blob/master/LICENSE.md) for more info.


## Attribution

The logo typeface comes thanks to [Sanid Jusić](https://dribbble.com/shots/1049674-Free-Colorfull-Triangle-Typeface).
