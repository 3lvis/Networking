@import XCTest;
#import "macOSTests-Swift.h"

@interface ObjCTests : XCTestCase

@end

@implementation ObjCTests

- (void)testExample {
    NSString *baseURL = @"http://httpbin.org";
    Networking *networking = [[Networking alloc] initWithBaseURL:baseURL];
    [networking get:@"/get" parameters:nil completion:^(id body, NSError *error) {
        if (error != nil) {
            XCTFail();
        } else {
            NSDictionary *json = (NSDictionary *)body;
            NSString *url = json[@"url"];
            XCTAssertEqual(url, @"http://httpbin.org/get");
        }
    }];
}

@end
