#import "GRClimateChartView.h"
#import "GRLogic.h"
#import "GRTheme.h"
#import "GRUtil.h"

// Plot margins: room for the value labels on the left and the time labels below.
static const CGFloat GRPlotLeft = 54, GRPlotRight = 10, GRPlotTop = 14, GRPlotBottom = 32;

static double GRNiceStep(double raw) {
  double power = pow(10, floor(log10(raw)));
  double fraction = raw / power;
  return (fraction <= 1 ? 1 : fraction <= 2 ? 2 : fraction <= 2.5 ? 2.5 : fraction <= 5 ? 5 : 10) * power;
}

@implementation GRClimateChartView {
  NSArray<NSDictionary *> *_points;
  NSArray<NSNumber *> *_times, *_values;
  NSString *_message;
  BOOL _humidity;
  double _bottom, _top, _step;
}

- (instancetype)initWithPoints:(NSArray<NSDictionary *> *)points humidity:(BOOL)humidity message:(NSString *)message {
  if(!(self = [super initWithFrame:CGRectZero])) { return nil; }
  self.opaque = NO; self.backgroundColor = [UIColor clearColor]; self.contentMode = UIViewContentModeRedraw;
  _humidity = humidity; _message = [message copy];
  NSMutableArray *kept = [NSMutableArray array], *times = [NSMutableArray array], *values = [NSMutableArray array];
  for(NSDictionary *point in points) {
    NSDate *date = GRParseISODate(GRStr(point[@"time"]));
    NSNumber *value = GRNum(point[@"value"]);
    if(!date || !value) { continue; }
    [kept addObject:point]; [times addObject:@(date.timeIntervalSince1970)]; [values addObject:value];
  }
  _points = kept; _times = times; _values = values;
  _selectedIndex = (NSInteger)kept.count - 1;
  if(kept.count) {
    double minimum = [values[0] doubleValue], maximum = minimum;
    for(NSNumber *value in values) { minimum = MIN(minimum, value.doubleValue); maximum = MAX(maximum, value.doubleValue); }
    _step = GRNiceStep(MAX((maximum - minimum) / 4, humidity ? 1 : .2));
    _bottom = floor(minimum / _step) * _step; _top = ceil(maximum / _step) * _step;
    if(_top - _bottom < _step * 2) { _bottom -= _step; _top += _step; }
    [self addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(touched:)]];
    [self addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(touched:)]];
    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitAdjustable;
    self.accessibilityLabel = humidity ? @"Historial d’humitat" : @"Historial de temperatura";
  }
  return self;
}

- (CGRect)plot {
  return CGRectMake(GRPlotLeft, GRPlotTop, MAX(1, self.bounds.size.width - GRPlotLeft - GRPlotRight), MAX(1, self.bounds.size.height - GRPlotTop - GRPlotBottom));
}

- (CGPoint)pointAt:(NSUInteger)i {
  CGRect plot = [self plot];
  double first = _times.firstObject.doubleValue, last = _times.lastObject.doubleValue;
  CGFloat x = last > first ? CGRectGetMinX(plot) + (_times[i].doubleValue - first) / (last - first) * plot.size.width : CGRectGetMidX(plot);
  CGFloat y = CGRectGetMaxY(plot) - (_values[i].doubleValue - _bottom) / (_top - _bottom) * plot.size.height;
  return CGPointMake(x, y);
}

- (NSString *)unitText:(double)value {
  return _humidity ? [NSString stringWithFormat:@"%ld%%", GRRound(value)] : [[GRLogic shortNumber:value] stringByAppendingString:@"°"];
}

- (void)drawText:(NSString *)text at:(CGPoint)point align:(NSTextAlignment)align color:(UIColor *)color {
  NSDictionary *attributes = @{NSFontAttributeName: GRDigits(12, UIFontWeightRegular), NSForegroundColorAttributeName: color};
  CGSize size = [text sizeWithAttributes:attributes];
  CGFloat x = align == NSTextAlignmentRight ? point.x - size.width : (align == NSTextAlignmentCenter ? point.x - size.width / 2 : point.x);
  [text drawAtPoint:CGPointMake(x, point.y - size.height / 2) withAttributes:attributes];
}

