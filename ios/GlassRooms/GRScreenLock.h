// Glass Rooms for iOS 9: screen off after a chosen number of seconds without touches.
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// An app cannot lock the iPad itself. While it has been touched within the chosen time (GRPreferences.screenLock)
// it keeps the screen on; when the time passes it turns the screen off itself (a black cover at minimum
// brightness, if GRPreferences.screenDim) and hands over to iOS, which locks after its own auto-lock delay.
// A touch on the black screen only wakes it: it never reaches the controls underneath.
@interface GRScreenLock : NSObject
// Call on every touch.
+ (void)userActivity;
// Call at launch, on returning to the foreground and after the preferences change.
+ (void)restart;
// Turns the screen back on and restores the brightness (also when the app leaves the foreground).
+ (void)wake;
+ (BOOL)sleeping;
@end

// Window that reports touches to GRScreenLock and swallows the touch that wakes the screen.
@interface GRWindow : UIWindow
@end

NS_ASSUME_NONNULL_END
