![Networking](https://raw.githubusercontent.com/3lvis/Networking/master/Images/cover-v3.png)

- Super friendly API
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


## Stubbing GET

```swift
let stories = [["id" : 47333, "title" : "Site Design: Aquest", "created_at" : "2015-04-06T13:16:36Z"]]
Networking.stubGET("/stories", response: ["stories" : stories])

let networking = Networking(baseURL: "https://api-news.layervault.com/api/v2")
networking.GET("/stories", completion: { JSON, error in
  if let JSON = JSON {
    // Stories with id: 47333
  }
})
```


## Author

Elvis Nuñez, [@3lvis](https://twitter.com/3lvis)


## License

**Networking** is available under the MIT license. See the LICENSE file for more info.


## Attribution

The logo typeface comes thanks to [Sanid Jusić](https://dribbble.com/shots/1049674-Free-Colorfull-Triangle-Typeface)
