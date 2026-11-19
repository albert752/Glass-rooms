#import "GRScreenLock.h"
#import "GRPreferences.h"
#import "GRUtil.h"

static NSDate *GRLastActivity;
static GRTimer *GRLockTimer;
static UIView *GRCover;
static CGFloat GRSavedBrightness = -1;
static BOOL GRSwallowing;

@interface GRScreenLock ()
+ (BOOL)consumeTouches:(UIEvent *)event;
@end

@implementation GRScreenLock

+ (BOOL)sleeping { return GRCover != nil; }

+ (void)userActivity {
  GRLastActivity = [NSDate date];
  if([GRPreferences shared].screenLock <= 0) { return; }
  [UIApplication sharedApplication].idleTimerDisabled = YES;
  if(!GRLockTimer) { [self check]; }
}

+ (void)restart {
  [self wake];
  [GRLockTimer cancel]; GRLockTimer = nil;
  NSInteger seconds = [GRPreferences shared].screenLock;
  [UIApplication sharedApplication].idleTimerDisabled = seconds != 0;
  if(seconds > 0) { [self userActivity]; }
}

// One timer at a time: when it fires early because of a later touch, it waits only for the time left.
+ (void)check {
  GRLockTimer = nil;
  NSInteger seconds = [GRPreferences shared].screenLock;
  if(seconds <= 0) { return; }
  NSTimeInterval idle = GRLastActivity ? -[GRLastActivity timeIntervalSinceNow] : seconds;
  if(idle >= seconds) { [self sleep]; return; }
  GRLockTimer = [GRTimer after:seconds - idle block:^{ [GRScreenLock check]; }];
}

+ (void)sleep {
  [UIApplication sharedApplication].idleTimerDisabled = NO;
  if(![GRPreferences shared].screenDim || GRCover) { return; }
  UIWindow *window = [UIApplication sharedApplication].keyWindow;
  if(!window) { return; }
  GRCover = [[UIView alloc] initWithFrame:window.bounds];
  GRCover.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  GRCover.backgroundColor = [UIColor blackColor];
  GRCover.isAccessibilityElement = YES;
  GRCover.accessibilityLabel = @"Pantalla apagada; toca per encendre-la";
  GRCover.alpha = 0;
  [window addSubview:GRCover];
  GRSavedBrightness = [UIScreen mainScreen].brightness;
  [UIView animateWithDuration:.6 animations:^{ GRCover.alpha = 1; }];
  [UIScreen mainScreen].brightness = 0;
}

+ (void)wake {
  if(!GRCover) { return; }
  [GRCover removeFromSuperview]; GRCover = nil;
  if(GRSavedBrightness >= 0) { [UIScreen mainScreen].brightness = GRSavedBrightness; GRSavedBrightness = -1; }
}

// The touch that wakes the screen is swallowed until every finger lifts.
+ (BOOL)consumeTouches:(UIEvent *)event {
  if(GRCover) { GRSwallowing = YES; [self wake]; }
  if(!GRSwallowing) { return NO; }
  BOOL down = NO;
  for(UITouch *touch in event.allTouches) {
    if(touch.phase != UITouchPhaseEnded && touch.phase != UITouchPhaseCancelled) { down = YES; }
  }
  if(!down) { GRSwallowing = NO; [self userActivity]; }
  return YES;
}

@end

@implementation GRWindow

- (void)sendEvent:(UIEvent *)event {
  if(event.type == UIEventTypeTouches) {
    if([GRScreenLock consumeTouches:event]) { return; }
    [GRScreenLock userActivity];
  }
  [super sendEvent:event];
}

@end
