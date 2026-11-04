// Development only: drives the UI of the Mac Catalyst preview build and saves screenshots.
// Not part of the iOS app; ios/scripts/preview-mac.sh links it in when GR_SNAPSHOT_DIR is set.
#import <UIKit/UIKit.h>
#import "GRMainViewController.h"

static void GRSave(NSString *name) {
  UIWindow *window = [UIApplication sharedApplication].windows.firstObject;
  UIGraphicsBeginImageContextWithOptions(window.bounds.size, YES, 1);
  [window drawViewHierarchyInRect:window.bounds afterScreenUpdates:YES];
  UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  NSString *directory = [NSProcessInfo processInfo].environment[@"GR_SNAPSHOT_DIR"];
  [UIImagePNGRepresentation(image) writeToFile:[directory stringByAppendingPathComponent:[name stringByAppendingString:@".png"]] atomically:YES];
}

static UIButton *GRFindButton(UIView *view, NSString *identifier) {
  if([view isKindOfClass:[UIButton class]] && [view.accessibilityIdentifier isEqualToString:identifier]) { return (UIButton *)view; }
  for(UIView *child in view.subviews) { UIButton *found = GRFindButton(child, identifier); if(found) { return found; } }
  return nil;
}

static void GRRun(NSArray *steps, NSUInteger index) {
  if(index >= steps.count) { exit(0); }
  NSArray *step = steps[index];
  ((void (^)(void))step[1])();
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    if([step[0] length]) { GRSave(step[0]); }
    GRRun(steps, index + 1);
  });
}

__attribute__((constructor)) static void GRInstallSnapshots(void) {
  NSString *directory = [NSProcessInfo processInfo].environment[@"GR_SNAPSHOT_DIR"];
  if(!directory.length) { return; }
  [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
    UIWindow *window = [UIApplication sharedApplication].windows.firstObject;
    NSString *size = [NSProcessInfo processInfo].environment[@"GR_SNAPSHOT_SIZE"] ?: @"1024x768";
    NSArray *parts = [size componentsSeparatedByString:@"x"];
    CGSize target = CGSizeMake([parts[0] doubleValue], [parts[1] doubleValue]);
    if(@available(macCatalyst 13.0, *)) { window.windowScene.sizeRestrictions.minimumSize = target; window.windowScene.sizeRestrictions.maximumSize = target; }
    GRMainViewController *panel = (GRMainViewController *)window.rootViewController;
    NSString *prefix = [NSProcessInfo processInfo].environment[@"GR_SNAPSHOT_PREFIX"] ?: @"";
    NSMutableArray *steps = [NSMutableArray array];
    void (^add)(NSString *, void (^)(void)) = ^(NSString *name, void (^block)(void)) {
      [steps addObject:@[name.length ? [prefix stringByAppendingString:name] : @"", [block copy]]];
    };
    add(@"", ^{ [panel setThemeChoice:@"day"]; });
    add(@"rooms-day", ^{});
    add(@"overview-day", ^{ [panel navigate:@"overview"]; });
    add(@"climate-day", ^{ [panel navigate:@"climate"]; });
    add(@"room-modal-day", ^{ [panel navigate:@"rooms"]; [panel openRoom:@"cuina"]; });
    add(@"lights-drawer-day", ^{ [panel closeModal]; [panel navigate:@"lights"]; });
    add(@"settings-day", ^{ [panel closeModal]; [panel openSettings]; });
    add(@"rooms-night", ^{ [panel closeModal]; [panel setThemeChoice:@"night"]; [panel navigate:@"rooms"]; });
    add(@"climate-night", ^{ [panel navigate:@"climate"]; });
    add(@"room-modal-night", ^{ [panel navigate:@"rooms"]; [panel openRoom:@"menjador"]; });
    add(@"after-badge-tap", ^{ [panel closeModal]; [panel setThemeChoice:@"day"]; [GRFindButton(window, @"cuina") sendActionsForControlEvents:UIControlEventTouchUpInside]; });
    add(@"", ^{ [panel setThemeChoice:@"auto"]; });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ GRRun(steps, 0); });
  }];
}
