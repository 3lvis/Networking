![Networking](https://raw.githubusercontent.com/3lvis/Networking/master/Images/cover-v3.png)

[![Version](https://img.shields.io/cocoapods/v/Networking.svg?style=flat)](https://cocoapods.org/pods/Networking)
[![License](https://img.shields.io/cocoapods/l/Networking.svg?style=flat)](https://cocoapods.org/pods/Networking)
[![Platform](https://img.shields.io/cocoapods/p/Networking.svg?style=flat)](https://cocoapods.org/pods/Networking)

- Super friendly API
- Singleton free
- Optimized for unit testing
- Minimal implementation
- Easy stubbing
- Runs synchronously in automatic testing enviroments
- Image download and caching
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
* [PUT](#put)
    * [Stubbing PUT](#stubbing-put)
    * [Cancelling PUT](#cancelling-put)
* [DELETE](#delete)
    * [Stubbing DELETE](#stubbing-delete)
    * [Cancelling DELETE](#cancelling-delete)
* [Image download](#image-download)
    * [Stubbing image download](#stubbing-image-download)
    * [Cancelling image download](#cancelling-image-download)
    * [Image download caching](#image-download-caching)
* [Error logging](#error-logging)
* [Network Activity Indicator](#network-activity-indicator)
* [Installation](#installation)
* [Author](#author)
* [License](#license)
* [Attribution](#attribution)

## Authentication

### HTTP basic authentication

`Networking` supports [HTTP basic authentication](http://www.w3.org/Protocols/HTTP/1.0/spec.html#BasicAA):

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
let networking = Networking(baseURL: "https://api-news.layervault.com/api/v2")
networking.stubGET("/stories", response: [["id" : 47333, "title" : "Site Design: Aquest"]])
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
let networking = Networking(baseURL: "https://api-news.layervault.com/api/v2")
networking.stubPOST("/story", response: ["id" : 47333, "title" : "Site Design: Aquest"])
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

## PUT

```swift
let networking = Networking(baseURL: "http://httpbin.org")
networking.PUT("/put", params: ["username":"jameson", "password":"password"]) { JSON, error in
    /*
    JSON Pretty Print:
    {
        "json" : {
            "username" : "jameson",
            "password" : "password"
        },
        "url" : "http://httpbin.org/put",
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

### Stubbing PUT

```swift
let networking = Networking(baseURL: "https://api-news.layervault.com/api/v2")
networking.stubPUT("/story", response: ["id" : 47333, "title" : "Site Design: Aquest"])
networking.PUT("/story", params: ["username":"jameson", "password":"password"]) { JSON, error in
    if let JSON = JSON {
      // Story with id: 47333
    }
}
```

### Cancelling PUT

```swift
let networking = Networking(baseURL: "http://httpbin.org")
networking.PUT("/put", parameters: ["username":"jameson", "password":"password"]) { JSON, error in
    // Cancelling a PUT request returns an error with code -999 which means cancelled request
})

networking.cancelPUT("/put")
```

## DELETE

```swift
let networking = Networking(baseURL: "https://api-news.layervault.com/api/v2")
networking.DELETE("/stories/2342", completion: { JSON, error in
  if let JSON = JSON {
    // { "success": true }
  }
})
```


### Stubbing DELETE

```swift
let networking = Networking(baseURL: "https://api-news.layervault.com/api/v2")
networking.stubDELETE("/stories/2342", response: ["success" : true])
networking.DELETE("/stories/2342", completion: { JSON, error in
  if let JSON = JSON {
    // { "success": true }
  }
})
```

### Cancelling GET

```swift
let networking = Networking(baseURL: "http://httpbin.org")
networking.DELETE("/delete", completion: { JSON, error in
    // Cancelling a DELETE request returns an error with code -999 which means cancelled request
})

networking.cancelDELETE("/delete")
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

## Network Activity Indicator

`Networking` leverages on [NetworkActivityIndicator](https://github.com/3lvis/NetworkActivityIndicator) to balance how the network activity indicator is displayed.

You can manage the state of this indicator by using:

```swift
NetworkActivityIndicator.sharedIndicator.visible = true
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
