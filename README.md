# Networking

A thin networking library.

```objc
@import Foundation;
@import UIKit;

@interface Networking : NSObject

- (instancetype)initWithBaseURL:(NSString *)baseURL;

- (void)getPath:(NSString *)path completion:(void (^)(id JSON, NSError *error))completion;

@end
```

## Author

Elvis Nuñez, elvisnunez@me.com

## License

**Networking** is available under the MIT license. See the LICENSE file for more info.
