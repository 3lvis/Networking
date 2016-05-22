#import "SHA1.h"
#import <CommonCrypto/CommonDigest.h>

@implementation SHA1

+ (NSString *)signatureUsingParameters:(NSDictionary *)parameters secret:(NSString *)secret
{
    NSArray *parameterNames = [parameters allKeys];
    NSMutableArray *composedParameters = [NSMutableArray arrayWithCapacity:[parameters count]];
    parameterNames = [parameterNames sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    for (NSString *parameterName in parameterNames) {
        NSObject *value = [parameters valueForKey:parameterName];
        NSString *parameterValue;
        if ([value isKindOfClass:[NSArray class]]) {
            NSArray *arrayValue = (NSArray *) value;
            if ([arrayValue count] == 0) continue;
            parameterValue = [arrayValue componentsJoinedByString:@","];
        } else {
            parameterValue = [SHA1 asString:value];
            if ([parameterValue length] == 0) continue;
        }
        NSArray* encoded = @[parameterName, parameterValue];
        [composedParameters addObject:[encoded componentsJoinedByString:@"="]];
    }
    NSString *toSign = [composedParameters componentsJoinedByString:@"&"];
    unsigned char digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1_CTX ctx;
    CC_SHA1_Init(&ctx);
    NSData *stringBytes = [toSign dataUsingEncoding: NSUTF8StringEncoding];
    CC_SHA1_Update(&ctx, [stringBytes bytes], (CC_LONG) [stringBytes length]);
    stringBytes = [secret dataUsingEncoding: NSUTF8StringEncoding];
    CC_SHA1_Update(&ctx, [stringBytes bytes], (CC_LONG) [stringBytes length]);

    CC_SHA1_Final(digest, &ctx);
    NSMutableString *hexString = [NSMutableString stringWithCapacity:(CC_SHA1_DIGEST_LENGTH * 2)];

    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; ++i) {
        [hexString appendString:[NSString stringWithFormat:@"%02x", (unsigned)digest[i]]];
    }
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
        return nil;
    }
}

@end
