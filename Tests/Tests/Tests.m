@import XCTest;

#import "Networking.h"

static NSString * const BaseURL = @"http://httpbin.org";

@interface Tests : XCTestCase

@end

@implementation Tests

- (void)testGET
{
    __block BOOL success = NO;
    Networking *networking = [[Networking alloc] initWithBaseURL:BaseURL];
    [networking GET:@"/get"
         completion:^(NSDictionary *JSON, NSError *error) {
             XCTAssertEqualObjects(JSON[@"url"], @"http://httpbin.org/get");
             XCTAssertNil(error);
             success = YES;
         }];
    XCTAssertTrue(success);
}

- (void)testGetStubs
{
    [Networking stubGET:@"/stories" response:@{@"name" : @"Elvis"}];

    __block BOOL success = NO;
    Networking *networking = [[Networking alloc] initWithBaseURL:BaseURL];
    [networking GET:@"/stories"
         completion:^(NSDictionary *JSON, NSError *error) {
             XCTAssertEqualObjects(JSON[@"name"], @"Elvis");
             XCTAssertNil(error);
             success = YES;
         }];
    XCTAssertTrue(success);
}

@end
