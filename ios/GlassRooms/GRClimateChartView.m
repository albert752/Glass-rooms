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
  CGContextRef context = UIGraphicsGetCurrentContext();
  CGFloat scale = MIN(self.bounds.size.width / 320, self.bounds.size.height / 108);
  CGContextTranslateCTM(context, (self.bounds.size.width - 320 * scale) / 2, (self.bounds.size.height - 108 * scale) / 2);
  CGContextScaleCTM(context, scale, scale);
  CGContextSetStrokeColorWithColor(context, t.chartAxis.CGColor);
  CGContextSetLineWidth(context, 1);
  CGContextMoveToPoint(context, 8, 96); CGContextAddLineToPoint(context, 312, 96);
  CGContextStrokePath(context);
  if(!self.values.count) { return; }
  UIBezierPath *line = [UIBezierPath bezierPath];
  for(NSUInteger i = 0; i < self.values.count; i++) {
    CGPoint point = CGPointMake(self.xs[i].doubleValue, [self yFor:self.values[i].doubleValue]);
    if(i == 0) { [line moveToPoint:point]; } else { [line addLineToPoint:point]; }
  }
  line.lineWidth = 2.5; line.lineCapStyle = kCGLineCapRound; line.lineJoinStyle = kCGLineJoinRound;
  [(self.humidity ? t.humidityLine : t.temperatureLine) setStroke];
  [line stroke];
  NSInteger index = MAX(0, MIN((NSInteger)self.values.count - 1, self.selectedIndex));
  CGRect marker = CGRectMake(self.xs[index].doubleValue - 4, [self yFor:self.values[index].doubleValue] - 4, 8, 8);
  UIBezierPath *circle = [UIBezierPath bezierPathWithOvalInRect:marker];
  [[UIColor whiteColor] setFill]; [circle fill];
  circle.lineWidth = 2; [t.markerStroke setStroke]; [circle stroke];
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
  self.backgroundColor = t.chart;
  self.layer.cornerRadius = 13; self.layer.borderWidth = 1; self.layer.borderColor = t.chartBorder.CGColor;
  if(!points.count) {
    _message = GRWrappingLabel(message ?: @"Encara no hi ha historial disponible.", GRFont(12, UIFontWeightRegular), t.chartEndpoints, 0);
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
  _start = GRLabel([GRLogic climateTime:points[0][@"time"]], GRFont(10, UIFontWeightRegular), t.chartEndpoints);
  _end = GRLabel([GRLogic climateTime:points.lastObject[@"time"]], GRFont(10, UIFontWeightRegular), t.chartEndpoints);
  _end.textAlignment = NSTextAlignmentRight;
  _selected = GRLabel(nil, [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightRegular], t.chartSelected);
  _slider = [UISlider new];
  _slider.minimumValue = 0; _slider.maximumValue = MAX(0, (float)points.count - 1); _slider.value = _slider.maximumValue;
  _slider.minimumTrackTintColor = humidity ? t.humidityLine : t.temperatureLine;
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
  if(_message) { return 12 + MAX(40, ceil([_message sizeThatFits:CGSizeMake(width - 24, CGFLOAT_MAX)].height)) + 4; }
  return 12 + GRPlotHeight + 14 + 10 + 20 + 2 + 32 + 4;
}

- (CGSize)sizeThatFits:(CGSize)size { return CGSizeMake(size.width, [self heightForWidth:size.width]); }

- (void)layoutSubviews {
  [super layoutSubviews];
  CGFloat width = self.bounds.size.width - 24;
  if(_message) { _message.frame = CGRectMake(12, 12, width, ceil([_message sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)].height)); return; }
  _plot.frame = CGRectMake(12, 12, width, GRPlotHeight);
  _start.frame = CGRectMake(12, 12 + GRPlotHeight, width / 2, 14);
  _end.frame = CGRectMake(12 + width / 2, 12 + GRPlotHeight, width / 2, 14);
  _selected.frame = CGRectMake(12, 12 + GRPlotHeight + 14 + 10, width, 20);
  _slider.frame = CGRectMake(12, 12 + GRPlotHeight + 14 + 10 + 22, width, 32);
}

@end
