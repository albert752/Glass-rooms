#import "GRClimateChartView.h"
#import "GRLogic.h"
#import "GRTheme.h"
#import "GRUtil.h"
#import "GRViews.h"

// Same geometry as the SVG of the web panel: viewBox 0 0 320 108, drawn 115 points high.
static const CGFloat GRPlotHeight = 115;

@interface GRClimatePlotView : UIView
@property (nonatomic, copy) NSArray<NSNumber *> *xs, *values;
@property (nonatomic) double bottom, span;
@property (nonatomic) NSInteger selectedIndex;
@property (nonatomic) BOOL humidity;
@end

@implementation GRClimatePlotView

- (CGFloat)yFor:(double)value { return 96 - (value - self.bottom) * 84 / self.span; }

- (void)drawRect:(CGRect)rect {
  GRTheme *t = [GRTheme current];
  // Points use the web SVG's 0-320 x 0-108 box; stretch x 8-312 to the width (6 pt kept for the marker) without thickening the strokes.
  CGAffineTransform fit = CGAffineTransformScale(CGAffineTransformMakeTranslation(6, 0), (self.bounds.size.width - 12) / 304, self.bounds.size.height / 108);
  fit = CGAffineTransformTranslate(fit, -8, 0);
  UIBezierPath *axis = [UIBezierPath bezierPath];
  [axis moveToPoint:CGPointMake(8, 96)]; [axis addLineToPoint:CGPointMake(312, 96)];
  [axis applyTransform:fit];
  axis.lineWidth = 1; [t.line setStroke]; [axis stroke];
  if(!self.values.count) { return; }
  UIBezierPath *line = [UIBezierPath bezierPath];
  for(NSUInteger i = 0; i < self.values.count; i++) {
    CGPoint point = CGPointMake(self.xs[i].doubleValue, [self yFor:self.values[i].doubleValue]);
    if(i == 0) { [line moveToPoint:point]; } else { [line addLineToPoint:point]; }
  }
  UIColor *color = self.humidity ? t.humidityLine : t.temperatureLine;
  UIBezierPath *area = [line copy];
  [area addLineToPoint:CGPointMake(self.xs.lastObject.doubleValue, 96)];
  [area addLineToPoint:CGPointMake(self.xs.firstObject.doubleValue, 96)];
  [area closePath];
  [area applyTransform:fit]; [line applyTransform:fit];
  [[color colorWithAlphaComponent:.1] setFill]; [area fill];
  line.lineWidth = 2; line.lineCapStyle = kCGLineCapRound; line.lineJoinStyle = kCGLineJoinRound;
  [color setStroke];
  [line stroke];
  NSInteger index = MAX(0, MIN((NSInteger)self.values.count - 1, self.selectedIndex));
  CGPoint centre = CGPointApplyAffineTransform(CGPointMake(self.xs[index].doubleValue, [self yFor:self.values[index].doubleValue]), fit);
  UIBezierPath *circle = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(centre.x - 5, centre.y - 5, 10, 10)];
  [color setFill]; [circle fill];
  circle.lineWidth = 2; [t.background setStroke]; [circle stroke];
}

@end

@implementation GRClimateChartView {
  NSArray<NSDictionary *> *_points;
  NSString *_unit;
  GRClimatePlotView *_plot;
  UILabel *_message, *_start, *_end, *_selected;
  UISlider *_slider;
}

- (instancetype)initWithPoints:(NSArray<NSDictionary *> *)points unit:(NSString *)unit humidity:(BOOL)humidity
                          name:(NSString *)name message:(NSString *)message {
  if(!(self = [super initWithFrame:CGRectZero])) { return nil; }
  GRTheme *t = [GRTheme current];
  _points = [points copy]; _unit = [unit copy];
  if(!points.count) {
    _message = GRWrappingLabel(message ?: @"Encara no hi ha historial disponible.", GRFont(12, UIFontWeightRegular), t.muted, 0);
    [self addSubview:_message];
    return self;
  }
  double minimum = [points[0][@"value"] doubleValue], maximum = minimum;
  for(NSDictionary *point in points) { minimum = MIN(minimum, [point[@"value"] doubleValue]); maximum = MAX(maximum, [point[@"value"] doubleValue]); }
  double margin = MAX((maximum - minimum) * 0.12, 0.5);
  NSTimeInterval first = GRParseISODate(points[0][@"time"]).timeIntervalSince1970, last = GRParseISODate(points.lastObject[@"time"]).timeIntervalSince1970;
  NSMutableArray *xs = [NSMutableArray array], *values = [NSMutableArray array];
  for(NSDictionary *point in points) {
    NSTimeInterval time = GRParseISODate(point[@"time"]).timeIntervalSince1970;
    [xs addObject:@(8 + (last == first ? 0 : (time - first) * 304 / (last - first)))];
    [values addObject:point[@"value"]];
  }
  _plot = [GRClimatePlotView new];
  _plot.backgroundColor = [UIColor clearColor]; _plot.contentMode = UIViewContentModeRedraw; _plot.opaque = NO;
  _plot.xs = xs; _plot.values = values; _plot.bottom = minimum - margin; _plot.span = maximum - minimum + 2 * margin;
  _plot.humidity = humidity; _plot.selectedIndex = points.count - 1;
  _plot.isAccessibilityElement = YES; _plot.accessibilityLabel = [@"Historial de " stringByAppendingString:name];
  [self addSubview:_plot];
  _start = GRLabel([GRLogic climateTime:points[0][@"time"]], GRFont(10, UIFontWeightRegular), t.muted);
  _end = GRLabel([GRLogic climateTime:points.lastObject[@"time"]], GRFont(10, UIFontWeightRegular), t.muted);
  _end.textAlignment = NSTextAlignmentRight;
  _selected = GRLabel(nil, [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightRegular], t.text);
  _slider = [UISlider new];
  _slider.minimumValue = 0; _slider.maximumValue = MAX(0, (float)points.count - 1); _slider.value = _slider.maximumValue;
  _slider.minimumTrackTintColor = humidity ? t.humidityLine : t.temperatureLine;
  _slider.maximumTrackTintColor = t.line;
  _slider.accessibilityLabel = [NSString stringWithFormat:@"Consulta l’historial de %@", name];
  [_slider addTarget:self action:@selector(selectPoint) forControlEvents:UIControlEventValueChanged];
  for(UIView *view in @[_start, _end, _selected, _slider]) { [self addSubview:view]; }
  [self selectPoint];
  return self;
}

