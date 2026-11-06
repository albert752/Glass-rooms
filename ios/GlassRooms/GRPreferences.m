#import "GRPreferences.h"
#import <Security/Security.h>

static NSString *const GRKeychainService = @"glass-rooms";
static NSString *const GRKeychainAccount = @"app-token";
static NSString *const GRFallbackTokenKey = @"glass-rooms-token-fallback";

@implementation GRPreferences

+ (instancetype)shared {
  static GRPreferences *shared;
  static dispatch_once_t once;
  dispatch_once(&once, ^{ shared = [GRPreferences new]; });
  return shared;
}

- (NSUserDefaults *)defaults { return [NSUserDefaults standardUserDefaults]; }

- (NSString *)serverURL { return [[self defaults] stringForKey:@"glass-rooms-server"]; }
- (void)setServerURL:(NSString *)value { [[self defaults] setObject:value forKey:@"glass-rooms-server"]; }
- (NSString *)pinnedFingerprint { return [[self defaults] stringForKey:@"glass-rooms-certificate"]; }
- (void)setPinnedFingerprint:(NSString *)value { [[self defaults] setObject:value forKey:@"glass-rooms-certificate"]; }

- (NSString *)theme {
  NSString *theme = [[self defaults] stringForKey:@"glass-rooms-theme"];
  return [@[@"auto", @"day", @"night"] containsObject:theme] ? theme : @"auto";
}
- (void)setTheme:(NSString *)value { [[self defaults] setObject:value forKey:@"glass-rooms-theme"]; }
- (NSInteger)screenLock {
  // Before 1.1.13 there was only a keep-awake switch: on means never lock.
  id stored = [[self defaults] objectForKey:@"glass-rooms-screen-lock"];
  if(!stored) { return [[self defaults] boolForKey:@"glass-rooms-keep-awake"] ? -1 : 0; }
  NSInteger value = [[self defaults] integerForKey:@"glass-rooms-screen-lock"];
  return value >= -1 && value <= 4 * 3600 ? value : 0;
}
- (void)setScreenLock:(NSInteger)value { [[self defaults] setInteger:value forKey:@"glass-rooms-screen-lock"]; }

- (NSDictionary *)keychainQuery {
  return @{(__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
           (__bridge id)kSecAttrService: GRKeychainService,
           (__bridge id)kSecAttrAccount: GRKeychainAccount};
}

- (NSString *)token {
  NSMutableDictionary *query = [[self keychainQuery] mutableCopy];
  query[(__bridge id)kSecReturnData] = @YES;
  query[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;
  CFTypeRef result = NULL;
  if(SecItemCopyMatching((__bridge CFDictionaryRef)query, &result) == errSecSuccess && result) {
    NSData *data = CFBridgingRelease(result);
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  }
  return [[self defaults] stringForKey:GRFallbackTokenKey];
}

- (void)setToken:(NSString *)value {
  SecItemDelete((__bridge CFDictionaryRef)[self keychainQuery]);
  [[self defaults] removeObjectForKey:GRFallbackTokenKey];
  if(!value.length) { return; }
  NSMutableDictionary *item = [[self keychainQuery] mutableCopy];
  item[(__bridge id)kSecValueData] = [value dataUsingEncoding:NSUTF8StringEncoding];
  item[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly;
  if(SecItemAdd((__bridge CFDictionaryRef)item, NULL) != errSecSuccess) {
    // Some sideloading methods sign without keychain entitlements; keep the app usable inside its sandbox.
    [[self defaults] setObject:value forKey:GRFallbackTokenKey];
  }
}

- (BOOL)tokenInKeychain { return [self token].length && ![[self defaults] stringForKey:GRFallbackTokenKey].length; }

@end
