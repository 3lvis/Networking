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

- (void)getPath:(NSString *)path
     completion:(void (^)(id JSON, NSError *error))completion
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;

    NSString *url = [NSString stringWithFormat:@"%@%@", self.baseURL, path];
    NSURLRequest *urlRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
    NSOperationQueue *queue = [NSOperationQueue new];
    [NSURLConnection sendAsynchronousRequest:urlRequest
                                       queue:queue
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                               NSError *error = connectionError;

                               NSError *serializationError = nil;
                               NSJSONSerialization *JSON = [NSJSONSerialization JSONObjectWithData:data
                                                                                           options:NSJSONReadingMutableContainers
                                                                                             error:&serializationError];
                               if (!error) {
                                   error = serializationError;
                               }

                               dispatch_async(dispatch_get_main_queue(), ^{
                                   [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
                                   completion(JSON, error);
                               });
                           }];
}

@end
