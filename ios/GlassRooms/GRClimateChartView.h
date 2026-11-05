// Glass Rooms for iOS 9: full-size history chart (touch to inspect a point) and the clock column's sparkline.
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface GRClimateChartView : UIView
// points: [{"time": ISO 8601, "value": number}], oldest first. message is drawn when there are no points.
- (instancetype)initWithPoints:(NSArray<NSDictionary *> *)points humidity:(BOOL)humidity message:(nullable NSString *)message;
@property (nonatomic, readonly) NSInteger selectedIndex;
- (void)selectIndex:(NSInteger)index;
@property (nonatomic, copy, nullable) void (^onSelect)(NSInteger index);
@end

// Small filled curve for the clock column; values are drawn left to right, oldest first.
@interface GRSparklineView : UIView
@property (nonatomic, copy) NSArray<NSNumber *> *values;
@end

NS_ASSUME_NONNULL_END
