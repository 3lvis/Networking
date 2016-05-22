@import Foundation;

/**
 This class is used as a helper to unit test uploads to Cloudinary
 */
@interface SHA1 : NSObject

+ (NSString *)signatureUsingParameters:(NSDictionary *)parameters secret:(NSString *)secret;

@end