- (void)selectPoint {
  NSInteger index = (NSInteger)lroundf(_slider.value);
  index = MAX(0, MIN((NSInteger)_points.count - 1, index));
  _plot.selectedIndex = index; [_plot setNeedsDisplay];
  NSDictionary *point = _points[index];
  _selected.text = [NSString stringWithFormat:@"%@ · %@%@", [GRLogic climateTime:point[@"time"]], GRFormatNumber([point[@"value"] doubleValue]), _unit.length ? [@" " stringByAppendingString:_unit] : @""];
}

- (CGFloat)heightForWidth:(CGFloat)width {
  if(_message) { return 8 + MAX(24, ceil([_message sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)].height)); }
  return GRPlotHeight + 14 + 10 + 20 + 2 + 32;
}

- (CGSize)sizeThatFits:(CGSize)size { return CGSizeMake(size.width, [self heightForWidth:size.width]); }

- (void)layoutSubviews {
  [super layoutSubviews];
  CGFloat width = self.bounds.size.width;
  if(_message) { _message.frame = CGRectMake(0, 8, width, ceil([_message sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)].height)); return; }
  _plot.frame = CGRectMake(0, 0, width, GRPlotHeight);
  _start.frame = CGRectMake(0, GRPlotHeight, width / 2, 14);
  _end.frame = CGRectMake(width / 2, GRPlotHeight, width / 2, 14);
  _selected.frame = CGRectMake(0, GRPlotHeight + 14 + 10, width, 20);
  _slider.frame = CGRectMake(0, GRPlotHeight + 14 + 10 + 22, width, 32);
}

@end

@implementation GRSparklineView

- (instancetype)initWithFrame:(CGRect)frame {
  if((self = [super initWithFrame:frame])) { self.opaque = NO; self.backgroundColor = [UIColor clearColor]; self.contentMode = UIViewContentModeRedraw; }
  return self;
}

// Averages into at most 18 buckets so the sensor's 0.1° steps do not read as noise.
- (void)setValues:(NSArray<NSNumber *> *)values {
  NSUInteger buckets = MIN(values.count, (NSUInteger)18);
  NSMutableArray *smooth = [NSMutableArray arrayWithCapacity:buckets];
  for(NSUInteger b = 0; b < buckets; b++) {
    NSUInteger start = b * values.count / buckets, end = MAX(start + 1, (b + 1) * values.count / buckets);
    double total = 0;
    for(NSUInteger i = start; i < end; i++) { total += values[i].doubleValue; }
    [smooth addObject:@(total / (end - start))];
  }
  _values = smooth;
  [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
  if(self.values.count < 2) { return; }
  GRTheme *t = [GRTheme current];
  CGSize size = self.bounds.size;
  double minimum = self.values[0].doubleValue, maximum = minimum;
  for(NSNumber *value in self.values) { minimum = MIN(minimum, value.doubleValue); maximum = MAX(maximum, value.doubleValue); }
  double span = MAX(maximum - minimum, .5);
  CGFloat top = 6, height = size.height - top - 4;
  UIBezierPath *line = [UIBezierPath bezierPath];
  NSUInteger count = self.values.count;
  CGPoint previous = CGPointZero;
  for(NSUInteger i = 0; i < count; i++) {
    CGPoint point = CGPointMake(size.width * i / (count - 1), top + height - (self.values[i].doubleValue - minimum) / span * height);
    if(i == 0) { [line moveToPoint:point]; }
    else {
      // Horizontal-tangent curves read as a calm trend rather than a jagged sensor trace.
      CGFloat mid = (previous.x + point.x) / 2;
      [line addCurveToPoint:point controlPoint1:CGPointMake(mid, previous.y) controlPoint2:CGPointMake(mid, point.y)];
    }
    previous = point;
  }
  UIBezierPath *area = [line copy];
  [area addLineToPoint:CGPointMake(size.width, size.height)];
  [area addLineToPoint:CGPointMake(0, size.height)];
  [area closePath];
  [[t.accent colorWithAlphaComponent:t.night ? .09 : .14] setFill]; [area fill];
  line.lineWidth = 2; line.lineCapStyle = kCGLineCapRound; line.lineJoinStyle = kCGLineJoinRound;
  [t.accent setStroke]; [line stroke];
}

@end
