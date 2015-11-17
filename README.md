![Networking](https://raw.githubusercontent.com/3lvis/Networking/master/Images/cover-v3.png)

[![Version](https://img.shields.io/cocoapods/v/Networking.svg?style=flat)](https://cocoapods.org/pods/Networking)
[![License](https://img.shields.io/cocoapods/l/Networking.svg?style=flat)](https://cocoapods.org/pods/Networking)
[![Platform](https://img.shields.io/cocoapods/p/Networking.svg?style=flat)](https://cocoapods.org/pods/Networking)

- Super friendly API
- Optimized for unit testing
- Minimal implementation
- Easy stubbing
- Runs synchronously in automatic testing enviroments
- Free

## Table of Contents

* [Authentication](#authentication)
    * [HTTP basic authentication](#http-basic-authentication)
    * [Bearer token authentication](#bearer-token-authentication)
* [GET](#get)
    * [Stubbing GET](#stubbing-get)
    * [Cancelling GET](#cancelling-get)
* [POST](#post)
    * [Stubbing POST](#stubbing-post)
    * [Cancelling POST](#cancelling-post)
* [Image download](#image-download)
    * [Stubbing image download](#stubbing-image-download)
    * [Cancelling image download](#cancelling-image-download)
    * [Image download caching](#image-download-caching)
* [Error logging](#error-logging)
* [Installation](#installation)
* [Author](#author)
* [License](#license)
* [Attribution](#attribution)

## Authentication

### HTTP basic authentication

`Networking` supports [HTTP basic autentication](http://www.w3.org/Protocols/HTTP/1.0/spec.html#BasicAA):

To authenticate using basic authentication with a username **"Aladdin"** and password **"open sesame"**, you would need to set the following header field: 

`Authorization: Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==`, which contains the string `Aladin:open sesame` in Base64 format. Luckily, `Networking` provides a simpler way to do this.

This is how you use basic authentication on Networking, the following example features a username: `user` and a password: `pswd`.

```swift
let networking = Networking(baseURL: "http://httpbin.org")
networking.authenticate("user", password: "pswd")
networking.GET("/basic-auth/user/pswd", completion: { JSON, error in
    // Do something...
})
```

### Bearer token authentication

`Networking` supports [Bearer Token Usage](https://tools.ietf.org/html/rfc6750):

To authenticate using a bearer token **"AAAFFAAAA3DAAAAAA"**, you would need to set the following header field: 

`Authorization: Bearer AAAFFAAAA3DAAAAAA`. Luckily, `Networking` provides a simpler way to do this.

This is how you use bearer token authentication on Networking, the following example features a token: `AAAFFAAAA3DAAAAAA`.

```swift
let networking = Networking(baseURL: "http://sample.org")
networking.authenticate("AAAFFAAAA3DAAAAAA")
networking.GET("/users", completion: { JSON, error in
    // Do something...
})
```

## GET

```swift
let networking = Networking(baseURL: "https://api-news.layervault.com/api/v2")
networking.GET("/stories", completion: { JSON, error in
  if let JSON = JSON {
    // Stories JSON: https://api-news.layervault.com/api/v2/stories
  }
})
```


### Stubbing GET

```swift
let stories = [["id" : 47333, "title" : "Site Design: Aquest"]]
Networking.stubGET("/stories", response: ["stories" : stories])

let networking = Networking(baseURL: "https://api-news.layervault.com/api/v2")
networking.GET("/stories", completion: { JSON, error in
  if let JSON = JSON {
    // Stories with id: 47333
  }
})
```

### Cancelling GET

```swift
let networking = Networking(baseURL: "http://httpbin.org")
networking.GET("/get", completion: { JSON, error in
    // Cancelling a GET request returns an error with code -999 which means cancelled request
})

networking.cancelGET("/get")
```

## POST

```swift
let networking = Networking(baseURL: "http://httpbin.org")
networking.POST("/post", params: ["username":"jameson", "password":"password"]) { JSON, error in
    /*
    JSON Pretty Print:
    {
        "json" : {
            "username" : "jameson",
            "password" : "password"
        },
        "url" : "http://httpbin.org/post",
        "data" : "{"password":"password","username":"jameson"}",
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

### Stubbing POST

```swift
let story = ["id" : 47333, "title" : "Site Design: Aquest"]
Networking.stubPOST("/story", response: story)

let networking = Networking(baseURL: "https://api-news.layervault.com/api/v2")
networking.POST("/story", params: ["username":"jameson", "password":"password"]) { JSON, error in
    if let JSON = JSON {
      // Story with id: 47333
    }
}
```

### Cancelling POST

```swift
let networking = Networking(baseURL: "http://httpbin.org")
networking.POST("/post", parameters: ["username":"jameson", "password":"password"]) { JSON, error in
    // Cancelling a POST request returns an error with code -999 which means cancelled request
})

networking.cancelPOST("/post")
```

## Image download

```swift
let networking = Networking(baseURL: "http://httpbin.org")
networking.downloadImage("/image/png") { image, error in
   // Do something with the downloaded image
}
```

### Stubbing image download

```swift
let networking = Networking(baseURL: baseURL)
let pigImage = UIImage(named: "pig.png", inBundle: NSBundle(forClass: Tests.self), compatibleWithTraitCollection: nil)!
networking.stubImageDownload("/image/png", image: pigImage)
networking.downloadImage("/image/png") { image, error in
   // Here you'll get the stubbed pig.png image
}
```

### Cancelling image download

```swift
let networking = Networking(baseURL: baseURL)
networking.downloadImage("/image/png") { image, error in
    // Cancelling a image download returns an error with code -999 which means cancelled request
}

networking.cancelImageDownload("/image/png")
```

### Image download caching

`Networking` stores the download image in the Caches folder. It also uses NSCache internally so it doesn't have to download the same image again and again.

If you want to remove the downloaded image so it downloads again. You can do it like this:

```swift
let networking = Networking(baseURL: "http://httpbin.org")
let destinationURL = networking.destinationURL("/image/png")
if let path = destinationURL.path where NSFileManager().fileExistsAtPath(path) {
   try! NSFileManager().removeItemAtPath(path)
}
```

## Error logging

Any error catched by `Networking` will be printed in your console. This is really convenient since you want to know why your networking call failed anyway.

For example a cancelled request will print this:

```
========== Networking Error ==========
 
Error -999: Error Domain=NSURLErrorDomain Code=-999 "cancelled" UserInfo={NSErrorFailingURLKey=http://httpbin.org/image/png, NSLocalizedDescription=cancelled, NSErrorFailingURLStringKey=http://httpbin.org/image/png}
 
Request: <NSMutableURLRequest: 0x7fede8c3daf0> { URL: http://httpbin.org/image/png }
 
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

## Installation

**Networking** is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'Networking'
```

## Author

Elvis Nuñez, [@3lvis](https://twitter.com/3lvis)


## License

**Networking** is available under the MIT license. See the LICENSE file for more info.


## Attribution

The logo typeface comes thanks to [Sanid Jusić](https://dribbble.com/shots/1049674-Free-Colorfull-Triangle-Typeface)
