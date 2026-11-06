// Glass Rooms for iOS 9: native iPad client for the Glass Rooms Home Assistant app.
#import <UIKit/UIKit.h>
#import "GRMainViewController.h"
#import "GRScreenLock.h"

@interface GRAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) GRMainViewController *panel;
@end

@implementation GRAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  self.window = [[GRWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  self.panel = [GRMainViewController new];
  self.window.rootViewController = self.panel;
  [self.window makeKeyAndVisible];
  [GRScreenLock restart];
  [self.panel connectFromPreferences];
  return YES;
}

- (void)applicationDidEnterBackground:(UIApplication *)application { [self.panel appDidEnterBackground]; }
- (void)applicationWillEnterForeground:(UIApplication *)application { [GRScreenLock restart]; [self.panel appWillEnterForeground]; }

@end

int main(int argc, char *argv[]) {
  @autoreleasepool {
    return UIApplicationMain(argc, argv, nil, NSStringFromClass([GRAppDelegate class]));
  }
}
