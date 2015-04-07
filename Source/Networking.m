#import "Networking.h"

@interface Networking ()

@property (nonatomic, copy) NSString *baseURL;

@end

@implementation Networking

- (instancetype)initWithBaseURL:(NSString *)baseURL
{
    self = [super init];
    if (!self) return nil;

    _baseURL = baseURL;

    return self;
}

@end
