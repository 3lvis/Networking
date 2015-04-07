#import "Networking.h"

#import "NSObject+HYPTesting.h"

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

- (void)GET:(NSString *)path
 completion:(void (^)(id JSON, NSError *error))completion
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;

    NSString *url = [NSString stringWithFormat:@"%@%@", self.baseURL, path];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];

    if ([NSObject isUnitTesting]) {
        NSError *error = nil;
        NSURLResponse *response = nil;
        NSData *data = [NSURLConnection sendSynchronousRequest:request
                                             returningResponse:&response
                                                         error:&error];
        id JSON;
        if (data) {
            NSError *serializationError = nil;
            JSON = [NSJSONSerialization JSONObjectWithData:data
                                                   options:NSJSONReadingMutableContainers
                                                     error:&serializationError];
            if (!error) {
                error = serializationError;
            }

            completion(JSON, error);
        }
    } else {
        NSOperationQueue *queue = [NSOperationQueue new];
        [NSURLConnection sendAsynchronousRequest:request
                                           queue:queue
                               completionHandler:^(NSURLResponse *response,
                                                   NSData *data,
                                                   NSError *connectionError) {
                                   NSError *error = connectionError;
                                   id JSON;

                                   if (data) {
                                       NSError *serializationError = nil;
                                       JSON = [NSJSONSerialization JSONObjectWithData:data
                                                                              options:NSJSONReadingMutableContainers
                                                                                error:&serializationError];
                                       if (!error) {
                                           error = serializationError;
                                       }
                                   }

                                   dispatch_async(dispatch_get_main_queue(), ^{
                                       [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
                                       completion(JSON, error);
                                   });
                               }];
    }
}

+ (void)stubGET:(NSString *)path response:(id)JSON
{

}

@end
