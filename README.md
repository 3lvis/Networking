![Networking](https://raw.githubusercontent.com/3lvis/Networking/master/Images/cover-v3.png)

- Super friendly API
- Minimal implementation
- Easy stubbing
- Runs synchronously in automatic testing enviroments
- Free

### GET

```objc
Networking *networking = [[Networking alloc] initWithBaseURL:@"https://api-news.layervault.com/api/v2"];
[networking GET:@"/stories"
     completion:^(id JSON, NSError *error) {
         // Stories JSON: https://api-news.layervault.com/api/v2/stories
     }];
}
```

### Stubbing GET

```objc
NSArray *stories = @[@{@"id" : @47333,
                       @"title" : @"Site Design: Aquest",
                       @"created_at" : @"2015-04-06T13:16:36Z",
                       @"submitter_display_name" : @"Chris A."}];

[Networking stubGET:@"/stories" response:@{@"stories": stories}];

Networking *networking = [[Networking alloc] initWithBaseURL:@"https://api-news.layervault.com/api/v2"];
[networking GET:@"/stories"
     completion:^(id JSON, NSError *error) {
         // Stories with id: 47333
     }];
}
```

## Author

Elvis Nuñez, [@3lvis](https://twitter.com/3lvis)

## License

**Networking** is available under the MIT license. See the LICENSE file for more info.

## Attribution

The logo typeface comes thanks to [Sanid Jusić](https://dribbble.com/shots/1049674-Free-Colorfull-Triangle-Typeface)
