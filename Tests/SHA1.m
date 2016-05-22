#import "SHA1.h"
#import <CommonCrypto/CommonDigest.h>

@implementation SHA1

+ (NSString *)signatureUsingParameters:(NSDictionary *)parameters secret:(NSString *)secret
{
    NSArray* paramNames = [parameters allKeys];
    NSMutableArray *params = [NSMutableArray arrayWithCapacity:[parameters count]];
    paramNames = [paramNames sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    for (NSString *param in paramNames) {
        NSObject* value = [parameters valueForKey:param];
        NSString* paramValue;
        if ([value isKindOfClass:[NSArray class]]) {
            NSArray *arrayValue = (NSArray*) value;
            if ([arrayValue count] == 0) continue;
            paramValue = [arrayValue componentsJoinedByString:@","];
        } else {
            paramValue = [SHA1 asString:value];
            if ([paramValue length] == 0) continue;
        }
        NSArray* encoded = @[param, paramValue];
        [params addObject:[encoded componentsJoinedByString:@"="]];
    }
    NSString *toSign = [params componentsJoinedByString:@"&"];
    unsigned char digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1_CTX ctx;
    CC_SHA1_Init(&ctx);
    NSData *stringBytes = [toSign dataUsingEncoding: NSUTF8StringEncoding];
    CC_SHA1_Update(&ctx, [stringBytes bytes], (CC_LONG) [stringBytes length]);
    stringBytes = [secret dataUsingEncoding: NSUTF8StringEncoding];
    CC_SHA1_Update(&ctx, [stringBytes bytes], (CC_LONG) [stringBytes length]);

    CC_SHA1_Final(digest, &ctx);
    NSMutableString *hexString = [NSMutableString stringWithCapacity:(CC_SHA1_DIGEST_LENGTH * 2)];

    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; ++i)
        [hexString appendString:[NSString stringWithFormat:@"%02x", (unsigned)digest[i]]];
    return [NSString stringWithString:hexString];
}

+ (NSString *)asString:(id)value
{
    if (value == nil) {
        return nil;
    } else if ([value isKindOfClass:[NSString class]]) {
        return value;
    } else if ([value isKindOfClass:[NSNumber class]]) {
        NSNumber* number = value;
        return [number stringValue];
    } else {
        [NSException raise:@"CloudinaryError" format:@"Expected NSString or NSNumber"];
        return nil;
    }
}

@end
