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
* [Logging errors](#logging-errors)
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
    // error is a NetworkingError carrying the status code and message
    print(error.localizedDescription)
}
```

Use `JSONResponse` as the type when you want the raw `statusCode`, `headers`, and `body` instead of a model.

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

If you do not provide a status code for this fake request, the default returned one will be 200 (SUCCESS), but if you do provide a status code that is not 2XX, then **Networking** will return an NSError containing the status code and a proper error description.

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

## Logging errors

Any error catched by **Networking** will be printed in your console. This is really convenient since you want to know why your networking call failed anyway.

For example a cancelled request will print this:

```shell
========== Networking Error ==========

Cancelled request: https://api.mmm.com/38bea9c8b75bfed1326f90c48675fce87dd04ae6/thumb/small

================= ~ ==================
```

A 404 request will print something like this:

```shell
========== Networking Error ==========

*** Request ***

Error 404: Error Domain=NetworkingErrorDomain Code=404 "not found" UserInfo={NSLocalizedDescription=not found}

URL: http://example.com/posdddddt

Headers: ["Accept": "application/json", "Content-Type": "application/json"]

Parameters: {
  "password" : "secret",
  "username" : "jameson"
}

Data: <!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">
<title>404 Not Found</title>
<h1>Not Found</h1>
<p>The requested URL was not found on the server.  If you entered the URL manually please check your spelling and try again.</p>


*** Response ***

Headers: ["Content-Length": 233, "Server": nginx, "Access-Control-Allow-Origin": *, "Content-Type": text/html, "Date": Sun, 29 May 2016 07:19:13 GMT, "Access-Control-Allow-Credentials": true, "Connection": keep-alive]

Status code: 404 — not found

================= ~ ==================
```

To disable error logging:

```swift
let networking = Networking(baseURL: "http://example.com")
await networking.setErrorLoggingEnabled(false)
```

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
