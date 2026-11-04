#import "GRAPIClient.h"
#import "GRUtil.h"
#import <CommonCrypto/CommonDigest.h>
#import <Security/Security.h>

static NSString *const GRNoConnection = @"No hi ha connexió amb el servidor.";

@interface GRAPIClient () <NSURLSessionTaskDelegate>
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, copy) NSString *token;
@property (nonatomic, copy) NSString *pinnedFingerprint;
@property (atomic, copy) NSString *untrustedFingerprint;
@end

@implementation GRAPIClient

+ (NSURL *)normalizedBaseURL:(NSString *)text error:(NSString **)error {
  NSString *trimmed = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  NSURL *url = trimmed.length ? [NSURL URLWithString:trimmed] : nil;
  NSString *scheme = url.scheme.lowercaseString;
  NSString *problem = nil;
  if(!url || !([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"]) || !url.host.length) {
    problem = @"Escriu l’adreça completa del panell, per exemple http://192.168.1.10:8099.";
  } else if(url.user || url.password || url.query || url.fragment || (url.path.length && ![url.path isEqualToString:@"/"])) {
    problem = @"L’adreça del panell no pot incloure usuari, ruta, consulta ni fragment.";
  }
  if(problem) { if(error) { *error = problem; } return nil; }
  NSString *host = url.host;
  if([host rangeOfString:@":"].location != NSNotFound && ![host hasPrefix:@"["]) { host = [NSString stringWithFormat:@"[%@]", host]; }
  NSString *base = url.port ? [NSString stringWithFormat:@"%@://%@:%@", scheme, host, url.port] : [NSString stringWithFormat:@"%@://%@", scheme, host];
  return [NSURL URLWithString:base];
}

+ (NSString *)fingerprintForCertificateData:(NSData *)data {
  unsigned char digest[CC_SHA256_DIGEST_LENGTH];
  CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
  NSMutableArray *parts = [NSMutableArray arrayWithCapacity:CC_SHA256_DIGEST_LENGTH];
  for(int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) { [parts addObject:[NSString stringWithFormat:@"%02X", digest[i]]]; }
  return [parts componentsJoinedByString:@":"];
}

- (instancetype)initWithBaseURL:(NSURL *)baseURL token:(NSString *)token pinnedFingerprint:(NSString *)fingerprint {
  if((self = [super init])) {
    _baseURL = baseURL;
    _token = token.length ? [token copy] : nil;
    _pinnedFingerprint = fingerprint.length ? [fingerprint copy] : nil;
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    configuration.HTTPShouldSetCookies = NO;
    configuration.HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicyNever;
    configuration.URLCache = nil;
    configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    configuration.HTTPMaximumConnectionsPerHost = 4;
    configuration.timeoutIntervalForResource = 90;
    _session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:[NSOperationQueue mainQueue]];
  }
  return self;
}

- (BOOL)hasToken { return self.token.length > 0; }

- (void)invalidate { [self.session invalidateAndCancel]; }

- (NSURLSessionDataTask *)GET:(NSString *)path timeout:(NSTimeInterval)timeout completion:(GRResponse)completion {
  return [self request:@"GET" path:path body:nil timeout:timeout completion:completion];
}

- (NSURLSessionDataTask *)POST:(NSString *)path body:(NSDictionary *)body timeout:(NSTimeInterval)timeout completion:(GRResponse)completion {
  return [self request:@"POST" path:path body:body timeout:timeout completion:completion];
}

- (NSURLSessionDataTask *)request:(NSString *)method path:(NSString *)path body:(NSDictionary *)body
                          timeout:(NSTimeInterval)timeout completion:(GRResponse)completion {
  NSURL *url = [NSURL URLWithString:[self.baseURL.absoluteString stringByAppendingString:path]];
  GRResponse finish = [completion copy];
  if(!url) { dispatch_async(dispatch_get_main_queue(), ^{ finish(GRNoConnection, nil, 0); }); return nil; }
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:timeout > 0 ? timeout : 15];
  request.HTTPMethod = method;
  request.HTTPShouldHandleCookies = NO;
  [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
  if(self.token) { [request setValue:[@"Bearer " stringByAppendingString:self.token] forHTTPHeaderField:@"Authorization"]; }
  if([method isEqualToString:@"POST"]) {
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body ?: @{} options:0 error:NULL];
  }
  __block NSURLSessionDataTask *task = nil;
  task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
    BOOL untrusted = [task.taskDescription isEqualToString:@"untrusted"];
    task = nil;
    if(error) {
      if(error.code == NSURLErrorCancelled && !untrusted) { return; }
      NSString *message = GRNoConnection;
      if(untrusted) { message = @"iOS no reconeix el certificat HTTPS del panell. Comprova l’empremta a Ajustos abans de confiar-hi."; }
      else if(error.code == NSURLErrorTimedOut) { message = @"El servidor no ha respost a temps."; }
      else if(error.code <= NSURLErrorSecureConnectionFailed && error.code >= NSURLErrorClientCertificateRequired) {
        message = @"No s’ha pogut establir la connexió HTTPS amb el panell.";
      }
      finish(message, nil, 0);
      return;
    }
    NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]] ? ((NSHTTPURLResponse *)response).statusCode : 0;
    id parsed = data.length ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
    NSDictionary *json = GRDict(parsed) ?: @{@"error": @"No s’ha pogut llegir la resposta del servidor."};
    BOOL ok = status >= 200 && status < 300 && GRDict(parsed);
    finish(ok ? nil : (GRStr(json[@"error"]) ?: GRNoConnection), json, status);
  }];
  [task resume];
  return task;
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler {
  if(![challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
    completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    return;
  }
  SecTrustRef trust = challenge.protectionSpace.serverTrust;
  SecTrustResultType result = kSecTrustResultInvalid;
  BOOL trusted = trust && SecTrustEvaluate(trust, &result) == errSecSuccess
    && (result == kSecTrustResultUnspecified || result == kSecTrustResultProceed);
  if(trusted) {
    self.untrustedFingerprint = nil;
    completionHandler(NSURLSessionAuthChallengeUseCredential, [NSURLCredential credentialForTrust:trust]);
    return;
  }
  // Self-signed LAN certificates are accepted only when the user pinned this exact leaf certificate.
  SecCertificateRef leaf = trust && SecTrustGetCertificateCount(trust) > 0 ? SecTrustGetCertificateAtIndex(trust, 0) : NULL;
  NSData *der = leaf ? CFBridgingRelease(SecCertificateCopyData(leaf)) : nil;
  NSString *fingerprint = der ? [GRAPIClient fingerprintForCertificateData:der] : nil;
  if(fingerprint && self.pinnedFingerprint && [fingerprint isEqualToString:self.pinnedFingerprint]) {
    self.untrustedFingerprint = nil;
    completionHandler(NSURLSessionAuthChallengeUseCredential, [NSURLCredential credentialForTrust:trust]);
    return;
  }
  self.untrustedFingerprint = fingerprint ?: @"";
  task.taskDescription = @"untrusted";
  completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
}

@end
