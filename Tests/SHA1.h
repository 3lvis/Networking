@import Foundation;

@interface SHA1 : NSObject

+ (NSString *)signatureUsingParameters:(NSDictionary *)parameters secret:(NSString *)secret;

@end
