// Glass Rooms for iOS 9: local preferences. The panel PIN stays in the keychain when iOS allows it.
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GRPreferences : NSObject
+ (instancetype)shared;
@property (nonatomic, copy, nullable) NSString *serverURL;
@property (nonatomic, copy, nullable) NSString *token;
@property (nonatomic, copy, nullable) NSString *pinnedFingerprint;
@property (nonatomic, copy) NSString *theme; // auto, day or night
@property (nonatomic, copy) NSString *style; // warm (Nit càlida) or jarvis
// Seconds without a touch before the screen turns off (5 s to 24 h); 0 leaves it to iOS, -1 never.
@property (nonatomic) NSInteger screenLock;
// When the time passes: YES blacks the screen out at minimum brightness right away; NO only hands over to iOS.
@property (nonatomic) BOOL screenDim;
@property (nonatomic, readonly) BOOL tokenInKeychain;
@end

NS_ASSUME_NONNULL_END
