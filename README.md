![Networking](https://raw.githubusercontent.com/3lvis/Networking/master/Images/cover-v3.png)

- Super friendly API
- Optimized for unit testing
- Minimal implementation
- Easy stubbing
- Runs synchronously in automatic testing enviroments
- Free

## Authentication

### HTTP basic authentication

`Networking` supports [HTTP basic autentication](http://www.w3.org/Protocols/HTTP/1.0/spec.html#BasicAA):

To authenticate using basic authentication with a username **"Aladdin"** and password **"open sesame"**, you would need to set the following header field: 

`Authorization: Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==`, which contains the string `Aladin:open sesame` in Base64 format. Luckily `Networking` provides a simpler way to do this.

This is how you use basic authentication on Networking, the following example features a username: `user` and a password: `pswd`.

```swift
let networking = Networking(baseURL: "http://httpbin.org")
networking.autenticate("user", password: "pswd")
networking.GET("/basic-auth/user/pswd", completion: { JSON, error in
    // Do something...
})
```

### Bearer token authentication

`Networking` supports [Bearer Token Usage](https://tools.ietf.org/html/rfc6750):

To authenticate using a bearer token **"AAAFFAAAA3DAAAAAA"**, you would need to set the following header field: 

`Authorization: Bearer AAAFFAAAA3DAAAAAA`. Luckily `Networking` provides a simpler way to do this.

This is how you use bearer token authentication on Networking, the following example features a token: `AAAFFAAAA3DAAAAAA`.

```swift
let networking = Networking(baseURL: "http://sample.org")
networking.autenticate("AAAFFAAAA3DAAAAAA")
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
        "url" : "http:\/\/httpbin.org\/post",
        "data" : "{\"password\":\"password\",\"username\":\"jameson\"}",
        "headers" : {
            "Accept" : "application\/json",
            "Content-Type" : "application\/json",
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
