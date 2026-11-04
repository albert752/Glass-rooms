// Glass Rooms for iOS 9: small helpers for untrusted JSON and formatting.
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NSString *_Nullable GRStr(id _Nullable value);
NSNumber *_Nullable GRNum(id _Nullable value);
NSDictionary *_Nullable GRDict(id _Nullable value);
NSArray *_Nullable GRArray(id _Nullable value);
NSDate *_Nullable GRParseISODate(NSString *_Nullable value);
NSString *GRPad2(NSInteger value);
// Shortest decimal text that reads back as the same double, like JavaScript's String(number).
NSString *GRFormatNumber(double value);
// Math.round from JavaScript: halves round towards positive infinity.
long GRRound(double value);

@interface GRTimer : NSObject
+ (GRTimer *)after:(NSTimeInterval)seconds block:(dispatch_block_t)block;
- (void)cancel;
@end

NS_ASSUME_NONNULL_END
