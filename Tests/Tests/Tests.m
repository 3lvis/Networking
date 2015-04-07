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
         completion:^(id JSON, NSError *error) {
             XCTAssertNotNil(JSON);
             XCTAssertNil(error);
             success = YES;
         }];
    XCTAssertTrue(success);
}

- (void)testGetStubs
{
    [Networking stubGET:@"/stories" response:@{@"first_name" : @"Elvis"}];

    Networking *networking = [[Networking alloc] initWithBaseURL:BaseURL];
    [networking GET:@"/get"
         completion:^(id JSON, NSError *error) {
             XCTAssertNotNil(JSON);
             XCTAssertNil(error);
         }];
}

@end
