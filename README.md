![Networking](https://raw.githubusercontent.com/3lvis/Networking/master/Images/cover-v3.png)

[![Version](https://img.shields.io/cocoapods/v/Networking.svg?style=flat)](https://cocoapods.org/pods/Networking)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/3lvis/Networking)
![Swift 2.2.x](https://img.shields.io/badge/Swift-2.2.x-orange.svg)
![platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20OS%20X%20%7C%20watchOS%20%7C%20tvOS%20-lightgrey.svg)
[![License](https://img.shields.io/cocoapods/l/Networking.svg?style=flat)](https://cocoapods.org/pods/Networking)

**Networking** was born out of the necesity of having a simple networking library that didn't had crazy programming abstractions or used the latest reactive programming techniques, just a plain, simple and convenient wrapper around `NSURLSession` that supported common needs such as faking requests and caching images out of the box. A library that was small enough to read in one go but useful enough to include in any project. That's how **Networking** was born, a fully tested library that even your grandma would love.

- Super friendly API
- Singleton free
- No external dependencies
- Optimized for unit testing
- Minimal implementation
- Fake requests easily (mocking/stubbing)
- Runs synchronously in automatic testing environments
- Image downloading and caching
- Free

## Table of Contents

* [Choosing a configuration type](#choosing-a-configuration-type)
* [Authenticating](#authenticating)
    * [HTTP basic](#http-basic)
    * [Bearer token](#bearer-token)
    * [Custom authentication header](#custom-authentication-header)
* [Making a request](#making-a-request)
* [Choosing a content type](#choosing-a-content-type)
* [Faking a request](#faking-a-request)
* [Cancelling a request](#cancelling-a-request)
* [Downloading and caching an image](#downloading-and-caching-an-image)
* [Logging errors](#logging-errors)
* [Updating the Network Activity Indicator](#updating-the-network-activity-indicator)
* [Installing](#installing)
* [Author](#author)
* [License](#license)
* [Attribution](#attribution)

## Choosing a configuration type

Since **Networking** is basically a wrapper of `NSURLSession` we can take leverage of the great configuration types that it supports, such as `Default`, `Ephemeral` and `Background`, if you don't provide any or don't have special needs then `Default` will be used.

 - `Default`: The default session configuration uses a persistent disk-based cache (except when the result is downloaded to a file) and stores credentials in the user’s keychain. It also stores cookies (by default) in the same shared cookie store as the NSURLConnection and NSURLDownload classes.
 
- `Ephemeral`: An ephemeral session configuration object is similar to a default session configuration object except that the corresponding session object does not store caches, credential stores, or any session-related data to disk. Instead, session-related data is stored in RAM. The only time an ephemeral session writes data to disk is when you tell it to write the contents of a URL to a file.

The main advantage to using ephemeral sessions is privacy. By not writing potentially sensitive data to disk, you make it less likely that the data will be intercepted and used later. For this reason, ephemeral sessions are ideal for private browsing modes in web browsers and other similar situations.

Because an ephemeral session does not write cached data to disk, the size of the cache is limited by available RAM. This limitation means that previously fetched resources are less likely to be in the cache (and are guaranteed to not be there if the user quits and relaunches your app). This behavior may reduce perceived performance, depending on your app.

When your app invalidates the session, all ephemeral session data is purged automatically. Additionally, in iOS, the in-memory cache is not purged automatically when your app is suspended but may be purged when your app is terminated or when the system experiences memory pressure.

 - `Background`: This configuration type is suitable for transferring data files while the app runs in the background. A session configured with this object hands control of the transfers over to the system, which handles the transfers in a separate process. In iOS, this configuration makes it possible for transfers to continue even when the app itself is suspended or terminated.

If an iOS app is terminated by the system and relaunched, it retrieves the status of transfers that were in progress at the time of termination. This behavior applies only for normal termination of the app by the system. If the user terminates the app from the multitasking screen, the system cancels all of the session’s background transfers. In addition, the system does not automatically relaunch apps that were force quit by the user. The user must explicitly relaunch the app before transfers can begin again.

```swift
// Default
let networking = Networking(baseURL: "http://httpbin.org")

// Ephemeral
let networking = Networking(baseURL: "http://httpbin.org", configurationType: .Ephemeral)
```

## Authenticating

### HTTP basic

To authenticate using [basic authentication](http://www.w3.org/Protocols/HTTP/1.0/spec.html#BasicAA) with a username **"aladdin"** and password **"opensesame"** you only need to do this:

```swift
let networking = Networking(baseURL: "http://httpbin.org")
networking.authenticate(username: "aladdin", password: "opensesame")
networking.GET("/basic-auth/aladdin/opensesame") { JSON, error in
    // Successfully logged in! Now do something with the JSON
}
```

### Bearer token

To authenticate using a [bearer token](https://tools.ietf.org/html/rfc6750) **"AAAFFAAAA3DAAAAAA"** you only need to do this:

```swift
let networking = Networking(baseURL: "http://sample.org")
networking.authenticate(token: "AAAFFAAAA3DAAAAAA")
networking.GET("/users") { JSON, error in
    // Do something...
}
```

### Custom authentication header

To authenticate using a custom authentication header, for example **"Token token=AAAFFAAAA3DAAAAAA"** you would need to set the following header field: `Authorization: Token token=AAAFFAAAA3DAAAAAA`. Luckily, **Networking** provides a simple way to do this:

```swift
let networking = Networking(baseURL: "http://sample.org")
networking.authenticate(authorizationHeader: "Token token=AAAFFAAAA3DAAAAAA")
networking.GET("/users") { JSON, error in
    // Do something...
}
```

## Making a request

Making a request is as simple as just calling `GET`, `POST`, `PUT`, or `DELETE`.

**GET example**:

```swift
let networking = Networking(baseURL: "https://api-news.layervault.com/api/v2")
networking.GET("/stories") { JSON, error in
  if let JSON = JSON {
    // Stories JSON: https://api-news.layervault.com/api/v2/stories
  }
}
```

**POST example**:

```swift
let networking = Networking(baseURL: "http://httpbin.org")
networking.POST("/post", params: ["username" : "jameson", "password" : "secret"]) { JSON, error in
    /*
    JSON Pretty Print:
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
}
```

## Choosing a Content Type

The `Content-Type` HTTP specification is so unfriendly, you have to know the specifics of it before understanding that content type is really just the parameter type. Because of this **Networking** uses a `ParameterType` instead of a `ContentType`. Anyway, here's hoping this makes it more human friendly.

**Networking** by default uses `application/json` as the `Content-Type`, if you're sending JSON you don't have to do anything. But if you want to send other types of parameters you can do it by providing the `ParameterType` attribute. For example, if you want to use `application/x-www-form-urlencoded` just use the `.FormURLEncoded` parameter type, internally **Networking** will format your parameters so they use [`Percent-encoding`](https://en.wikipedia.org/wiki/Percent-encoding#The_application.2Fx-www-form-urlencoded_type). No more changes needed.

**JSON parameters**:
```swift
let networking = Networking(baseURL: "http://httpbin.org")
networking.POST("/post", parameters: ["name" : "jameson"]) { JSON, error in
   // Successfull post using `application/json` as `Content-Type`
}
```

**Percent encoded parameters**:
```swift
let networking = Networking(baseURL: "http://httpbin.org")
networking.POST("/post", parameterType: .FormURLEncoded, parameters: ["name" : "jameson"]) { JSON, error in
   // Successfull post using `application/x-www-form-urlencoded` as `Content-Type`
}
```

At the moment **Networking** supports three types of `ParameterType`s out of the box: `JSON`, `FormURLEncoded` and `Custom`. Meanwhile `JSON` and `FormURLEncoded` serialize your parameters in some way, `Custom(String)` sends your parameters as plain `NSData` and sets the value inside `Custom` as the `Content-Type`.

For example:
```swift
let networking = Networking(baseURL: "http://httpbin.org")
networking.POST("/upload", parameterType: .Custom("application/octet-stream"), parameters: imageData) { JSON, error in
   // Successfull upload using `application/octet-stream` as `Content-Type`
}
```

## Faking a request

Faking a request means that after calling this method on a specific path, any call to this resource, will return what you registered as a response. This technique is also known as mocking or stubbing.

**Faking with successfull response**:

```swift
let networking = Networking(baseURL: "https://api-news.layervault.com/api/v2")
networking.fakeGET("/stories", response: [["id" : 47333, "title" : "Site Design: Aquest"]])
networking.GET("/stories") { JSON, error in
    // JSON containing stories
}
```

**Faking with contents of a file**:

If your file is not located in the main bundle you have to specify using the bundle parameters, otherwise `NSBundle.mainBundle()` will be used.

```swift
let networking = Networking(baseURL: baseURL)
networking.fakeGET("/entries", fileName: "entries.json")
networking.GET("/entries") { JSON, error in
    // JSON with the contents of entries.json
}
```

**Faking with status code**:

If you do not provide a status code for this fake request, the default returned one will be 200 (SUCCESS), but if you do provide a status code that is not 2XX, then **Networking** will return an NSError containing the status code and a proper error description.

```swift
let networking = Networking(baseURL: "https://api-news.layervault.com/api/v2")
networking.fakeGET("/stories", response: nil, statusCode: 500)
networking.GET("/stories") { JSON, error in
    // error with status code 500
}
```

## Cancelling a request

Cancelling any request for a specific path is really simple. Beware that cancelling a request will cause the request to return with an error with status code -999.

```swift
let networking = Networking(baseURL: "http://httpbin.org")
networking.GET("/get") { JSON, error in
    // Cancelling a GET request returns an error with code -999 which means cancelled request
}

networking.cancelGET("/get")
```

## Downloading and caching an image

**Downloading**:

```swift
let networking = Networking(baseURL: "http://httpbin.org")
networking.downloadImage("/image/png") { image, error in
   // Do something with the downloaded image
}
```

**Faking**:

```swift
let networking = Networking(baseURL: baseURL)
let pigImage = UIImage(named: "pig.png")!
networking.fakeImageDownload("/image/png", image: pigImage)
networking.downloadImage("/image/png") { image, error in
   // Here you'll get the provided pig.png image
}
```

**Cancelling**:

```swift
let networking = Networking(baseURL: baseURL)
networking.downloadImage("/image/png") { image, error in
    // Cancelling a image download returns an error with code -999 which means cancelled request
}

networking.cancelImageDownload("/image/png")
```

**Caching**:

**Networking** stores the download image in the Caches folder. It also uses NSCache internally so it doesn't have to download the same image again and again.

If you want to remove the downloaded image you can do it like this:

```swift
let networking = Networking(baseURL: "http://httpbin.org")
let destinationURL = try networking.destinationURL("/image/png")
if let path = destinationURL.path where NSFileManager.defaultManager().fileExistsAtPath(path) {
   try! NSFileManager.defaultManager().removeItemAtPath(path)
}
```

**Retreiving cached image**:

First download an image like you normally do:
```swift
let networking = Networking(baseURL: baseURL)
networking.downloadImage("/image/png") { image, error in
    // Downloaded image
}
```

Then you would be able to retrieve the image from the cache at any time!
```swift
networking.imageFromCache("/image/png") { image in
    // Image from cache, you will get `nil` if no image is found
}
```

## Logging errors

Any error catched by **Networking** will be printed in your console. This is really convenient since you want to know why your networking call failed anyway.

For example a cancelled request will print this:

```
========== Networking Error ==========

Cancelled request: <NSMutableURLRequest: 0x7fdc80eb0e30> { URL: https://api.mmm.com/38bea9c8b75bfed1326f90c48675fce87dd04ae6/thumb/small }

================= ~ ==================
```

A 404 request will print something like this:

```
========== Networking Error ==========

Error 3840: Error Domain=NSCocoaErrorDomain Code=3840 "JSON text did not start with array or object and option to allow fragments not set." UserInfo={NSDebugDescription=JSON text did not start with array or object and option to allow fragments not set.}

Request: <NSMutableURLRequest: 0x7fede8d17220> { URL: http://httpbin.org/invalidpath }

Data: <!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">
<title>404 Not Found</title>
<h1>Not Found</h1>
<p>The requested URL was not found on the server.  If you entered the URL manually please check your spelling and try again.</p>


Response status code: 404

Path: http://httpbin.org/invalidpath

Response: <NSHTTPURLResponse: 0x7fede8d0c4e0> { URL: http://httpbin.org/invalidpath } { status code: 404, headers {
    "Access-Control-Allow-Credentials" = true;
    "Access-Control-Allow-Origin" = "*";
    Connection = "keep-alive";
    "Content-Length" = 233;
    "Content-Type" = "text/html";
    Date = "Tue, 17 Nov 2015 09:59:42 GMT";
    Server = nginx;
} }

================= ~ ==================
```

## Updating the Network Activity Indicator

**Networking** balances how the network activity indicator is displayed.

> A network activity indicator appears in the status bar and shows that network activity is occurring.
>The network activity indicator:
>
> - Spins in the status bar while network activity proceeds and disappears when network activity stops
> - Doesn’t allow user interaction
>
> Display the network activity indicator to provide feedback when your app accesses the network for more than a couple of seconds. If the operation finishes sooner than that, you don’t have to show the network activity indicator, because the indicator is likely to disappear before users notice its presence.
>
>— [iOS Human Interface Guidelines](https://developer.apple.com/library/ios/documentation/UserExperience/Conceptual/MobileHIG/Controls.html)

<p align="center">
  <img src="https://raw.githubusercontent.com/3lvis/NetworkActivityIndicator/master/GIF/sample.gif"/>
</p>

## Installing

**Networking** is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
use_frameworks!

pod 'Networking'
```

**Networking** is also available through [Carthage](https://github.com/Carthage/Carthage). To install
it, simply add the following line to your Cartfile:

```ruby
github "3lvis/Networking"
```

## Author

This library was made with love by [@3lvis](https://twitter.com/3lvis).


## License

**Networking** is available under the MIT license. See the [LICENSE file](https://github.com/3lvis/Networking/blob/master/LICENSE.md) for more info.


## Attribution

The logo typeface comes thanks to [Sanid Jusić](https://dribbble.com/shots/1049674-Free-Colorfull-Triangle-Typeface)
