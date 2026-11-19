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
    // Both styles, by night and by day; GR_SNAPSHOT_LOOKS="warm-night,jarvis-day" picks some of them.
    NSString *only = [NSProcessInfo processInfo].environment[@"GR_SNAPSHOT_LOOKS"];
    for(NSArray *look in @[@[@"warm", @"night"], @[@"jarvis", @"night"], @[@"jarvis", @"day"], @[@"warm", @"day"]]) {
      if(only.length && ![[only componentsSeparatedByString:@","] containsObject:[NSString stringWithFormat:@"%@-%@", look[0], look[1]]]) { continue; }
      NSString *suffix = [NSString stringWithFormat:@"-%@-%@", look[0], look[1]];
      add(@"", ^{ [panel closeModal]; [panel setStyleChoice:look[0]]; [panel setThemeChoice:look[1]]; [panel navigate:@"rooms"]; });
      add([@"rooms" stringByAppendingString:suffix], ^{});
      add([@"rooms-p2" stringByAppendingString:suffix], ^{ [panel showPage:1]; });
      add([@"climate" stringByAppendingString:suffix], ^{ [panel navigate:@"climate"]; });
      add([@"heater" stringByAppendingString:suffix], ^{ [panel navigate:@"heater"]; });
      add([@"heater-p2" stringByAppendingString:suffix], ^{ [panel showPage:1]; });
      add([@"fans" stringByAppendingString:suffix], ^{ [panel navigate:@"fans"]; });
      add([@"remotes" stringByAppendingString:suffix], ^{ [panel navigate:@"remotes"]; });
      add([@"remotes-p2" stringByAppendingString:suffix], ^{ [panel showPage:1]; });
      add([@"energy" stringByAppendingString:suffix], ^{ [panel navigate:@"energy"]; });
      add([@"energy-p2" stringByAppendingString:suffix], ^{ [panel showPage:1]; });
      add([@"security" stringByAppendingString:suffix], ^{ [panel navigate:@"security"]; });
      add([@"security-p2" stringByAppendingString:suffix], ^{ [panel showPage:1]; });
      add([@"overview" stringByAppendingString:suffix], ^{ [panel navigate:@"overview"]; });
      add([@"overview-p2" stringByAppendingString:suffix], ^{ [panel showPage:1]; });
      add([@"lights-drawer" stringByAppendingString:suffix], ^{ [panel navigate:@"lights"]; });
      add([@"office-drawer" stringByAppendingString:suffix], ^{ [panel closeModal]; [panel navigate:@"rooms"]; [panel openRoom:@"despatx"]; });
      add(@"", ^{ [panel closeModal]; });
      add([@"climate-after" stringByAppendingString:suffix], ^{ [panel navigate:@"climate"]; });
      add([@"settings" stringByAppendingString:suffix], ^{ [panel navigate:@"settings"]; });
      add([@"settings-p2" stringByAppendingString:suffix], ^{ [panel showPage:1]; });
      add([@"room-drawer" stringByAppendingString:suffix], ^{ [panel navigate:@"rooms"]; [panel openRoom:@"menjador"]; });
      add([@"alarm-pad" stringByAppendingString:suffix], ^{
        [panel closeModal];
        for(NSDictionary *entity in panel.model.entities) {
          if(![entity[@"domain"] isEqual:@"alarm_control_panel"]) { continue; }
          for(NSDictionary *control in entity[@"controls"]) {
            if([control[@"action"] isEqual:@"alarm_disarm"]) { [panel performSelector:NSSelectorFromString(@"alarmPrompt:control:") withObject:entity withObject:control]; }
          }
        }
      });
    }
    add(@"", ^{ [panel closeModal]; [panel setStyleChoice:@"warm"]; [panel setThemeChoice:@"auto"]; [panel navigate:@"rooms"]; });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ GRRun(steps, 0); });
  }];
}
