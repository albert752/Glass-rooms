// Glass Rooms for iOS 9: native history chart with a slider to inspect each point.
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface GRClimateChartView : UIView
- (instancetype)initWithPoints:(NSArray<NSDictionary *> *)points unit:(NSString *)unit humidity:(BOOL)humidity
                          name:(NSString *)name message:(nullable NSString *)message;
- (CGFloat)heightForWidth:(CGFloat)width;
@end

// Small filled curve for the clock column; values are drawn left to right, oldest first.
@interface GRSparklineView : UIView
@property (nonatomic, copy) NSArray<NSNumber *> *values;
@end

NS_ASSUME_NONNULL_END
