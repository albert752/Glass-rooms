// Glass Rooms for iOS 9: screen lock after a chosen time without touches.
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// An app cannot lock the iPad itself: it keeps the screen on while it has been touched within the chosen time
// (GRPreferences.screenLock) and then hands over to iOS, which locks after its own auto-lock delay.
@interface GRScreenLock : NSObject
// Call on every touch.
+ (void)userActivity;
// Call at launch, on returning to the foreground and after the preference changes.
+ (void)restart;
@end

// Window that reports touches to GRScreenLock.
@interface GRWindow : UIWindow
@end

NS_ASSUME_NONNULL_END
