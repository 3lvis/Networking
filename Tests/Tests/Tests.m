@import XCTest;

#import "Networking.h"

@interface Tests : XCTestCase

@end

@implementation Tests

- (void)testGet
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Networking expectations"];

    Networking *networking = [[Networking alloc] initWithBaseURL:@"http://api-news.layervault.com/api/v2"];
    [networking GET:@"/stories"
             completion:^(id JSON, NSError *error) {
                 XCTAssertNotNil(JSON);
                 XCTAssertNil(error);
                 [expectation fulfill];
             }];

    [self waitForExpectationsWithTimeout:60.0f handler:nil];
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
