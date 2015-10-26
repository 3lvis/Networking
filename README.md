![Networking](https://raw.githubusercontent.com/3lvis/Networking/master/Images/cover-v3.png)

- Super friendly API
- Optimized for unit testing
- Minimal implementation
- Easy stubbing
- Runs synchronously in automatic testing enviroments
- Free


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
