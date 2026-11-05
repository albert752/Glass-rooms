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

static UISwitch *GRFindSwitch(UIView *view, NSString *identifier) {
  if([view isKindOfClass:[UISwitch class]] && [view.accessibilityIdentifier isEqualToString:identifier]) { return (UISwitch *)view; }
  for(UIView *child in view.subviews) { UISwitch *found = GRFindSwitch(child, identifier); if(found) { return found; } }
  return nil;
}

static UIControl *GRFindControl(UIView *view, NSString *identifier) {
  if([view isKindOfClass:[UIControl class]] && [view.accessibilityIdentifier isEqualToString:identifier]) { return (UIControl *)view; }
  for(UIView *child in view.subviews) { UIControl *found = GRFindControl(child, identifier); if(found) { return found; } }
  return nil;
}

static void GRScrollToEnd(UIView *view) {
  if([view isKindOfClass:[UIScrollView class]] && ((UIScrollView *)view).scrollEnabled && view.bounds.size.width > 600) {
    UIScrollView *scroll = (UIScrollView *)view;
    [scroll setContentOffset:CGPointMake(0, MAX(0, scroll.contentSize.height + scroll.contentInset.bottom - scroll.bounds.size.height)) animated:NO];
  }
  for(UIView *child in view.subviews) { GRScrollToEnd(child); }
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
    add(@"room-drawer-day", ^{ [panel navigate:@"rooms"]; [panel openRoom:@"menjador"]; });
    add(@"settings-day", ^{ [panel closeModal]; [panel openSettings]; });
    add(@"security-day", ^{ [panel closeModal]; [panel navigate:@"security"]; });
    add(@"", ^{ [panel navigate:@"rooms"]; });
    add(@"rooms-night", ^{ [panel closeModal]; [panel setThemeChoice:@"night"]; [panel navigate:@"rooms"]; });
    add(@"climate-night", ^{ [panel navigate:@"climate"]; });
    add(@"climate-humidity-night", ^{ [GRFindControl(window, @"sensor.hum_menjador") sendActionsForControlEvents:UIControlEventTouchUpInside]; });
    add(@"security-night", ^{ [panel navigate:@"security"]; });
    add(@"", ^{});
    add(@"security-night-camera", ^{});
    add(@"security-night-end", ^{ GRScrollToEnd(window); });
    add(@"room-drawer-night", ^{ [panel navigate:@"rooms"]; [panel openRoom:@"menjador"]; });
    add(@"lights-drawer-night", ^{ [panel closeModal]; [panel navigate:@"lights"]; });
    add(@"swipe-to-climate", ^{
      [panel closeModal]; [panel navigate:@"rooms"];
      UISwipeGestureRecognizer *swipe = [UISwipeGestureRecognizer new]; swipe.direction = UISwipeGestureRecognizerDirectionLeft;
      [panel performSelector:@selector(swiped:) withObject:swipe];
    });
    add(@"", ^{ [panel navigate:@"rooms"]; });
    add(@"after-switch", ^{
      [panel closeModal];
      UISwitch *toggle = GRFindSwitch(window, @"cuina");
      [toggle setOn:!toggle.on animated:NO];
      [toggle sendActionsForControlEvents:UIControlEventValueChanged];
    });
    add(@"", ^{
      UISwitch *toggle = GRFindSwitch(window, @"habitacio");
      [toggle setOn:!toggle.on animated:NO];
      [toggle sendActionsForControlEvents:UIControlEventValueChanged];
    });
    for(NSInteger i = 0; i < 8; i++) { add(@"", ^{}); }
    add(@"after-unresponsive", ^{});
    add(@"", ^{ [panel setThemeChoice:@"auto"]; });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ GRRun(steps, 0); });
  }];
}