- (void)drawRect:(CGRect)rect {
  GRTheme *t = [GRTheme current];
  if(!_points.count) {
    NSMutableParagraphStyle *paragraph = [NSMutableParagraphStyle new];
    paragraph.alignment = NSTextAlignmentCenter;
    NSDictionary *attributes = @{NSFontAttributeName: GRFont(18, UIFontWeightLight), NSForegroundColorAttributeName: t.muted, NSParagraphStyleAttributeName: paragraph};
    NSString *text = _message ?: @"Encara no hi ha historial disponible.";
    CGRect box = CGRectInset(self.bounds, 20, 0);
    CGFloat height = ceil([text boundingRectWithSize:CGSizeMake(box.size.width, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin attributes:attributes context:nil].size.height);
    [text drawInRect:CGRectMake(box.origin.x, (self.bounds.size.height - height) / 2, box.size.width, height) withAttributes:attributes];
    return;
  }
  CGRect plot = [self plot];
  // Horizontal grid with value labels.
  for(double value = _bottom; value <= _top + _step / 2; value += _step) {
    CGFloat y = round(CGRectGetMaxY(plot) - (value - _bottom) / (_top - _bottom) * plot.size.height) + .5;
    UIBezierPath *grid = [UIBezierPath bezierPath];
    [grid moveToPoint:CGPointMake(CGRectGetMinX(plot), y)]; [grid addLineToPoint:CGPointMake(CGRectGetMaxX(plot), y)];
    grid.lineWidth = 1; [t.line setStroke]; [grid stroke];
    [self drawText:[self unitText:value] at:CGPointMake(CGRectGetMinX(plot) - 12, y) align:NSTextAlignmentRight color:t.muted];
  }
  // Five time labels; hours for a day or two, day/month beyond.
  double first = _times.firstObject.doubleValue, last = _times.lastObject.doubleValue;
  NSCalendar *calendar = [NSCalendar currentCalendar];
  for(NSInteger i = 0; i <= 4 && last > first; i++) {
    double time = first + (last - first) * i / 4;
    NSDateComponents *c = [calendar components:NSCalendarUnitDay|NSCalendarUnitMonth|NSCalendarUnitHour|NSCalendarUnitMinute fromDate:[NSDate dateWithTimeIntervalSince1970:time]];
    NSString *label = last - first <= 36 * 3600 ? [NSString stringWithFormat:@"%@:%@", GRPad2(c.hour), GRPad2(c.minute)] : [NSString stringWithFormat:@"%ld/%ld", (long)c.day, (long)c.month];
    CGFloat x = CGRectGetMinX(plot) + plot.size.width * i / 4;
    [self drawText:label at:CGPointMake(x, CGRectGetMaxY(plot) + 18) align:i == 0 ? NSTextAlignmentLeft : (i == 4 ? NSTextAlignmentRight : NSTextAlignmentCenter) color:t.muted];
  }
  UIColor *color = _humidity ? t.humidityLine : t.temperatureLine;
  UIBezierPath *line = [UIBezierPath bezierPath];
  for(NSUInteger i = 0; i < _values.count; i++) {
    CGPoint point = [self pointAt:i];
    if(i == 0) { [line moveToPoint:point]; } else { [line addLineToPoint:point]; }
  }
  UIBezierPath *area = [line copy];
  [area addLineToPoint:CGPointMake([self pointAt:_values.count - 1].x, CGRectGetMaxY(plot))];
  [area addLineToPoint:CGPointMake([self pointAt:0].x, CGRectGetMaxY(plot))];
  [area closePath];
  [[color colorWithAlphaComponent:t.night ? .1 : .14] setFill]; [area fill];
  line.lineWidth = 2.5; line.lineCapStyle = kCGLineCapRound; line.lineJoinStyle = kCGLineJoinRound;
  [color setStroke]; [line stroke];
  // Selected point: guide line and marker.
  CGPoint selected = [self pointAt:(NSUInteger)_selectedIndex];
  UIBezierPath *guide = [UIBezierPath bezierPath];
  [guide moveToPoint:CGPointMake(selected.x, CGRectGetMinY(plot))]; [guide addLineToPoint:CGPointMake(selected.x, CGRectGetMaxY(plot))];
  guide.lineWidth = 1; [t.edge setStroke]; [guide stroke];
  UIBezierPath *marker = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(selected.x - 7, selected.y - 7, 14, 14)];
  [color setFill]; [marker fill];
  marker.lineWidth = 3; [t.background setStroke]; [marker stroke];
}

- (void)selectIndex:(NSInteger)index {
  if(!_points.count) { return; }
  index = MAX(0, MIN((NSInteger)_points.count - 1, index));
  _selectedIndex = index;
  self.accessibilityValue = [NSString stringWithFormat:@"%@, %@", [GRLogic climateTime:_points[index][@"time"]], [self unitText:_values[index].doubleValue]];
  [self setNeedsDisplay];
  if(self.onSelect) { self.onSelect(index); }
}

- (void)touched:(UIGestureRecognizer *)gesture {
  CGFloat x = [gesture locationInView:self].x;
  NSInteger best = 0; CGFloat distance = CGFLOAT_MAX;
  for(NSUInteger i = 0; i < _values.count; i++) {
    CGFloat d = fabs([self pointAt:i].x - x);
    if(d < distance) { distance = d; best = (NSInteger)i; }
  }
  if(best != _selectedIndex) { [self selectIndex:best]; }
}

- (void)accessibilityIncrement { [self selectIndex:_selectedIndex + MAX(1, (NSInteger)_points.count / 24)]; }
- (void)accessibilityDecrement { [self selectIndex:_selectedIndex - MAX(1, (NSInteger)_points.count / 24)]; }

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
