@import XCTest;

#import "Networking.h"

@interface Tests : XCTestCase

@end

@implementation Tests

- (void)testGet
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Networking expectations"];

    Networking *networking = [[Networking alloc] initWithBaseURL:@"https://api-news.layervault.com/api/v2"];
    [networking getPath:@"/stories"
             completion:^(id JSON, NSError *error) {
                 XCTAssertNotNil(JSON);
                 [expectation fulfill];
             }];

    [self waitForExpectationsWithTimeout:60.0f handler:nil];
}

@end
