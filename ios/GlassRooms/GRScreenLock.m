#import "GRScreenLock.h"
#import "GRPreferences.h"
#import "GRUtil.h"

static NSDate *GRLastActivity;
static GRTimer *GRLockTimer;

@implementation GRScreenLock

+ (void)userActivity {
  GRLastActivity = [NSDate date];
  if([GRPreferences shared].screenLock <= 0) { return; }
  [UIApplication sharedApplication].idleTimerDisabled = YES;
  if(!GRLockTimer) { [self check]; }
}

+ (void)restart {
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
  if(idle >= seconds) { [UIApplication sharedApplication].idleTimerDisabled = NO; return; }
  GRLockTimer = [GRTimer after:seconds - idle block:^{ [GRScreenLock check]; }];
}

@end

@implementation GRWindow

- (void)sendEvent:(UIEvent *)event {
  if(event.type == UIEventTypeTouches) { [GRScreenLock userActivity]; }
  [super sendEvent:event];
}

@end
