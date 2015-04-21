#import "Networking.h"

#import "NSObject+HYPTesting.h"

@interface Networking ()

@property (nonatomic, copy) NSString *baseURL;
@property (nonatomic) NSMutableDictionary *stubbedResponses;

@end

@implementation Networking

#pragma mark - Initializers

+ (Networking *)stubsInstance {
    static Networking *__stubsInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __stubsInstance = [[Networking alloc] init];
    });

    return __stubsInstance;
}

- (instancetype)initWithBaseURL:(NSString *)baseURL {
    self = [super init];
    if (!self) return nil;

    _baseURL = baseURL;

    return self;
}

#pragma mark - Getters

- (NSMutableDictionary *)stubbedResponses {
    if (_stubbedResponses) return _stubbedResponses;

    _stubbedResponses = [NSMutableDictionary new];

    return _stubbedResponses;
}

#pragma mark - Public methods

- (void)GET:(NSString *)path
 completion:(void (^)(id JSON, NSError *error))completion {
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;

    NSString *url = [NSString stringWithFormat:@"%@%@", self.baseURL, path];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];

    if ([NSObject isUnitTesting]) {
        NSDictionary *responses = [[Networking stubsInstance].stubbedResponses copy];
        if (responses[path]) {
            completion(responses[path], nil);
        } else {
            NSError *error = nil;
            NSURLResponse *response = nil;
            NSData *data = [NSURLConnection sendSynchronousRequest:request
                                                 returningResponse:&response
                                                             error:&error];
            completion([self JSONFromData:data], error);
        }
    } else {
        NSOperationQueue *queue = [NSOperationQueue new];
        [NSURLConnection sendAsynchronousRequest:request
                                           queue:queue
                               completionHandler:^(NSURLResponse *response,
                                                   NSData *data,
                                                   NSError *error) {
                                   id JSON = [self JSONFromData:data];
                                   dispatch_async(dispatch_get_main_queue(), ^{
                                       [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
                                       completion(JSON, error);
                                   });
                               }];
    }
}

+ (void)stubGET:(NSString *)path response:(id)JSON {
    [self stubsInstance].stubbedResponses[path] = JSON;
}

#pragma mark - Private methods

- (id)JSONFromData:(NSData *)data {
    id JSON;
    if (data) {
        NSError *serializationError = nil;
        JSON = [NSJSONSerialization JSONObjectWithData:data
                                               options:NSJSONReadingMutableContainers
                                                 error:&serializationError];
        if (serializationError) {
            abort();
        }
    }

    return JSON;
}

@end
