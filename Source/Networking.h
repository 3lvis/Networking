@import Foundation;
@import UIKit;

@interface Networking : NSObject

- (instancetype)initWithBaseURL:(NSString *)baseURL;

- (void)getPath:(NSString *)path completion:(void (^)(id JSON, NSError *error))completion;

@end
