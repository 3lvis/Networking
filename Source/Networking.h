@import Foundation;
@import UIKit;

typedef NS_OPTIONS(NSInteger, NetworkingStatusCode) {
    NetworkingStatusCodeUnknown             = 0,
    NetworkingStatusCodeUnauthorized        = 401,
    NetworkingStatusCodeForbidden           = 403,
    NetworkingStatusCodeInternalServerError = 500,
    NetworkingStatusCodeServiceUnavailable  = 503
};

@interface Networking : NSObject

- (instancetype)initWithBaseURL:(NSString *)baseURL;

- (void)GET:(NSString *)path
 completion:(void (^)(id JSON, NSError *error))completion;

+ (void)stubGET:(NSString *)path response:(id)JSON;

@end
