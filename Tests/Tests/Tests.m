@import XCTest;

#import "Networking.h"

@interface Tests : XCTestCase

@end

@implementation Tests

- (void)testGET
{
    __block BOOL success = NO;
    Networking *networking = [[Networking alloc] initWithBaseURL:@"http://api-news.layervault.com/api/v2"];
    [networking GET:@"/stories"
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

    Networking *networking = [[Networking alloc] initWithBaseURL:@"http://api-news.layervault.com/api/v2"];
    [networking GET:@"/stories"
         completion:^(id JSON, NSError *error) {
             XCTAssertNotNil(JSON);
             XCTAssertNil(error);
         }];
}

@end
