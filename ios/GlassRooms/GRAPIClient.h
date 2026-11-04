// Glass Rooms for iOS 9: JSON client for the panel server (never Home Assistant directly).
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^GRResponse)(NSString *_Nullable error, id _Nullable data, NSInteger status);

@interface GRAPIClient : NSObject
// Accepts http(s)://host[:port][/] only; returns nil and a Catalan message otherwise.
+ (nullable NSURL *)normalizedBaseURL:(NSString *)text error:(NSString *_Nullable *_Nullable)error;
+ (NSString *)fingerprintForCertificateData:(NSData *)data;

- (instancetype)initWithBaseURL:(NSURL *)baseURL token:(nullable NSString *)token pinnedFingerprint:(nullable NSString *)fingerprint;
@property (nonatomic, readonly) NSURL *baseURL;
@property (nonatomic, readonly) BOOL hasToken;
// SHA-256 of the last certificate refused because iOS did not trust it and it was not pinned.
@property (atomic, readonly, copy, nullable) NSString *untrustedFingerprint;

- (nullable NSURLSessionDataTask *)GET:(NSString *)path timeout:(NSTimeInterval)timeout completion:(GRResponse)completion;
- (nullable NSURLSessionDataTask *)POST:(NSString *)path body:(NSDictionary *)body timeout:(NSTimeInterval)timeout completion:(GRResponse)completion;
- (void)invalidate;
@end

NS_ASSUME_NONNULL_END
