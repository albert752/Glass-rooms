// Glass Rooms for iOS 9: local preferences. The panel PIN stays in the keychain when iOS allows it.
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GRPreferences : NSObject
+ (instancetype)shared;
@property (nonatomic, copy, nullable) NSString *serverURL;
@property (nonatomic, copy, nullable) NSString *token;
@property (nonatomic, copy, nullable) NSString *pinnedFingerprint;
@property (nonatomic, copy) NSString *theme; // auto, day or night
@property (nonatomic) BOOL glass;
@property (nonatomic) BOOL keepAwake;
@property (nonatomic, readonly) BOOL tokenInKeychain;
@end

NS_ASSUME_NONNULL_END
