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
* [Choosing a content or parameter type](#choosing-a-content-or-parameter-type)
    * [JSON](#json)
    * [URL-encoding](#url-encoding)
    * [Multipart](#multipart)
    * [Others](#others)
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
let networking = Networking(baseURL: "http://httpbin.org")

// Ephemeral
let networking = Networking(baseURL: "http://httpbin.org", configuration: .ephemeral)
```

## Changing request headers

You can set the `headerFields` in any networking object.

This will append (if not found) or overwrite (if found) what NSURLSession sends on each request.

```swift
networking.headerFields = ["User-Agent": "your new user agent"]
```

## Authenticating

### HTTP basic

To authenticate using [basic authentication](http://www.w3.org/Protocols/HTTP/1.0/spec.html#BasicAA) with a username **"aladdin"** and password **"opensesame"** you only need to do this:

```swift
let networking = Networking(baseURL: "http://httpbin.org")
networking.setAuthorizationHeader(username: "aladdin", password: "opensesame")
let result = try await networking.oldGet("/basic-auth/aladdin/opensesame")
// Successfully authenticated!
```

### Bearer token

To authenticate using a [bearer token](https://tools.ietf.org/html/rfc6750) **"AAAFFAAAA3DAAAAAA"** you only need to do this:

```swift
let networking = Networking(baseURL: "http://httpbin.org")
networking.setAuthorizationHeader(token: "AAAFFAAAA3DAAAAAA")
let result = try await networking.oldGet("/get")
// Successfully authenticated!
```

### Custom authentication header

To authenticate using a custom authentication header, for example **"Token token=AAAFFAAAA3DAAAAAA"** you would need to set the following header field: `Authorization: Token token=AAAFFAAAA3DAAAAAA`. Luckily, **Networking** provides a simple way to do this:

```swift
let networking = Networking(baseURL: "http://httpbin.org")
networking.setAuthorizationHeader(headerValue: "Token token=AAAFFAAAA3DAAAAAA")
let result = try await networking.oldGet("/get")
// Successfully authenticated!
```

Providing the following authentication header `Anonymous-Token: AAAFFAAAA3DAAAAAA` is also possible:

```swift
let networking = Networking(baseURL: "http://httpbin.org")
networking.setAuthorizationHeader(headerKey: "Anonymous-Token", headerValue: "AAAFFAAAA3DAAAAAA")
let result = try await networking.oldGet("/get")
// Successfully authenticated!
```

## Making a request

### The basics

Making a request is as simple as just calling `get`, `post`, `put`, or `delete`.

**GET example**:

```swift
let networking = Networking(baseURL: "http://httpbin.org")
let result = try await networking.oldGet("/get")
switch result {
case .success(let response):
    let json = response.dictionaryBody
    // Do something with JSON, you can also get arrayBody
case .failure(let response):
    // Handle error
}
```

**POST example**:

```swift
let networking = Networking(baseURL: "http://httpbin.org")
let result = try await networking.oldPost("/post", parameters: ["username" : "jameson", "password" : "secret"])
 /*
 {
     "json" : {
         "username" : "jameson",
         "password" : "secret"
     },
     "url" : "http://httpbin.org/post",
     "data" : "{"password" : "secret","username" : "jameson"}",
     "headers" : {
         "Accept" : "application/json",
         "Content-Type" : "application/json",
         "Host" : "httpbin.org",
         "Content-Length" : "44",
         "Accept-Language" : "en-us"
     }
 }
 */
```

You can get the response headers inside the success.

```swift
let networking = Networking(baseURL: "http://httpbin.org")
let result = try await networking.oldGet("/get")
switch result {
case .success(let response):
    let headers = response.allHeaderFields
    // Do something with headers
case .failure(let response):
    // Handle error
}
```

### The NetworkingResult type

The [NetworkingResult](https://github.com/3lvis/Networking/blob/master/Sources/NetworkingResult.swift) type is an enum that has two cases: `success` and `failure`. The `success` case has a response, the `failure` case has an error and a response, none of these ones are optionals.

Here's how to use it:

```swift
// The best way
let networking = Networking(baseURL: "http://fakerecipes.com")
let result = try await networking.oldGet("/recipes")
switch result {
case .success(let response):
    // We know we'll be receiving an array with the best recipes, so we can just do:
    let recipes = response.arrayBody // BOOM, no optionals. [[String: Any]]

    // If we need headers or response status code we can use the HTTPURLResponse for this.
    let headers = response.headers // [String: Any]
case .failure(let response):
    // Non-optional error ✨
    let errorCode = response.error.code

    // Our backend developer told us that they will send a json with some
    // additional information on why the request failed, this will be a dictionary.
    let json = response.dictionaryBody // BOOM, no optionals here [String: Any]

    // We want to know the headers of the failed response.
    let headers = response.headers // [String: Any]
}
```

And that's how we do things in **Networking** without optionals.

## Choosing a Content or Parameter Type

The `Content-Type` HTTP specification is so unfriendly, you have to know the specifics of it before understanding that content type is really just the parameter type. Because of this **Networking** uses a `ParameterType` instead of a `ContentType`. Anyway, here's hoping this makes it more human friendly.

### JSON

**Networking** by default uses `application/json` as the `Content-Type`, if you're sending JSON you don't have to do anything. But if you want to send other types of parameters you can do it by providing the `ParameterType` attribute.

When sending JSON your parameters will be serialized to data using `NSJSONSerialization`.

```swift
let networking = Networking(baseURL: "http://httpbin.org")
let result = try await networking.oldPost("/post", parameters: ["name" : "jameson"])
// Successfull post using `application/json` as `Content-Type`
```

### URL-encoding

 If you want to use `application/x-www-form-urlencoded` just use the `.formURLEncoded` parameter type, internally **Networking** will format your parameters so they use [`Percent-encoding` or `URL-enconding`](https://en.wikipedia.org/wiki/Percent-encoding#The_application.2Fx-www-form-urlencoded_type).

```swift
let networking = Networking(baseURL: "http://httpbin.org")
let result = try await networking.oldPost("/post", parameterType: .formURLEncoded, parameters: ["name" : "jameson"])
// Successfull post using `application/x-www-form-urlencoded` as `Content-Type`
```

### Multipart

**Networking** provides a simple model to use `multipart/form-data`. A multipart request consists in appending one or several [FormDataPart](https://github.com/3lvis/Networking/blob/master/Sources/FormDataPart.swift) items to a request. The simplest multipart request would look like this.

```swift
let networking = Networking(baseURL: "https://example.com")
let imageData = UIImagePNGRepresentation(imageToUpload)!
let part = FormDataPart(data: imageData, parameterName: "file", filename: "selfie.png")
let result = try await networking.oldPost("/image/upload", part: part)
// Successfull upload using `multipart/form-data` as `Content-Type`
```

If you need to use several parts or append other parameters than aren't files, you can do it like this:

```swift
let networking = Networking(baseURL: "https://example.com")
let part1 = FormDataPart(data: imageData1, parameterName: "file1", filename: "selfie1.png")
let part2 = FormDataPart(data: imageData2, parameterName: "file2", filename: "selfie2.png")
let parameters = ["username" : "3lvis"]
let result = try await networking.oldPost("/image/upload", parts: [part1, part2], parameters: parameters)
// Do something
```

**FormDataPart Content-Type**:

`FormDataPart` uses `FormDataPartType` to generate the `Content-Type` for each part. The default `FormDataPartType` is `.Data` which adds the `application/octet-stream` to your part. If you want to use a `Content-Type` that is not available between the existing `FormDataPartType`s, you can use `.Custom("your-content-type)`.

### Others

At the moment **Networking** supports four types of `ParameterType`s out of the box: `JSON`, `FormURLEncoded`, `MultipartFormData` and `Custom`. Meanwhile `JSON` and `FormURLEncoded` serialize your parameters in some way, `Custom(String)` sends your parameters as plain `NSData` and sets the value inside `Custom` as the `Content-Type`.

For example:
```swift
let networking = Networking(baseURL: "http://httpbin.org")
let result = try await networking.oldPost("/upload", parameterType: .Custom("application/octet-stream"), parameters: imageData)
// Successfull upload using `application/octet-stream` as `Content-Type`
```

## Cancelling a request

### Using path

Cancelling any request for a specific path is really simple. Beware that cancelling a request will cause the request to return with an error with status code URLError.cancelled.

```swift
let networking = Networking(baseURL: "http://httpbin.org")
let result = try await networking.oldGet("/get")
// Cancelling a GET request returns an error with code URLError.cancelled which means cancelled request

// In another place
networking.cancelGET("/get")
```

## Faking a request

Faking a request means that after calling this method on a specific path, any call to this resource, will return what you registered as a response. This technique is also known as mocking or stubbing.

**Faking with successfull response**:

```swift
let networking = Networking(baseURL: "https://api-news.layervault.com/api/v2")
networking.fakeGET("/stories", response: [["id" : 47333, "title" : "Site Design: Aquest"]])
let result = try await networking.oldGet("/stories")
// JSON containing stories
```

**Faking with contents of a file**:

If your file is not located in the main bundle you have to specify using the bundle parameters, otherwise `NSBundle.mainBundle()` will be used.

```swift
let networking = Networking(baseURL: baseURL)
networking.fakeGET("/entries", fileName: "entries.json")
let result = try await networking.oldGet("/entries")
// JSON with the contents of entries.json
```

**Faking with status code**:

If you do not provide a status code for this fake request, the default returned one will be 200 (SUCCESS), but if you do provide a status code that is not 2XX, then **Networking** will return an NSError containing the status code and a proper error description.

```swift
let networking = Networking(baseURL: "https://api-news.layervault.com/api/v2")
networking.fakeGET("/stories", response: nil, statusCode: 500)
let result = try await networking.oldGet("/stories")
// error with status code 500
```

## Downloading and caching an image

**Downloading**:

```swift
let networking = Networking(baseURL: "http://httpbin.org")
let result = try await networking.downloadImage("/image/png")
// Do something with the downloaded image
```

**Cancelling**:

```swift
let networking = Networking(baseURL: baseURL)
let result = try await networking.downloadImage("/image/png")
// Cancelling an image download returns an error with code URLError.cancelled which means cancelled request

networking.cancelImageDownload("/image/png")
```

**Caching**:

**Networking** uses a multi-cache architecture when downloading images, the first time the `downloadImage` method is called for a specific path, it will store the results in disk (Documents folder) and in memory (NSCache), so in the next call it will return the cached results without hitting the network.

```swift
let networking = Networking(baseURL: "http://httpbin.org")
let result = try await networking.downloadImage("/image/png")
// Image from network
   
let result = try await networking.downloadImage("/image/png")
// Image from cache
```

If you want to remove the downloaded image you can do it like this:

```swift
let networking = Networking(baseURL: "http://httpbin.org")
let destinationURL = try networking.destinationURL(for: "/image/png")
if let path = destinationURL.path where NSFileManager.defaultManager().fileExistsAtPath(path) {
   try NSFileManager.defaultManager().removeItemAtPath(path)
}
```

**Faking**:

```swift
let networking = Networking(baseURL: baseURL)
let pigImage = UIImage(named: "pig.png")!
networking.fakeImageDownload("/image/png", image: pigImage)
let result = try await networking.downloadImage("/image/png")
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

URL: http://httpbin.org/posdddddt

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

To disable error logging use the flag `disableErrorLogging`.

```swift
let networking = Networking(baseURL: "http://httpbin.org")
networking.disableErrorLogging = true
```

## Installing

**Networking** is available through Swift Package Manager.

## Author

This library was made with love by [@3lvis](https://twitter.com/3lvis).


## License

**Networking** is available under the MIT license. See the [LICENSE file](https://github.com/3lvis/Networking/blob/master/LICENSE.md) for more info.


## Attribution

The logo typeface comes thanks to [Sanid Jusić](https://dribbble.com/shots/1049674-Free-Colorfull-Triangle-Typeface).
