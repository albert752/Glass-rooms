#import "GRUtil.h"
#include <math.h>
#include <time.h>

NSString *GRStr(id value) { return [value isKindOfClass:[NSString class]] ? value : nil; }

NSNumber *GRNum(id value) {
  if(![value isKindOfClass:[NSNumber class]]) { return nil; }
  // NSJSONSerialization returns booleans as NSNumber; JavaScript would not treat them as numbers.
  if((__bridge CFTypeRef)value == kCFBooleanTrue || (__bridge CFTypeRef)value == kCFBooleanFalse) { return nil; }
  return isfinite([value doubleValue]) ? value : nil;
}

NSDictionary *GRDict(id value) { return [value isKindOfClass:[NSDictionary class]] ? value : nil; }
NSArray *GRArray(id value) { return [value isKindOfClass:[NSArray class]] ? value : nil; }

NSDate *GRParseISODate(NSString *value) {
  // The server sends datetime.isoformat(): 2026-11-04T21:59:00.123456+00:00 (fraction optional).
  if(![value isKindOfClass:[NSString class]] || value.length < 19) { return nil; }
  const char *text = value.UTF8String;
  int year, month, day, hour, minute, second, consumed = 0;
  if(sscanf(text, "%4d-%2d-%2dT%2d:%2d:%2d%n", &year, &month, &day, &hour, &minute, &second, &consumed) != 6 || consumed != 19) { return nil; }
  const char *rest = text + consumed;
  double fraction = 0;
  if(*rest == '.') {
    double scale = 0.1; rest++;
    while(*rest >= '0' && *rest <= '9') { fraction += (*rest - '0') * scale; scale /= 10; rest++; }
  }
  long offset = 0;
  if(*rest == 'Z') { rest++; }
  else if(*rest == '+' || *rest == '-') {
    int oh = 0, om = 0, sign = *rest == '-' ? -1 : 1;
    if(sscanf(rest + 1, "%2d:%2d", &oh, &om) != 2) { return nil; }
    offset = sign * (oh * 3600 + om * 60); rest += 6;
  } else { return nil; }
  if(*rest != '\0') { return nil; }
  struct tm parts = {0};
  parts.tm_year = year - 1900; parts.tm_mon = month - 1; parts.tm_mday = day;
  parts.tm_hour = hour; parts.tm_min = minute; parts.tm_sec = second;
  time_t seconds = timegm(&parts);
  if(seconds == (time_t)-1) { return nil; }
  return [NSDate dateWithTimeIntervalSince1970:(double)seconds - offset + fraction];
}

NSString *GRPad2(NSInteger value) { return value < 10 ? [NSString stringWithFormat:@"0%ld", (long)value] : [NSString stringWithFormat:@"%ld", (long)value]; }

NSString *GRFormatNumber(double value) {
  if(!isfinite(value)) { return @"—"; }
  if(value == floor(value) && fabs(value) < 1e15) { return [NSString stringWithFormat:@"%.0f", value]; }
  for(int precision = 1; precision <= 17; precision++) {
    NSString *text = [NSString stringWithFormat:@"%.*g", precision, value];
    if(strtod(text.UTF8String, NULL) == value) { return text; }
  }
  return [NSString stringWithFormat:@"%.17g", value];
}

long GRRound(double value) { return (long)floor(value + 0.5); }

@interface GRTimer ()
@property (nonatomic) BOOL cancelled;
@end

@implementation GRTimer
+ (GRTimer *)after:(NSTimeInterval)seconds block:(dispatch_block_t)block {
  GRTimer *timer = [GRTimer new];
  dispatch_block_t copied = [block copy];
  // The block keeps the timer alive until it fires; cancel() turns it into a no-op.
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    if(!timer.cancelled) { timer.cancelled = YES; copied(); }
  });
  return timer;
}
- (void)cancel { self.cancelled = YES; }
@end
