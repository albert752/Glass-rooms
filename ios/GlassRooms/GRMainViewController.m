#import "GRMainViewController.h"
#import "GRScreenLock.h"
#import "GRClimateChartView.h"
#import "GRLogic.h"
#import "GRPreferences.h"
#import "GRTheme.h"
#import "GRUtil.h"
#import "GRViews.h"

#ifndef GR_VERSION
#define GR_VERSION "dev"
#endif
static NSString *const GRVersion = @GR_VERSION;

#pragma mark - Small views

// Square icon button of the bottom navigation; the active one gets an accent border.
@interface GRNavButton : UIControl
@property (nonatomic, copy) NSString *destination;
@property (nonatomic, strong) UIImageView *icon;
@property (nonatomic) BOOL active;
@end

@implementation GRNavButton
- (instancetype)initWithIcon:(NSString *)icon destination:(NSString *)destination accessibility:(NSString *)accessibility {
  if((self = [super initWithFrame:CGRectMake(0, 0, 56, 56)])) {
    _destination = destination;
    _icon = GRIconView(icon, NO, [GRTheme current].muted);
    _icon.userInteractionEnabled = NO;
    [self addSubview:_icon];
    self.layer.borderWidth = 1;
    self.isAccessibilityElement = YES; self.accessibilityLabel = accessibility; self.accessibilityTraits = UIAccessibilityTraitButton;
  }
  return self;
}
- (void)applyTheme {
  GRTheme *t = [GRTheme current];
  self.icon.tintColor = self.active ? t.accent : t.muted;
  self.layer.borderColor = (self.active ? t.accent : t.edge).CGColor;
  self.layer.cornerRadius = GRRadius(18);
  GRGlow(self.layer, t.accent, 10);
  if(!self.active) { self.layer.shadowOpacity = 0; }
  self.accessibilityTraits = UIAccessibilityTraitButton | (self.active ? UIAccessibilityTraitSelected : 0);
}
- (void)setActive:(BOOL)active { _active = active; [self applyTheme]; }
- (void)setHighlighted:(BOOL)highlighted { [super setHighlighted:highlighted]; self.alpha = highlighted ? .6 : 1; }
- (void)layoutSubviews { [super layoutSubviews]; self.icon.frame = CGRectMake((self.bounds.size.width - 23) / 2, (self.bounds.size.height - 23) / 2, 23, 23); }
@end

// Full-width list row that dims while touched.
@interface GRRowControl : UIControl
@end
@implementation GRRowControl
- (void)setHighlighted:(BOOL)highlighted { [super setHighlighted:highlighted]; self.backgroundColor = highlighted ? [GRTheme current].line : [UIColor clearColor]; }
@end

// Jarvis background: a faint grid and, behind the clock, rings with tick marks like a heads-up display.
@interface GRHUDView : UIView
@property (nonatomic) CGPoint ringCenter;
@property (nonatomic) BOOL showRings;
@end

@implementation GRHUDView
- (instancetype)initWithFrame:(CGRect)frame {
  if((self = [super initWithFrame:frame])) { self.opaque = NO; self.backgroundColor = [UIColor clearColor]; self.userInteractionEnabled = NO; self.contentMode = UIViewContentModeRedraw; }
  return self;
}
- (void)drawRect:(CGRect)rect {
  GRTheme *t = [GRTheme current];
  if(!t.jarvis) { return; }
  CGSize size = self.bounds.size;
  UIBezierPath *grid = [UIBezierPath bezierPath];
  for(CGFloat x = 0; x <= size.width; x += 32) { [grid moveToPoint:CGPointMake(x + .5, 0)]; [grid addLineToPoint:CGPointMake(x + .5, size.height)]; }
  for(CGFloat y = 0; y <= size.height; y += 32) { [grid moveToPoint:CGPointMake(0, y + .5)]; [grid addLineToPoint:CGPointMake(size.width, y + .5)]; }
  grid.lineWidth = 1; [t.grid setStroke]; [grid stroke];
  if(!self.showRings) { return; }
  CGPoint c = self.ringCenter;
  UIColor *ring = [t.accent colorWithAlphaComponent:t.night ? .22 : .18];
  [ring setStroke];
  for(NSArray *arc in @[@[@150, @(-0.55), @(2.4), @1.5], @[@172, @(2.9), @(5.3), @1], @[@196, @(-1.2), @(1.0), @3]]) {
    UIBezierPath *path = [UIBezierPath bezierPathWithArcCenter:c radius:[arc[0] doubleValue] startAngle:[arc[1] doubleValue] endAngle:[arc[2] doubleValue] clockwise:YES];
    path.lineWidth = [arc[3] doubleValue]; [path stroke];
  }
  UIBezierPath *ticks = [UIBezierPath bezierPath];
  for(NSInteger i = 0; i < 72; i++) {
    double angle = i * M_PI * 2 / 72;
    CGFloat inner = i % 6 ? 208 : 202;
    [ticks moveToPoint:CGPointMake(c.x + cos(angle) * inner, c.y + sin(angle) * inner)];
    [ticks addLineToPoint:CGPointMake(c.x + cos(angle) * 214, c.y + sin(angle) * 214)];
  }
  ticks.lineWidth = 1; [[t.accent colorWithAlphaComponent:t.night ? .16 : .14] setStroke]; [ticks stroke];
}
@end

// Bordered card; in the Jarvis style it also gets bracket corners in the accent colour.
@interface GRCardView : GRFlowView
@end

@implementation GRCardView {
  CAShapeLayer *_brackets;
}
- (void)layoutSubviews {
  [super layoutSubviews];
  GRTheme *t = [GRTheme current];
  if(!t.jarvis) { [_brackets removeFromSuperlayer]; _brackets = nil; return; }
  if(!_brackets) { _brackets = [CAShapeLayer layer]; _brackets.fillColor = nil; _brackets.lineWidth = 2; [self.layer addSublayer:_brackets]; }
  _brackets.strokeColor = t.accent.CGColor;
  _brackets.frame = self.bounds;
  CGFloat w = self.bounds.size.width, h = self.bounds.size.height, l = 16;
  UIBezierPath *path = [UIBezierPath bezierPath];
  [path moveToPoint:CGPointMake(0, l)]; [path addLineToPoint:CGPointZero]; [path addLineToPoint:CGPointMake(l, 0)];
  [path moveToPoint:CGPointMake(w - l, 0)]; [path addLineToPoint:CGPointMake(w, 0)]; [path addLineToPoint:CGPointMake(w, l)];
  [path moveToPoint:CGPointMake(w, h - l)]; [path addLineToPoint:CGPointMake(w, h)]; [path addLineToPoint:CGPointMake(w - l, h)];
  [path moveToPoint:CGPointMake(l, h)]; [path addLineToPoint:CGPointMake(0, h)]; [path addLineToPoint:CGPointMake(0, h - l)];
  _brackets.path = path.CGPath;
  GRGlow(_brackets, t.accent, 6);
}
@end

// Hourly electricity prices: one bar per hour coloured by level, dashed lines at the day's maximum and minimum.
@interface GRPriceChartView : UIView
@property (nonatomic, copy) NSArray *prices; // 24 NSNumber (€/kWh) or NSNull
@property (nonatomic) NSInteger currentHour, selectedHour; // -1 = none
@property (nonatomic, copy, nullable) void (^onSelect)(NSInteger hour);
@end

@implementation GRPriceChartView
- (instancetype)initWithFrame:(CGRect)frame {
  if((self = [super initWithFrame:frame])) {
    self.opaque = NO; self.backgroundColor = [UIColor clearColor]; self.contentMode = UIViewContentModeRedraw;
    _currentHour = -1; _selectedHour = -1;
    [self addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(touched:)]];
    [self addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(touched:)]];
    self.isAccessibilityElement = YES; self.accessibilityLabel = @"Preu de cada hora";
  }
  return self;
}
- (CGRect)plot { return CGRectMake(58, 16, MAX(1, self.bounds.size.width - 58 - 70), MAX(1, self.bounds.size.height - 16 - 30)); }
- (void)touched:(UIGestureRecognizer *)gesture {
  CGRect plot = [self plot];
  NSInteger hour = (NSInteger)floor(([gesture locationInView:self].x - plot.origin.x) / (plot.size.width / 24));
  hour = MAX(0, MIN(23, hour));
  if(hour != _selectedHour && GRNum(self.prices.count == 24 ? self.prices[hour] : nil)) {
    _selectedHour = hour; [self setNeedsDisplay];
    if(self.onSelect) { self.onSelect(hour); }
  }
}
- (void)drawText:(NSString *)text at:(CGPoint)point align:(NSTextAlignment)align color:(UIColor *)color {
  NSDictionary *attributes = @{NSFontAttributeName: GRDigits(12, UIFontWeightRegular), NSForegroundColorAttributeName: color};
  CGSize size = [text sizeWithAttributes:attributes];
  CGFloat x = align == NSTextAlignmentRight ? point.x - size.width : (align == NSTextAlignmentCenter ? point.x - size.width / 2 : point.x);
  [text drawAtPoint:CGPointMake(x, point.y - size.height / 2) withAttributes:attributes];
}
- (void)drawRect:(CGRect)rect {
  GRTheme *t = [GRTheme current];
  if(self.prices.count != 24) { return; }
  CGContextRef context = UIGraphicsGetCurrentContext();
  double low = DBL_MAX, high = -DBL_MAX;
  for(id value in self.prices) { if(GRNum(value)) { low = MIN(low, [value doubleValue]); high = MAX(high, [value doubleValue]); } }
  if(low > high) { return; }
  CGRect plot = [self plot];
  double top = high * 1.08, bottom = MIN(0, low);
  CGFloat (^yFor)(double) = ^CGFloat(double value) { return CGRectGetMaxY(plot) - (value - bottom) / MAX(1e-6, top - bottom) * plot.size.height; };
  for(NSInteger i = 0; i <= 4; i++) {
    double value = bottom + (top - bottom) * i / 4;
    CGFloat y = round(yFor(value)) + .5;
    UIBezierPath *grid = [UIBezierPath bezierPath];
    [grid moveToPoint:CGPointMake(CGRectGetMinX(plot), y)]; [grid addLineToPoint:CGPointMake(CGRectGetMaxX(plot), y)];
    grid.lineWidth = 1; [t.line setStroke]; [grid stroke];
    [self drawText:[GRLogic centsText:value] at:CGPointMake(CGRectGetMinX(plot) - 10, y) align:NSTextAlignmentRight color:t.muted];
  }
  CGFloat slot = plot.size.width / 24;
  for(NSInteger hour = 0; hour < 24; hour++) {
    NSNumber *price = GRNum(self.prices[hour]);
    if(hour % 3 == 0) { [self drawText:GRPad2(hour) at:CGPointMake(plot.origin.x + slot * (hour + .5), CGRectGetMaxY(plot) + 16) align:NSTextAlignmentCenter color:t.muted]; }
    if(!price) { continue; }
    NSString *level = [GRLogic priceLevel:price.doubleValue prices:self.prices];
    UIColor *color = [level isEqualToString:@"low"] ? t.good : ([level isEqualToString:@"high"] ? t.issue : t.accent);
    BOOL focus = hour == self.currentHour || hour == self.selectedHour;
    CGRect bar = CGRectMake(plot.origin.x + slot * hour + 2, yFor(price.doubleValue), slot - 4, CGRectGetMaxY(plot) - yFor(price.doubleValue));
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:bar byRoundingCorners:UIRectCornerTopLeft | UIRectCornerTopRight cornerRadii:CGSizeMake(GRRadius(4), GRRadius(4))];
    CGContextSaveGState(context);
    if(focus && t.glow > 0) { CGContextSetShadowWithColor(context, CGSizeZero, 8, [color colorWithAlphaComponent:t.glow].CGColor); }
    [[color colorWithAlphaComponent:focus || self.currentHour < 0 ? 1 : .55] setFill]; [path fill];
    CGContextRestoreGState(context);
    if(hour == self.selectedHour && hour != self.currentHour) { path.lineWidth = 2; [t.highlight setStroke]; [path stroke]; }
  }
  if(self.currentHour >= 0) {
    [self drawText:@"ARA" at:CGPointMake(plot.origin.x + slot * (self.currentHour + .5), plot.origin.y - 6) align:NSTextAlignmentCenter color:t.highlight];
  }
  for(NSArray *guide in @[@[@(high), @"màx"], @[@(low), @"mín"]]) {
    CGFloat y = round(yFor([guide[0] doubleValue])) + .5;
    UIBezierPath *line = [UIBezierPath bezierPath];
    [line moveToPoint:CGPointMake(CGRectGetMinX(plot), y)]; [line addLineToPoint:CGPointMake(CGRectGetMaxX(plot), y)];
    CGFloat dash[] = {5, 4}; [line setLineDash:dash count:2 phase:0];
    line.lineWidth = 1.5; [t.highlight setStroke]; [line stroke];
    [self drawText:[NSString stringWithFormat:@"%@ %@", guide[1], [GRLogic centsText:[guide[0] doubleValue]]] at:CGPointMake(CGRectGetMaxX(plot) + 8, y) align:NSTextAlignmentLeft color:t.highlight];
  }
}
@end

// iOS 11+ would add safe-area insets on its own (the Mac preview does); iOS 9 never does. Same layout on both.
static void GRFixedInsets(UIScrollView *scroll) {
  if([scroll respondsToSelector:NSSelectorFromString(@"setContentInsetAdjustmentBehavior:")]) { [scroll setValue:@2 forKey:@"contentInsetAdjustmentBehavior"]; }
}

static UIView *GRDot(BOOL lit) {
  GRTheme *t = [GRTheme current];
  UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
  dot.userInteractionEnabled = NO;
  dot.layer.cornerRadius = 5;
  dot.backgroundColor = lit ? t.accent : t.faint;
  if(lit) {
    dot.layer.shadowColor = t.accent.CGColor; dot.layer.shadowOpacity = t.night ? .9 : .6; dot.layer.shadowRadius = 6; dot.layer.shadowOffset = CGSizeZero;
    dot.layer.shadowPath = [UIBezierPath bezierPathWithOvalInRect:dot.bounds].CGPath;
  }
  return dot;
}

#pragma mark - Controller

@interface GRMainViewController () <UITextFieldDelegate>
@property (nonatomic, strong, readwrite) GRPanelModel *model;
@property (nonatomic) BOOL modalDirtyFlag;
@end

@implementation GRMainViewController {
  // Clock column
  UILabel *_clock, *_date, *_status, *_sparkCaption, *_humidityCaption;
  NSArray<UILabel *> *_statLabels, *_statValues;
  GRSparklineView *_spark, *_humiditySpark;
  NSMutableArray<GRNavButton *> *_navButtons;
  GRNavButton *_settingsButton;
  // Content column
  UIScrollView *_scroll;
  GRFlowView *_viewFlow;
  NSString *_currentView;
  // Climate page: chosen sensor and the inspected point (-1 = latest).
  NSString *_climateSensor;
  NSInteger _climateIndex;
  // Security page: chosen camera, last image per camera, the views showing it and the refresh loop.
  NSString *_cameraEntity;
  NSMutableDictionary<NSString *, UIImage *> *_cameraImages;
  NSMapTable<NSString *, UIImageView *> *_cameraViews;
  NSURLSessionDataTask *_cameraTask;
  GRTimer *_cameraTimer;
  BOOL _cameraFailed;
  NSString *_cameraError;
  UIControl *_cameraZoom;
  CGFloat _renderedWidth;
  UIView *_toastView;
  UILabel *_toastLabel;
  GRTimer *_toastTimer, *_clockTimer;
  // Side drawer
  UIView *_modalLayer, *_backdrop, *_drawer;
  UILabel *_modalEyebrow, *_modalTitle;
  UIButton *_closeButton;
  UIScrollView *_modalScroll;
  GRFlowView *_modalFlow;
  NSDictionary *_modal;
  BOOL _modalDirty;
  CGFloat _keyboardHeight;
  NSString *_configurationMessage, *_auditText;
  UITextField *_serverField, *_tokenField, *_lockField;
  // Alarm code typed on the on-screen pin pad, and the dots that show how many digits it has.
  NSMutableString *_alarmCode;
  UILabel *_alarmDots;
  BOOL _night;
  NSString *_style;
  GRHUDView *_hud;
  // Energy page: tomorrow's prices instead of today's, and the inspected hour (-1 = none).
  BOOL _energyTomorrow;
  NSInteger _energyHour;
  // Water heater: target temperature waiting to be sent after the last tap on - or +.
  GRTimer *_heaterTimer;
  NSMutableDictionary<NSString *, NSNumber *> *_heaterTargets;
}

- (instancetype)init {
  if((self = [super init])) {
    _model = [GRPanelModel new];
    _model.delegate = self;
    // The clock column always shows the temperature trend, so history is loaded on every view.
    _model.climateVisible = YES;
    _currentView = @"rooms";
    _climateIndex = -1;
    _cameraImages = [NSMutableDictionary dictionary];
    _cameraViews = [NSMapTable strongToWeakObjectsMapTable];
    _navButtons = [NSMutableArray array];
    _alarmCode = [NSMutableString string];
    _energyHour = -1;
    _heaterTargets = [NSMutableDictionary dictionary];
  }
  return self;
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

- (BOOL)prefersStatusBarHidden { return NO; }
- (UIStatusBarStyle)preferredStatusBarStyle { return _night ? UIStatusBarStyleLightContent : UIStatusBarStyleDefault; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskAll; }

- (CGFloat)statusBarHeight {
  CGRect frame = [UIApplication sharedApplication].statusBarFrame;
  return [UIApplication sharedApplication].statusBarHidden ? 0 : MIN(frame.size.width, frame.size.height);
}

- (BOOL)landscape { return self.view.bounds.size.width > self.view.bounds.size.height; }

#pragma mark View setup

- (void)viewDidLoad {
  [super viewDidLoad];
  [self updateThemeFromPreferences];
  GRTheme *t = [GRTheme current];
  _hud = [GRHUDView new];
  [self.view addSubview:_hud];

  _clock = GRLabel(@"--:--", GRDigits(150, UIFontWeightThin), t.highlight);
  _date = GRLabel(nil, GRFont(20, UIFontWeightRegular), t.muted);
  NSMutableArray *labels = [NSMutableArray array], *values = [NSMutableArray array];
  for(NSInteger i = 0; i < 3; i++) {
    UILabel *label = GRLabel(nil, GRFont(12, UIFontWeightMedium), t.muted);
    UILabel *value = GRLabel(@"—", GRDigits(38, UIFontWeightThin), t.text);
    value.adjustsFontSizeToFitWidth = YES; value.minimumScaleFactor = .5;
    [labels addObject:label]; [values addObject:value];
    [self.view addSubview:label]; [self.view addSubview:value];
  }
  _statLabels = labels; _statValues = values;
  _spark = [GRSparklineView new];
  _spark.isAccessibilityElement = YES;
  _sparkCaption = GRLabel(nil, GRFont(12, UIFontWeightRegular), t.muted);
  _humiditySpark = [GRSparklineView new];
  _humiditySpark.humidity = YES; _humiditySpark.isAccessibilityElement = YES;
  _humidityCaption = GRLabel(nil, GRFont(12, UIFontWeightRegular), t.muted);
  [self.view addSubview:_humiditySpark]; [self.view addSubview:_humidityCaption];
  _status = GRLabel(@"Esperant dades de casa", GRFont(12, UIFontWeightRegular), t.muted);
  for(UIView *view in @[_clock, _date, _spark, _sparkCaption, _status]) { [self.view addSubview:view]; }

  NSArray *items = @[@[@"home", @"rooms", @"Estances"], @[@"thermometer", @"climate", @"Temperatura i humitat"],
                     @[@"fan", @"devices", @"Aparells: escalfador, ventiladors i comandaments"], @[@"spark", @"energy", @"Preu de la llum"],
                     @[@"shield", @"security", @"Seguretat"], @[@"overview", @"overview", @"Resum de casa"]];
  for(NSArray *item in items) {
    GRNavButton *button = [[GRNavButton alloc] initWithIcon:item[0] destination:item[1] accessibility:item[2]];
    [button addTarget:self action:@selector(navTapped:) forControlEvents:UIControlEventTouchUpInside];
    [_navButtons addObject:button]; [self.view addSubview:button];
  }
  _settingsButton = [[GRNavButton alloc] initWithIcon:@"settings" destination:@"settings" accessibility:@"Ajustos"];
  [_settingsButton addTarget:self action:@selector(navTapped:) forControlEvents:UIControlEventTouchUpInside];
  [self.view addSubview:_settingsButton];

  _scroll = [UIScrollView new];
  _scroll.alwaysBounceVertical = YES;
  _scroll.delaysContentTouches = NO;
  _scroll.showsVerticalScrollIndicator = NO;
  GRFixedInsets(_scroll);
  _viewFlow = [GRFlowView new];
  [_scroll addSubview:_viewFlow];
  [self.view addSubview:_scroll];

  [self buildModalLayer];
  _toastView = [UIView new];
  _toastView.layer.borderWidth = 1;
  _toastView.hidden = YES; _toastView.userInteractionEnabled = NO;
  _toastLabel = GRWrappingLabel(nil, GRFont(14, UIFontWeightRegular), t.toastText, 0);
  [_toastView addSubview:_toastLabel];
  [self.view addSubview:_toastView];

  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  [center addObserver:self selector:@selector(keyboardWillChange:) name:UIKeyboardWillChangeFrameNotification object:nil];
  [center addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];

  [self applyThemeColors];
  [self clockTick];
  [self renderView];
}

- (void)buildModalLayer {
  _modalLayer = [UIView new];
  _modalLayer.hidden = YES;
  _backdrop = [UIView new];
  UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(closeModal)];
  [_backdrop addGestureRecognizer:tap];
  [_modalLayer addSubview:_backdrop];
  _drawer = [UIView new];
  _drawer.accessibilityViewIsModal = YES;
  _drawer.clipsToBounds = YES;
  _modalEyebrow = GRLabel(nil, GRFont(12, UIFontWeightMedium), [GRTheme current].muted);
  _modalTitle = GRLabel(nil, GRFont(40, UIFontWeightThin), [GRTheme current].highlight);
  _modalTitle.adjustsFontSizeToFitWidth = YES; _modalTitle.minimumScaleFactor = .55;
  _modalTitle.accessibilityTraits = UIAccessibilityTraitHeader;
  _closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
  _closeButton.layer.borderWidth = 1;
  _closeButton.accessibilityLabel = @"Tanca";
  [_closeButton setImage:GRIcon(@"close", NO) forState:UIControlStateNormal];
  [_closeButton addTarget:self action:@selector(closeModal) forControlEvents:UIControlEventTouchUpInside];
  _modalScroll = [UIScrollView new];
  _modalScroll.alwaysBounceVertical = YES;
  _modalScroll.delaysContentTouches = NO;
  _modalScroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
  GRFixedInsets(_modalScroll);
  _modalFlow = [GRFlowView new];
  [_modalScroll addSubview:_modalFlow];
  UIView *border = [UIView new];
  border.tag = 8;
  for(UIView *view in @[_modalEyebrow, _modalTitle, _closeButton, _modalScroll, border]) { [_drawer addSubview:view]; }
  [_modalLayer addSubview:_drawer];
  [self.view addSubview:_modalLayer];
}

#pragma mark Layout

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  CGSize size = self.view.bounds.size;
  CGFloat top = [self statusBarHeight];
  BOOL landscape = [self landscape];
  CGFloat side = landscape ? 44 : 40;

  // Clock: align the top of the digits, not the font's line box, with the margin.
  UIFont *clockFont = GRDigits(landscape ? 150 : 124, UIFontWeightThin);
  _clock.font = clockFont;
  CGFloat clockTop = top + (landscape ? 30 : 26);
  CGFloat capOffset = ceil(clockFont.ascender - clockFont.capHeight);
  _clock.frame = CGRectMake(side - 4, clockTop - capOffset, 480, ceil(clockFont.lineHeight));
  CGFloat y = clockTop + ceil(clockFont.capHeight) + 18;
  _date.frame = CGRectMake(side + 2, y, landscape ? MIN(470, floor(size.width * .46)) : size.width - 2 * side, 26);
  y += 26 + (landscape ? 36 : 26);

  CGFloat x = side + 2;
  for(NSUInteger i = 0; i < 3; i++) {
    UILabel *label = _statLabels[i], *value = _statValues[i];
    CGFloat width = MAX(ceil([label sizeThatFits:CGSizeMake(300, 20)].width), ceil([value sizeThatFits:CGSizeMake(300, 50)].width));
    width = MIN(width, (landscape ? 470 : size.width - 2 * side) - (x - side));
    label.frame = CGRectMake(x, y, width, 16);
    value.frame = CGRectMake(x, y + 18, width, 46);
    x += width + 36;
  }
  CGFloat statsBottom = y + 18 + 46;

  CGFloat navY = size.height - (landscape ? 32 : 28) - 56;
  NSMutableArray *nav = [_navButtons mutableCopy];
  [nav addObject:_settingsButton];
  CGFloat navWidth = nav.count * 56 + (nav.count - 1) * 12;
  CGFloat navX = landscape ? side : (size.width - navWidth) / 2;
  for(GRNavButton *button in nav) { button.frame = CGRectMake(navX, navY, 56, 56); navX += 56 + 12; }

  if(landscape) {
    CGFloat leftWidth = MIN(470, floor(size.width * .46));
    CGFloat rightWidth = size.width - 2 * side - leftWidth - 66;
    _spark.frame = CGRectMake(side + 2, statsBottom + 30, leftWidth - 2, 72);
    _sparkCaption.frame = CGRectMake(side + 2, CGRectGetMaxY(_spark.frame) + 6, leftWidth, 16);
    _humiditySpark.frame = CGRectMake(side + 2, CGRectGetMaxY(_sparkCaption.frame) + 18, leftWidth - 2, 72);
    _humidityCaption.frame = CGRectMake(side + 2, CGRectGetMaxY(_humiditySpark.frame) + 6, leftWidth, 16);
    _status.textAlignment = NSTextAlignmentLeft;
    _status.frame = CGRectMake(side + 2, navY - 18 - 16, leftWidth, 16);
    _scroll.frame = CGRectMake(size.width - side - rightWidth, top, rightWidth, size.height - top);
    _scroll.contentInset = UIEdgeInsetsMake(clockTop - top + 4, 0, 32, 0);
  } else {
    CGFloat sparkWidth = MIN(250, size.width - 2 * side - 330);
    _spark.frame = CGRectMake(size.width - side - sparkWidth, clockTop - 4, sparkWidth, 40);
    _sparkCaption.frame = CGRectMake(size.width - side - sparkWidth, CGRectGetMaxY(_spark.frame) + 3, sparkWidth, 15);
    _humiditySpark.frame = CGRectMake(size.width - side - sparkWidth, CGRectGetMaxY(_sparkCaption.frame) + 10, sparkWidth, 40);
    _humidityCaption.frame = CGRectMake(size.width - side - sparkWidth, CGRectGetMaxY(_humiditySpark.frame) + 3, sparkWidth, 15);
    _status.textAlignment = NSTextAlignmentCenter;
    _status.frame = CGRectMake(side, navY - 14 - 16, size.width - 2 * side, 16);
    CGFloat scrollTop = statsBottom + 14;
    _scroll.frame = CGRectMake(side, scrollTop, size.width - 2 * side, CGRectGetMinY(_status.frame) - 6 - scrollTop);
    _scroll.contentInset = UIEdgeInsetsMake(14, 0, 14, 0);
  }

  // Every page except the rooms and the overview takes the whole screen above the navigation: the clock column steps aside.
  BOOL full = ![_currentView isEqualToString:@"rooms"] && ![_currentView isEqualToString:@"overview"];
  _hud.frame = self.view.bounds;
  _hud.showRings = !full;
  _hud.ringCenter = CGPointMake(CGRectGetMidX(_clock.frame) - (landscape ? 30 : 60), CGRectGetMidY(_clock.frame));
  [_hud setNeedsDisplay];
  NSMutableArray *column = [@[_clock, _date, _spark, _sparkCaption, _humiditySpark, _humidityCaption] mutableCopy];
  [column addObjectsFromArray:_statLabels]; [column addObjectsFromArray:_statValues];
  for(UIView *view in column) { view.alpha = full ? 0 : 1; }
  BOOL fixed = [_currentView isEqualToString:@"climate"];
  _scroll.scrollEnabled = !fixed;
  if(full) {
    _scroll.frame = CGRectMake(side, top + 26, size.width - 2 * side, navY - 24 - (top + 26));
    // While typing in Ajustos, the page scrolls above the keyboard.
    CGFloat covered = MAX(0, _keyboardHeight - (size.height - CGRectGetMaxY(_scroll.frame)));
    _scroll.contentInset = fixed ? UIEdgeInsetsZero : UIEdgeInsetsMake(0, 0, 16 + covered, 0);
    if(fixed) { _scroll.contentOffset = CGPointZero; }
    _status.textAlignment = NSTextAlignmentRight;
    _status.alpha = landscape ? 1 : 0;
    _status.frame = CGRectMake(navX, navY + 20, size.width - side - navX, 16);
  } else { _status.alpha = 1; }

  if(fabs(_renderedWidth - size.width) > .5) { _renderedWidth = size.width; [self renderView]; [self rebuildModal]; }
  else { [self layoutViewFlow]; }
  [self layoutModal];
  [self layoutToast];
}

- (void)layoutViewFlow {
  CGFloat width = _scroll.bounds.size.width;
  CGFloat height = [_viewFlow heightForWidth:width];
  _viewFlow.frame = CGRectMake(0, 0, width, height);
  [_viewFlow setNeedsLayout];
  _scroll.contentSize = CGSizeMake(width, height);
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
  [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
  [self.view endEditing:YES];
}

#pragma mark Theme

- (void)updateThemeFromPreferences {
  _night = [GRLogic isNightForTheme:[GRPreferences shared].theme date:[NSDate date]];
  _style = [GRPreferences shared].style;
  [GRTheme setStyle:_style night:_night];
}

- (void)applyThemeColors {
  GRTheme *t = [GRTheme current];
  self.view.backgroundColor = t.background;
  _clock.textColor = t.highlight; _date.textColor = t.muted;
  GRGlow(_clock.layer, t.highlight, 16);
  _date.font = GRFont(20, UIFontWeightRegular);
  for(UILabel *label in @[_sparkCaption, _humidityCaption, _status]) { label.font = GRFont(12, UIFontWeightRegular); }
  _toastLabel.font = GRFont(14, UIFontWeightRegular);
  _modalEyebrow.font = GRFont(12, UIFontWeightMedium);
  _toastView.layer.cornerRadius = GRRadius(16);
  _closeButton.layer.cornerRadius = GRRadius(22);
  [_hud setNeedsDisplay];
  _sparkCaption.textColor = t.muted; _humidityCaption.textColor = t.muted; _status.textColor = t.muted;
  [_spark setNeedsDisplay]; [_humiditySpark setNeedsDisplay];
  for(GRNavButton *button in _navButtons) { [button applyTheme]; }
  [_settingsButton applyTheme];
  _backdrop.backgroundColor = t.backdrop;
  _drawer.backgroundColor = t.panel;
  [_drawer viewWithTag:8].backgroundColor = t.edge;
  _modalTitle.textColor = t.highlight;
  _closeButton.layer.borderColor = t.edge.CGColor; _closeButton.tintColor = t.muted;
  _toastView.backgroundColor = t.toast; _toastView.layer.borderColor = (t.night ? t.edge : t.toast).CGColor;
  _toastLabel.textColor = t.toastText;
  [self setNeedsStatusBarAppearanceUpdate];
}

- (void)applyTheme {
  BOOL wasNight = _night;
  NSString *wasStyle = _style;
  [self updateThemeFromPreferences];
  if(wasNight == _night && [wasStyle isEqualToString:_style]) { return; }
  [self applyThemeColors];
  [self renderView];
  [self rebuildModal];
}

- (void)setThemeChoice:(NSString *)theme {
  [GRPreferences shared].theme = theme;
  [self applyTheme];
}

- (void)setStyleChoice:(NSString *)style {
  [GRPreferences shared].style = style;
  [self applyTheme];
}

- (void)clockTick {
  NSDate *now = [NSDate date];
  _clock.attributedText = GRKerned([GRLogic clockText:now], _clock.font, [GRTheme current].highlight, [self landscape] ? -6 : -5);
  _clock.accessibilityLabel = [@"Són les " stringByAppendingString:[GRLogic clockText:now]];
  [self renderDate];
  [self applyTheme];
  [_clockTimer cancel];
  __weak GRMainViewController *weakSelf = self;
  NSTimeInterval next = 60 - fmod(now.timeIntervalSince1970, 60) + .05;
  _clockTimer = [GRTimer after:next block:^{ [weakSelf clockTick]; }];
}

#pragma mark Connection

- (void)connectFromPreferences {
  GRPreferences *preferences = [GRPreferences shared];
  NSURL *base = preferences.serverURL.length ? [GRAPIClient normalizedBaseURL:preferences.serverURL error:NULL] : nil;
  GRAPIClient *client = base ? [[GRAPIClient alloc] initWithBaseURL:base token:preferences.token pinnedFingerprint:preferences.pinnedFingerprint] : nil;
  [self.model useClient:client];
}

- (void)appDidEnterBackground {
  [self.model enterBackground];
  [self stopCameraRefresh];
  [self clearAlarmCode];
  [_clockTimer cancel];
}

- (void)appWillEnterForeground {
  [self clockTick];
  [self.model enterForeground];
  [self updateCameraRefresh];
}

#pragma mark Model delegate

- (void)panelModel:(GRPanelModel *)model didUpdateWithForce:(BOOL)force changed:(BOOL)changed {
  if(changed && !([_currentView isEqualToString:@"settings"] && [self isEditingSettings])) { [self renderView]; [self refreshModal]; }
  else { [self renderStatus]; [self renderDate]; }
}

- (void)panelModel:(GRPanelModel *)model showToast:(NSString *)message {
  if(message.length) { [self toast:message]; } else { [self hideToast]; }
}

- (void)panelModel:(GRPanelModel *)model needsConfiguration:(NSString *)reason {
  _configurationMessage = reason;
  [self closeModal];
  if(![_currentView isEqualToString:@"settings"] || ![self isEditingSettings]) { [self navigate:@"settings"]; }
}

- (void)panelModelHistoryDidChange:(GRPanelModel *)model {
  if([_currentView isEqualToString:@"climate"]) { [self renderView]; } else { [self renderSide]; }
}

#pragma mark Toast

- (void)toast:(NSString *)message {
  [_toastTimer cancel];
  _toastLabel.text = message;
  _toastView.hidden = NO;
  [self layoutToast];
  [self.view bringSubviewToFront:_toastView];
  UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, message);
  __weak GRMainViewController *weakSelf = self;
  _toastTimer = [GRTimer after:6 block:^{ [weakSelf hideToast]; }];
}

- (void)hideToast { [_toastTimer cancel]; _toastLabel.text = @""; _toastView.hidden = YES; }

- (void)layoutToast {
  CGSize size = self.view.bounds.size;
  CGFloat width = MIN(420, size.width * .9);
  CGFloat textHeight = ceil([_toastLabel sizeThatFits:CGSizeMake(width - 44, CGFLOAT_MAX)].height);
  CGFloat height = textHeight + 36;
  _toastView.frame = CGRectMake((size.width - width) / 2, size.height - 30 - height - _keyboardHeight, width, height);
  _toastLabel.frame = CGRectMake(22, 18, width - 44, textHeight);
}

#pragma mark Clock column

- (BOOL)live { return self.model.connected || self.model.demo; }

- (void)renderStatus { _status.text = [GRLogic lastUpdateText:self.model.fetchedAt connected:self.model.connected demo:self.model.demo]; }

// The date, followed by the outdoor temperature when a weather.* entity is configured (Barcelona, for example).
- (void)renderDate {
  NSString *date = [GRLogic dateText:[NSDate date]].lowercaseString;
  NSString *weather = [GRLogic weatherLine:self.model.entities connected:self.model.connected];
  _date.text = weather ? [NSString stringWithFormat:@"%@  ·  %@", date, weather] : date;
  _date.adjustsFontSizeToFitWidth = YES; _date.minimumScaleFactor = .7;
}

- (void)setStat:(NSUInteger)index label:(NSString *)label value:(NSString *)value font:(UIFont *)font color:(UIColor *)color {
  GRTheme *t = [GRTheme current];
  _statLabels[index].attributedText = GRKerned(label, GRFont(12, UIFontWeightMedium), t.muted, 1.2);
  _statValues[index].font = font;
  _statValues[index].textColor = color;
  _statValues[index].text = value;
  _statValues[index].accessibilityLabel = [NSString stringWithFormat:@"%@: %@", label.lowercaseString, value];
  _statLabels[index].isAccessibilityElement = NO;
}

// Interior temperature, humidity, alarm (or lights) and the temperature trend.
- (void)renderSide {
  GRTheme *t = [GRTheme current];
  NSArray *entities = self.model.entities;
  BOOL connected = self.model.connected;
  NSNumber *temperature = [GRLogic averageClimate:entities deviceClass:@"temperature" connected:connected];
  NSNumber *humidity = [GRLogic averageClimate:entities deviceClass:@"humidity" connected:connected];
  [self setStat:0 label:@"INTERIOR" value:temperature ? [[GRLogic shortNumber:temperature.doubleValue] stringByAppendingString:@"°"] : @"—"
           font:GRDigits(38, UIFontWeightThin) color:t.text];
  [self setStat:1 label:@"HUMITAT" value:humidity ? [NSString stringWithFormat:@"%ld%%", GRRound(humidity.doubleValue)] : @"—"
           font:GRDigits(38, UIFontWeightThin) color:t.text];
  NSDictionary *alarm = [GRLogic alarmPanel:entities];
  if(alarm) {
    BOOL problem = [alarm[@"state"] isEqual:@"triggered"] || ![alarm[@"status"] isEqual:@"ok"];
    [self setStat:2 label:@"ALARMA" value:[GRLogic stateTextForEntity:alarm connected:connected demo:self.model.demo]
             font:GRFont(24, UIFontWeightLight) color:problem && connected ? t.issue : t.text];
  } else {
    NSArray *lights = [GRLogic lights:entities];
    NSUInteger on = 0;
    for(NSDictionary *light in lights) { if([light[@"status"] isEqual:@"ok"] && [light[@"state"] isEqual:@"on"]) { on++; } }
    [self setStat:2 label:@"LLUMS" value:[self live] && lights.count ? [NSString stringWithFormat:@"%lu encesos", (unsigned long)on] : @"—"
             font:GRFont(24, UIFontWeightLight) color:t.text];
  }

  // Trend of the first temperature sensor and the first humidity sensor that have history.
  NSInteger hours = self.model.historyHours;
  NSString *period = GRPeriodText(hours);
  NSArray *kinds = @[@[@"temperature", _spark, _sparkCaption, @"Temperatura", @"de la temperatura"],
                     @[@"humidity", _humiditySpark, _humidityCaption, @"Humitat", @"de la humitat"]];
  for(NSArray *kind in kinds) {
    NSArray *values = nil; NSString *name = nil;
    for(NSDictionary *sensor in [GRLogic entities:entities inCategory:@"climate"]) {
      if(![GRStr(GRDict(sensor[@"attributes"])[@"device_class"]) isEqualToString:kind[0]]) { continue; }
      NSArray *points = GRArray(self.model.historySeries[sensor[@"entity_id"]]);
      NSMutableArray *numbers = [NSMutableArray array];
      for(id point in points ?: @[]) { if(GRNum(GRDict(point)[@"value"])) { [numbers addObject:point[@"value"]]; } }
      if(numbers.count >= 2) { values = numbers; name = GRStr(sensor[@"name"]); break; }
    }
    GRSparklineView *spark = kind[1];
    UILabel *caption = kind[2];
    spark.values = values ?: @[];
    spark.hidden = !values;
    spark.accessibilityLabel = values ? [NSString stringWithFormat:@"Evolució %@ de %@", kind[4], name ?: @"casa"] : nil;
    caption.text = values ? [NSString stringWithFormat:@"%@ · %@", name ?: kind[3], period]
                          : (self.model.historyLoading && spark == _spark ? @"Carregant l’historial…" : @"");
  }
  [self renderStatus];
  [self renderDate];
  [self.view setNeedsLayout];
}

static NSString *GRPeriodText(NSInteger hours) {
  switch(hours) {
    case 1: return @"última hora";
    case 168: return @"últims 7 dies";
    case 336: return @"últims 14 dies";
    case 720: return @"últim mes";
    default: return [NSString stringWithFormat:@"últimes %ld h", (long)hours];
  }
}

static NSString *GRDuration(NSInteger seconds) {
  if(seconds < 60) { return [NSString stringWithFormat:@"%ld s", (long)seconds]; }
  if(seconds < 3600) { return seconds % 60 ? [NSString stringWithFormat:@"%ld min %ld s", (long)(seconds / 60), (long)(seconds % 60)] : [NSString stringWithFormat:@"%ld min", (long)(seconds / 60)]; }
  return seconds % 3600 ? [NSString stringWithFormat:@"%ld h %ld min", (long)(seconds / 3600), (long)(seconds % 3600 / 60)] : [NSString stringWithFormat:@"%ld h", (long)(seconds / 3600)];
}

#pragma mark Content helpers

- (UILabel *)sectionLabel:(NSString *)text {
  UILabel *label = GRLabel(nil, GRFont(13, UIFontWeightMedium), [GRTheme current].section);
  label.attributedText = GRKerned(text, GRFont(13, UIFontWeightMedium), [GRTheme current].section, 2);
  label.accessibilityTraits = UIAccessibilityTraitHeader;
  return label;
}

- (UILabel *)note:(NSString *)text { return GRWrappingLabel(text, GRFont(13, UIFontWeightRegular), [GRTheme current].muted, 19); }

// A tappable list row: optional icon or dot, title, optional detail, right-hand value and accessory.
- (GRRowControl *)rowWithTitle:(NSString *)title detail:(NSString *)detail detailIssue:(BOOL)detailIssue lead:(UIView *)lead
                         value:(NSString *)value accessory:(UIView *)accessory lit:(BOOL)lit {
  GRTheme *t = [GRTheme current];
  GRRowControl *row = [GRRowControl new];
  UILabel *name = GRLabel(title, GRFont(21, UIFontWeightLight), lit ? t.highlight : t.text);
  name.adjustsFontSizeToFitWidth = YES; name.minimumScaleFactor = .7;
  UILabel *sub = detail.length ? GRLabel(detail, GRFont(13, UIFontWeightRegular), detailIssue ? t.issue : t.muted) : nil;
  UILabel *right = value.length ? GRLabel(value, GRDigits(16, UIFontWeightRegular), t.muted) : nil;
  right.textAlignment = NSTextAlignmentRight;
  UIView *rule = [UIView new]; rule.backgroundColor = t.line;
  for(UIView *view in @[lead ?: [NSNull null], name, sub ?: [NSNull null], right ?: [NSNull null], rule]) {
    if([view isKindOfClass:[UIView class]]) { view.userInteractionEnabled = NO; [row addSubview:view]; }
  }
  if(accessory) { [row addSubview:accessory]; }
  GRBlockView *layout = [GRBlockView new];
  layout.userInteractionEnabled = NO;
  [row addSubview:layout];
  __weak GRRowControl *weakRow = row;
  layout.layout = ^(UIView *view) {
    GRRowControl *r = weakRow;
    CGFloat w = r.bounds.size.width, h = r.bounds.size.height, x = 4, end = w - 4;
    if(lead) { lead.center = CGPointMake(x + lead.bounds.size.width / 2, h / 2); x += lead.bounds.size.width + 16; }
    if(accessory) {
      CGSize a = [accessory isKindOfClass:[UISwitch class]] ? [accessory sizeThatFits:CGSizeZero] : accessory.bounds.size;
      accessory.frame = CGRectMake(end - a.width, (h - a.height) / 2, a.width, a.height); end -= a.width + 16;
    }
    if(right) {
      CGFloat rw = MIN(ceil([right sizeThatFits:CGSizeMake(w, 20)].width), w * .45);
      right.frame = CGRectMake(end - rw, (h - 20) / 2, rw, 20); end -= rw + 14;
    }
    if(sub) {
      name.frame = CGRectMake(x, h / 2 - 25, end - x, 28);
      sub.frame = CGRectMake(x, h / 2 + 4, end - x, 18);
    } else { name.frame = CGRectMake(x, (h - 28) / 2, end - x, 28); }
    rule.frame = CGRectMake(0, h - 1, w, 1);
  };
  // With a switch inside, VoiceOver reads the labels and the switch separately instead of one opaque row.
  row.isAccessibilityElement = ![accessory isKindOfClass:[UISwitch class]];
  row.accessibilityTraits = UIAccessibilityTraitButton;
  return row;
}

- (void)addRows:(NSArray<UIView *> *)rows height:(CGFloat)height top:(CGFloat)top {
  GRBlockView *list = [GRBlockView new];
  for(UIView *row in rows) { [list addSubview:row]; }
  list.measure = ^CGFloat(CGFloat width) { return rows.count * height; };
  list.layout = ^(UIView *view) {
    CGFloat y = 0;
    for(UIView *row in rows) {
      row.frame = CGRectMake(0, y, view.bounds.size.width, height);
      for(UIView *child in row.subviews) { if([child isKindOfClass:[GRBlockView class]]) { [child setNeedsLayout]; [child layoutIfNeeded]; } }
      y += height;
    }
  };
  [_viewFlow addView:list top:top];
}

#pragma mark Views

- (void)navTapped:(GRNavButton *)button { [self navigate:button.destination]; }

- (void)navigate:(NSString *)destination {
  [self closeModal];
  if([destination isEqualToString:@"lights"]) { [self openCategory:@"lights" title:@"Il·luminació"]; return; }
  if([destination isEqualToString:@"scenes"]) { [self openCategory:@"scenes" title:@"Escenes i ambient"]; return; }
  if(![destination isEqualToString:_currentView]) { _energyHour = -1; }
  _currentView = destination;
  [self.view endEditing:YES];
  [self renderView];
  [self.view setNeedsLayout];
  [_scroll setContentOffset:CGPointMake(0, -_scroll.contentInset.top) animated:NO];
}

- (void)renderView {
  if(!_viewFlow) { return; }
  [_viewFlow removeFromSuperview];
  _viewFlow = [GRFlowView new];
  [_scroll addSubview:_viewFlow];
  for(GRNavButton *button in _navButtons) { button.active = [button.destination isEqualToString:_currentView]; }
  _settingsButton.active = [_currentView isEqualToString:@"settings"];
  _serverField = nil; _tokenField = nil; _lockField = nil;
  if([_currentView isEqualToString:@"climate"]) { [self renderClimate]; }
  else if([_currentView isEqualToString:@"security"]) { [self renderSecurity]; }
  else if([_currentView isEqualToString:@"overview"]) { [self renderOverview]; }
  else if([_currentView isEqualToString:@"devices"]) { [self renderDevices]; }
  else if([_currentView isEqualToString:@"energy"]) { [self renderEnergy]; }
  else if([_currentView isEqualToString:@"settings"]) { [self renderSettings]; }
  else { [self renderRooms]; }
  [self renderSide];
  [self layoutViewFlow];
  [self.model loadClimateHistory];
  [self updateCameraRefresh];
}

- (void)renderRooms {
  BOOL live = [self live];
  BOOL canCommand = self.model.connected && !self.model.preview && !self.model.busy;
  NSMutableArray *rows = [NSMutableArray array];
  NSUInteger litRooms = 0, roomsWithLights = 0;
  for(NSDictionary *room in [GRLogic rooms]) {
    NSString *roomId = room[@"id"], *name = room[@"name"];
    NSArray *entities = [GRLogic entities:self.model.entities inRoom:roomId];
    NSArray *roomLights = [GRLogic lights:entities];
    BOOL lit = NO;
    for(NSDictionary *light in roomLights) { if([light[@"status"] isEqual:@"ok"] && [light[@"state"] isEqual:@"on"]) { lit = YES; } }
    lit = lit && live;
    if(lit) { litRooms++; }
    if(roomLights.count) { roomsWithLights++; }
    NSUInteger offline = roomLights.count - [GRLogic onlineLights:roomLights live:live];
    NSString *detail = nil;
    if(!roomLights.count) { detail = @"Sense llums"; }
    else if(live && offline) { detail = offline == 1 ? @"1 llum sense connexió" : [NSString stringWithFormat:@"%lu llums sense connexió", (unsigned long)offline]; }

    NSString *temperature = nil;
    for(NSDictionary *sensor in [GRLogic entities:entities inCategory:@"climate"]) {
      if(![GRStr(GRDict(sensor[@"attributes"])[@"device_class"]) isEqualToString:@"temperature"]) { continue; }
      NSNumber *value = [GRLogic numericState:sensor connected:self.model.connected];
      if(value) { temperature = [[GRLogic shortNumber:value.doubleValue] stringByAppendingString:@"°"]; break; }
    }

    UISwitch *toggle = nil;
    if(roomLights.count) {
      NSString *action = lit ? @"turn_off" : @"turn_on";
      NSArray *pending = [GRLogic lightsNeedingAction:roomLights action:action];
      toggle = [UISwitch new];
      toggle.on = lit;
      toggle.enabled = canCommand && [GRLogic canToggleLights:pending action:action];
      GRStyleSwitch(toggle);
      toggle.accessibilityIdentifier = roomId;
      toggle.accessibilityLabel = [@"Llums de " stringByAppendingString:name];
      toggle.accessibilityHint = toggle.enabled ? nil : @"Control pendent de connexió o verificació";
      [toggle addTarget:self action:@selector(roomSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    }
    GRRowControl *row = [self rowWithTitle:name detail:detail detailIssue:offline > 0 && live lead:GRDot(lit) value:temperature accessory:toggle lit:lit];
    row.accessibilityIdentifier = roomId;
    row.accessibilityLabel = [NSString stringWithFormat:@"Obre %@%@%@", name, roomLights.count && live ? (lit ? @", llums encesos" : @", llums apagats") : @"",
                              temperature ? [@", " stringByAppendingString:temperature] : @""];
    [row addTarget:self action:@selector(roomTapped:) forControlEvents:UIControlEventTouchUpInside];
    [rows addObject:row];
  }
  NSString *heading = !roomsWithLights || !live ? @"ESTANCES"
    : (litRooms ? [NSString stringWithFormat:@"ESTANCES · %lu %@", (unsigned long)litRooms, litRooms == 1 ? @"ENCESA" : @"ENCESES"] : @"ESTANCES · TOT APAGAT");
  if(self.model.demo) { heading = [heading stringByAppendingString:@" · SIMULACIÓ"]; }
  [_viewFlow addView:[self sectionLabel:heading] top:0];
  [self addRows:rows height:64 top:8];

  // Whole-house buttons: only lights with a verified command are touched.
  NSArray *lights = [GRLogic lights:self.model.entities];
  NSArray *readyOn = [GRLogic availableLights:lights action:@"turn_on"], *readyOff = [GRLogic availableLights:lights action:@"turn_off"];
  __weak GRMainViewController *weakSelf = self;
  GRButton *on = [GRButton buttonWithTitle:@"Encén tot" style:GRButtonStylePrimary handler:^(GRButton *b) { [weakSelf globalLights:@"turn_on"]; }];
  GRButton *off = [GRButton buttonWithTitle:@"Apaga tot" style:GRButtonStyleOutline handler:^(GRButton *b) { [weakSelf globalLights:@"turn_off"]; }];
  on.enabled = canCommand && readyOn.count; off.enabled = canCommand && readyOff.count;
  on.accessibilityLabel = readyOn.count < lights.count ? @"Encén els llums disponibles" : @"Encén tots els llums";
  off.accessibilityLabel = readyOff.count < lights.count ? @"Apaga els llums disponibles" : @"Apaga tots els llums";
  GRBlockView *buttons = [GRBlockView new];
  [buttons addSubview:on]; [buttons addSubview:off];
  buttons.measure = ^CGFloat(CGFloat width) { return 54; };
  buttons.layout = ^(UIView *view) {
    CGFloat w = floor((view.bounds.size.width - 10) / 2);
    on.frame = CGRectMake(0, 0, w, 54); off.frame = CGRectMake(w + 10, 0, view.bounds.size.width - w - 10, 54);
  };
  [_viewFlow addView:buttons top:22];
  if(!lights.count) { [_viewFlow addView:[self note:@"Afegeix llums a la configuració del panell."] top:12]; }
  else if(readyOn.count < lights.count || readyOff.count < lights.count) {
    [_viewFlow addView:[self note:[NSString stringWithFormat:@"Només es toquen els llums amb l’ordre verificada (%lu de %lu).",
                                   (unsigned long)MIN(readyOn.count, readyOff.count), (unsigned long)lights.count]] top:12];
  }

  [self addLightGroup:lights to:_viewFlow title:@"TOTS ELS LLUMS" top:28];

  // Scenes, one tap away.
  NSArray *scenes = [GRLogic entities:self.model.entities inCategory:@"scenes"];
  if(scenes.count) {
    [_viewFlow addView:[self sectionLabel:@"ESCENES"] top:28];
    GRWrapView *strip = [GRWrapView new];
    strip.horizontalSpacing = 10;
    NSString *reason = nil;
    for(NSDictionary *scene in scenes) {
      NSDictionary *control = nil;
      for(id item in GRArray(scene[@"controls"]) ?: @[]) { if([GRDict(item)[@"action"] isEqual:@"turn_on"]) { control = item; } }
      GRButton *button = [GRButton buttonWithTitle:GRStr(scene[@"name"]) ?: scene[@"entity_id"] style:GRButtonStyleAction handler:^(GRButton *b) {
        [weakSelf sendAction:scene control:control value:nil code:nil];
      }];
      // A scene that was never activated reads "unknown" in Home Assistant and still works.
      button.enabled = canCommand && [@[@"ok", @"unknown"] containsObject:GRStr(scene[@"status"]) ?: @""] && [control[@"enabled"] isEqual:@YES];
      button.accessibilityLabel = [@"Activa l’escena " stringByAppendingString:GRStr(scene[@"name"]) ?: scene[@"entity_id"]];
      if(!reason && control && ![control[@"enabled"] isEqual:@YES]) { reason = GRStr(control[@"reason"]); }
      [strip addSubview:button];
    }
    [_viewFlow addView:strip top:10];
    if(reason.length && self.model.connected) { [_viewFlow addView:[self note:reason] top:10]; }
  }
}

- (void)globalLights:(NSString *)action {
  NSArray *lights = [GRLogic lights:self.model.entities];
  NSArray *ready = [GRLogic availableLights:lights action:action];
  [self.model turnLights:ready place:@"tota la casa" action:action skipped:lights.count - ready.count];
}

- (void)roomTapped:(UIControl *)row { [self openRoom:row.accessibilityIdentifier]; }

- (void)roomSwitchChanged:(UISwitch *)toggle {
  GRStyleSwitch(toggle);
  NSDictionary *room = [GRLogic roomWithId:toggle.accessibilityIdentifier];
  NSArray *lights = [GRLogic lights:[GRLogic entities:self.model.entities inRoom:room[@"id"]]];
  NSString *action = toggle.on ? @"turn_on" : @"turn_off";
  [self.model turnLights:[GRLogic lightsNeedingAction:lights action:action] place:room[@"name"] action:action skipped:0];
}

- (void)renderOverview {
  GRTheme *t = [GRTheme current];
  [_viewFlow addView:[self sectionLabel:self.model.demo ? @"RESUM DE CASA · SIMULACIÓ" : @"RESUM DE CASA"] top:0];
  NSArray *items = @[@[@"climate", @"Temperatura i humitat", @"thermometer"], @[@"lights", @"Il·luminació", @"light"],
                     @[@"security", @"Seguretat", @"shield"], @[@"water", @"Aigua calenta", @"water"], @[@"media", @"Música i televisió", @"media"],
                     @[@"fans", @"Ventiladors", @"fan"], @[@"energy", @"Preu de la llum", @"spark"], @[@"weather", @"Temps exterior", @"thermometer"],
                     @[@"switches", @"Interruptors", @"light"], @[@"scenes", @"Escenes", @"spark"],
                     @[@"other", @"Altres dispositius", @"overview"]];
  NSMutableArray *rows = [NSMutableArray array];
  for(NSArray *item in items) {
    if(![GRLogic entities:self.model.entities inCategory:item[0]].count) { continue; }
    NSString *value = [GRLogic summaryValueForCategory:item[0] entities:self.model.entities connected:self.model.connected demo:self.model.demo];
    UIImageView *icon = GRIconView(item[2], NO, t.muted);
    icon.frame = CGRectMake(0, 0, 23, 23);
    UILabel *chevron = GRLabel(@"›", GRFont(26, UIFontWeightLight), t.muted);
    chevron.frame = CGRectMake(0, 0, 12, 30); chevron.userInteractionEnabled = NO;
    GRRowControl *row = [self rowWithTitle:item[1] detail:nil detailIssue:NO lead:icon value:value accessory:chevron lit:NO];
    row.accessibilityIdentifier = item[0];
    row.accessibilityLabel = [NSString stringWithFormat:@"%@, %@", item[1], value];
    [row addTarget:self action:@selector(summaryTapped:) forControlEvents:UIControlEventTouchUpInside];
    [rows addObject:row];
  }
  if(rows.count) { [self addRows:rows height:64 top:8]; }
  else { [_viewFlow addView:[self note:@"Pendent de carregar l’inventari. Comprova la connexió amb el panell."] top:16]; }
  __weak GRMainViewController *weakSelf = self;
  GRButton *all = [GRButton buttonWithTitle:@"Veure tots els dispositius" style:GRButtonStyleOutline handler:^(GRButton *button) {
    [weakSelf openCategory:@"all" title:@"Tots els dispositius"];
  }];
  [_viewFlow addView:all top:22];
}

- (void)summaryTapped:(UIControl *)row {
  NSString *category = row.accessibilityIdentifier;
  if([category isEqualToString:@"climate"] || [category isEqualToString:@"security"] || [category isEqualToString:@"energy"]) { [self navigate:category]; return; }
  if([category isEqualToString:@"water"] || [category isEqualToString:@"fans"]) { [self navigate:@"devices"]; return; }
  NSDictionary *titles = @{@"lights": @"Il·luminació", @"security": @"Seguretat", @"water": @"Aigua calenta", @"media": @"Música i televisió",
                           @"fans": @"Ventiladors", @"switches": @"Interruptors", @"scenes": @"Escenes", @"other": @"Altres dispositius", @"weather": @"Temps exterior"};
  [self openCategory:category title:titles[category] ?: @"Dispositius"];
}

// Full-screen climate page: sensor chips, a large reading of the inspected point and the history chart.
- (void)renderClimate {
  GRTheme *t = [GRTheme current];
  __weak GRMainViewController *weakSelf = self;
  NSArray *sensors = [GRLogic entities:self.model.entities inCategory:@"climate"];

  UILabel *title = GRLabel(nil, GRFont(40, UIFontWeightThin), t.highlight);
  title.attributedText = GRKerned(@"Clima", GRFont(40, UIFontWeightThin), t.highlight, -1);
  title.accessibilityTraits = UIAccessibilityTraitHeader;
  NSMutableArray *periods = [NSMutableArray array];
  for(NSArray *period in @[@[@1, @"1 h"], @[@3, @"3 h"], @[@6, @"6 h"], @[@12, @"12 h"], @[@24, @"24 h"], @[@48, @"48 h"],
                           @[@168, @"7 d"], @[@336, @"14 d"], @[@720, @"30 d"]]) {
    NSInteger hours = [period[0] integerValue];
    GRButton *button = [GRButton buttonWithTitle:period[1] style:GRButtonStylePeriod handler:^(GRButton *b) {
      GRMainViewController *strongSelf = weakSelf;
      if(strongSelf) { strongSelf->_climateIndex = -1; }
      [weakSelf.model changeClimatePeriod:hours];
    }];
    button.selectedLook = self.model.historyHours == hours;
    button.accessibilityTraits = UIAccessibilityTraitButton | (button.selectedLook ? UIAccessibilityTraitSelected : 0);
    [periods addObject:button];
  }
  NSString *outdoor = [GRLogic weatherLine:self.model.entities connected:self.model.connected];
  UILabel *weather = GRLabel(outdoor ? [@"Exterior · " stringByAppendingString:outdoor] : nil, GRFont(17, UIFontWeightLight), t.text);
  weather.textAlignment = NSTextAlignmentRight;
  weather.adjustsFontSizeToFitWidth = YES; weather.minimumScaleFactor = .7;
  GRBlockView *header = [GRBlockView new];
  [header addSubview:title]; [header addSubview:weather];
  header.measure = ^CGFloat(CGFloat width) { return 52; };
  header.layout = ^(UIView *view) {
    CGFloat w = view.bounds.size.width;
    title.frame = CGRectMake(0, 0, 160, 52);
    weather.frame = CGRectMake(170, 0, w - 170, 52);
  };
  [_viewFlow addView:header top:0];
  GRBlockView *periodRow = [GRBlockView new];
  for(UIView *button in periods) { [periodRow addSubview:button]; }
  periodRow.measure = ^CGFloat(CGFloat width) { return 44; };
  periodRow.layout = ^(UIView *view) {
    CGFloat w = floor((view.bounds.size.width - 8 * (periods.count - 1)) / periods.count);
    for(NSUInteger i = 0; i < periods.count; i++) { [periods[i] setFrame:CGRectMake(i * (w + 8), 0, w, 44)]; }
  };
  [_viewFlow addView:periodRow top:10];

  if(!sensors.count) {
    [_viewFlow addView:GRWrappingLabel(self.model.connected ? @"Encara no hi ha lectures ambientals." : @"Esperant dades de Home Assistant.", GRFont(28, UIFontWeightLight), t.text, 0) top:40];
    [_viewFlow addView:[self note:self.model.connected ? @"Afegeix els IDs dels sensors de temperatura i humitat a entity_ids. Home Assistant ha de publicar device_class: temperature o humidity. Assigna cada sensor a una habitació amb room_assignments." : @"Quan es recuperi la connexió, apareixeran els sensors ambientals configurats."] top:12];
    return;
  }

  // Sensors in room order; keep the chosen one, else the first temperature sensor.
  NSMutableArray *ordered = [NSMutableArray array];
  for(NSDictionary *room in [GRLogic rooms]) { [ordered addObjectsFromArray:[GRLogic entities:sensors inRoom:room[@"id"]]]; }
  [ordered addObjectsFromArray:[GRLogic entities:sensors inRoom:nil]];
  NSDictionary *chosen = nil;
  for(NSDictionary *sensor in ordered) { if([sensor[@"entity_id"] isEqual:_climateSensor]) { chosen = sensor; } }
  for(NSDictionary *sensor in ordered) {
    if(!chosen && [GRDict(sensor[@"attributes"])[@"device_class"] isEqual:@"temperature"]) { chosen = sensor; }
  }
  chosen = chosen ?: ordered.firstObject;
  _climateSensor = chosen[@"entity_id"];

  NSString *(^format)(NSDictionary *, NSNumber *) = ^NSString *(NSDictionary *sensor, NSNumber *value) {
    if(!value) { return @"—"; }
    BOOL humidity = [GRDict(sensor[@"attributes"])[@"device_class"] isEqual:@"humidity"];
    NSString *unit = GRStr(GRDict(sensor[@"attributes"])[@"unit_of_measurement"]) ?: @"";
    return humidity ? [NSString stringWithFormat:@"%ld%%", GRRound(value.doubleValue)] : [NSString stringWithFormat:@"%@ %@", [GRLogic shortNumber:value.doubleValue], unit];
  };

  UIScrollView *strip = [UIScrollView new];
  strip.showsHorizontalScrollIndicator = NO; strip.alwaysBounceHorizontal = YES; strip.delaysContentTouches = NO;
  NSMutableArray *chips = [NSMutableArray array];
  for(NSDictionary *sensor in ordered) {
    BOOL selected = sensor == chosen;
    BOOL humidity = [GRDict(sensor[@"attributes"])[@"device_class"] isEqual:@"humidity"];
    NSString *roomName = GRStr([GRLogic roomWithId:GRStr(sensor[@"room"]) ?: @""][@"name"]) ?: @"Sense estança";
    NSString *reading = format(sensor, [GRLogic numericState:sensor connected:self.model.connected]);
    GRRowControl *chip = [GRRowControl new];
    chip.layer.cornerRadius = GRRadius(16); chip.layer.borderWidth = selected ? 1.5 : 1;
    chip.layer.borderColor = (selected ? t.accent : t.edge).CGColor;
    chip.clipsToBounds = YES;
    UILabel *room = GRLabel(nil, GRFont(11, UIFontWeightMedium), selected ? t.accent : t.muted);
    room.attributedText = GRKerned(roomName.uppercaseString, room.font, room.textColor, 1.5);
    UILabel *line = GRLabel([NSString stringWithFormat:@"%@ · %@", humidity ? @"Humitat" : @"Temperatura", reading], GRFont(17, UIFontWeightLight), selected ? t.highlight : t.text);
    for(UILabel *label in @[room, line]) { label.userInteractionEnabled = NO; [chip addSubview:label]; }
    CGFloat width = MAX(150, MAX(ceil([room sizeThatFits:CGSizeZero].width), ceil([line sizeThatFits:CGSizeZero].width)) + 36);
    chip.frame = CGRectMake(0, 0, width, 64);
    room.frame = CGRectMake(18, 13, width - 36, 14);
    line.frame = CGRectMake(18, 30, width - 36, 22);
    chip.accessibilityIdentifier = sensor[@"entity_id"];
    chip.isAccessibilityElement = YES;
    chip.accessibilityLabel = [NSString stringWithFormat:@"%@, %@, %@", GRStr(sensor[@"name"]) ?: roomName, humidity ? @"humitat" : @"temperatura", reading];
    chip.accessibilityTraits = UIAccessibilityTraitButton | (selected ? UIAccessibilityTraitSelected : 0);
    [chip addTarget:self action:@selector(climateSensorTapped:) forControlEvents:UIControlEventTouchUpInside];
    [strip addSubview:chip]; [chips addObject:chip];
  }
  GRBlockView *stripRow = [GRBlockView new];
  [stripRow addSubview:strip];
  stripRow.measure = ^CGFloat(CGFloat width) { return 64; };
  stripRow.layout = ^(UIView *view) {
    strip.frame = view.bounds;
    CGFloat x = 0;
    for(UIView *chip in chips) { chip.frame = CGRectMake(x, 0, chip.bounds.size.width, 64); x += chip.bounds.size.width + 10; }
    strip.contentSize = CGSizeMake(MAX(0, x - 10), 64);
  };
  [_viewFlow addView:stripRow top:18];

  // Reading of the inspected point, with the period's minimum, maximum and mean.
  NSArray *raw = GRArray(self.model.historySeries[_climateSensor]) ?: @[];
  NSMutableArray *points = [NSMutableArray array];
  for(id point in raw) { if(GRDict(point) && GRNum(point[@"value"]) && GRParseISODate(GRStr(point[@"time"]))) { [points addObject:point]; } }
  // One record cannot draw a line; the reading above still shows the current value.
  BOOL sparse = points.count == 1;
  if(sparse) { [points removeAllObjects]; }
  BOOL humidity = [GRDict(chosen[@"attributes"])[@"device_class"] isEqual:@"humidity"];
  UILabel *value = GRLabel(nil, GRDigits(64, UIFontWeightThin), t.highlight);
  value.adjustsFontSizeToFitWidth = YES; value.minimumScaleFactor = .6;
  UILabel *when = GRLabel(nil, GRFont(16, UIFontWeightRegular), t.muted);
  NSMutableArray *statViews = [NSMutableArray array];
  double minimum = 0, maximum = 0, total = 0;
  for(NSUInteger i = 0; i < points.count; i++) {
    double v = [points[i][@"value"] doubleValue];
    minimum = i ? MIN(minimum, v) : v; maximum = i ? MAX(maximum, v) : v; total += v;
  }
  NSArray *stats = @[@[@"MÍNIM", points.count ? @(minimum) : [NSNull null]], @[@"MÀXIM", points.count ? @(maximum) : [NSNull null]],
                     @[@"MITJANA", points.count ? @(total / points.count) : [NSNull null]]];
  for(NSArray *stat in stats) {
    UILabel *label = GRLabel(nil, GRFont(12, UIFontWeightMedium), t.muted);
    label.attributedText = GRKerned(stat[0], label.font, t.muted, 1.2);
    UILabel *number = GRLabel(format(chosen, [stat[1] isKindOfClass:[NSNumber class]] ? stat[1] : nil), GRDigits(26, UIFontWeightLight), t.text);
    number.accessibilityLabel = [NSString stringWithFormat:@"%@: %@", [stat[0] lowercaseString], number.text];
    label.isAccessibilityElement = NO;
    [statViews addObject:@[label, number]];
  }
  GRBlockView *readout = [GRBlockView new];
  [readout addSubview:value]; [readout addSubview:when];
  for(NSArray *pair in statViews) { [readout addSubview:pair[0]]; [readout addSubview:pair[1]]; }
  readout.measure = ^CGFloat(CGFloat width) { return 96; };
  readout.layout = ^(UIView *view) {
    CGFloat w = view.bounds.size.width, x = w;
    for(NSArray *pair in [statViews reverseObjectEnumerator]) {
      CGFloat cw = MAX(90, ceil([pair[1] sizeThatFits:CGSizeZero].width));
      x -= cw;
      [pair[0] setFrame:CGRectMake(x, 26, cw, 16)];
      [pair[1] setFrame:CGRectMake(x, 44, cw, 32)];
      x -= 28;
    }
    value.frame = CGRectMake(0, 0, x - 20, 72);
    when.frame = CGRectMake(2, 72, x - 20, 22);
  };
  [_viewFlow addView:readout top:20];

  NSString *message = self.model.historyLoading ? @"Carregant l’historial…"
    : (self.model.historyError ?: (sparse || raw.count ? @"Home Assistant només té un registre d’aquest sensor en aquest període. Prova un període més llarg."
                                                      : @"Home Assistant no té historial d’aquest sensor. Comprova que el recorder el desa."));
  GRClimateChartView *chart = [[GRClimateChartView alloc] initWithPoints:points humidity:humidity message:message];
  NSDictionary *sensor = chosen;
  BOOL connected = self.model.connected;
  void (^show)(NSInteger) = ^(NSInteger index) {
    GRMainViewController *strongSelf = weakSelf;
    if(!points.count) {
      value.text = format(sensor, [GRLogic numericState:sensor connected:connected]);
      when.text = connected ? @"Lectura actual" : @"Pendent de connexió";
      return;
    }
    if(strongSelf) { strongSelf->_climateIndex = index == (NSInteger)points.count - 1 ? -1 : index; }
    value.text = format(sensor, points[index][@"value"]);
    NSString *time = [GRLogic climateTime:points[index][@"time"]];
    when.text = index == (NSInteger)points.count - 1 ? [@"Últim registre · " stringByAppendingString:time] : time;
  };
  chart.onSelect = show;
  if(points.count) { [chart selectIndex:_climateIndex >= 0 && _climateIndex < (NSInteger)points.count ? _climateIndex : (NSInteger)points.count - 1]; }
  else { show(0); }
  GRBlockView *chartRow = [GRBlockView new];
  [chartRow addSubview:chart];
  chartRow.measure = ^CGFloat(CGFloat width) {
    GRMainViewController *strongSelf = weakSelf;
    // Whatever height is left below the header, periods, sensors and reading (52 + 54 + 18 + 64 + 20 + 96 + 16).
    return MAX(220, (strongSelf ? strongSelf->_scroll.bounds.size.height : 400) - 320);
  };
  chartRow.layout = ^(UIView *view) { chart.frame = view.bounds; [chart setNeedsDisplay]; };
  [_viewFlow addView:chartRow top:16];
}

- (void)climateSensorTapped:(UIControl *)chip {
  _climateSensor = chip.accessibilityIdentifier;
  _climateIndex = -1;
  [self renderView];
}

#pragma mark - Security page

// Bordered card with a spaced heading and an optional note on the right.
- (GRFlowView *)card:(NSString *)title note:(NSString *)note {
  GRTheme *t = [GRTheme current];
  GRFlowView *card = [GRCardView new];
  card.insets = UIEdgeInsetsMake(20, 22, 22, 22);
  card.layer.cornerRadius = GRRadius(20); card.layer.borderWidth = 1; card.layer.borderColor = t.edge.CGColor;
  UILabel *heading = [self sectionLabel:title];
  UILabel *side = GRLabel(note, GRFont(13, UIFontWeightRegular), t.muted);
  side.textAlignment = NSTextAlignmentRight;
  GRBlockView *row = [GRBlockView new];
  [row addSubview:heading]; [row addSubview:side];
  row.measure = ^CGFloat(CGFloat width) { return 18; };
  row.layout = ^(UIView *view) {
    CGFloat w = view.bounds.size.width;
    CGFloat sideWidth = MIN(w * .55, ceil([side sizeThatFits:CGSizeZero].width));
    heading.frame = CGRectMake(0, 0, w - sideWidth - 8, 18);
    side.frame = CGRectMake(w - sideWidth, 0, sideWidth, 18);
  };
  [card addView:row top:0];
  return card;
}

// Status row: dot, name, optional detail below, state on the right.
- (UIView *)statusRow:(NSString *)name detail:(NSString *)detail state:(NSString *)state lit:(BOOL)lit issue:(BOOL)issue {
  GRTheme *t = [GRTheme current];
  UIView *dot = GRDot(lit);
  if(issue) { dot.backgroundColor = t.issue; dot.layer.shadowOpacity = 0; }
  UILabel *title = GRLabel(name, GRFont(18, UIFontWeightLight), lit ? t.highlight : t.text);
  title.adjustsFontSizeToFitWidth = YES; title.minimumScaleFactor = .7;
  UILabel *sub = detail.length ? GRLabel(detail, GRFont(12, UIFontWeightRegular), t.muted) : nil;
  UILabel *value = GRLabel(state, GRFont(15, issue || lit ? UIFontWeightMedium : UIFontWeightRegular), issue ? t.issue : (lit ? t.accent : t.muted));
  value.textAlignment = NSTextAlignmentRight;
  UIView *rule = [UIView new]; rule.backgroundColor = t.line;
  GRBlockView *row = [GRBlockView new];
  for(UIView *view in @[dot, title, value, rule]) { [row addSubview:view]; }
  if(sub) { [row addSubview:sub]; }
  row.isAccessibilityElement = YES;
  row.accessibilityLabel = [NSString stringWithFormat:@"%@: %@%@", name, state, detail.length ? [@", " stringByAppendingString:detail] : @""];
  row.measure = ^CGFloat(CGFloat width) { return sub ? 58 : 48; };
  row.layout = ^(UIView *view) {
    CGFloat w = view.bounds.size.width, h = view.bounds.size.height;
    CGFloat valueWidth = MIN(w * .45, ceil([value sizeThatFits:CGSizeZero].width));
    value.frame = CGRectMake(w - valueWidth, (h - 20) / 2, valueWidth, 20);
    CGFloat textWidth = w - 22 - valueWidth - 10;
    if(sub) { title.frame = CGRectMake(22, h / 2 - 22, textWidth, 24); sub.frame = CGRectMake(22, h / 2 + 3, textWidth, 16); }
    else { title.frame = CGRectMake(22, (h - 24) / 2, textWidth, 24); }
    dot.center = CGPointMake(5, CGRectGetMidY(title.frame));
    rule.frame = CGRectMake(0, h - 1, w, 1);
  };
  return row;
}

// Side-by-side columns; each holds a vertical stack of cards.
- (GRBlockView *)columns:(NSArray<NSArray<UIView *> *> *)columns gap:(CGFloat)gap {
  GRBlockView *block = [GRBlockView new];
  for(NSArray *column in columns) { for(UIView *view in column) { [block addSubview:view]; } }
  CGFloat (^place)(CGFloat, BOOL) = ^CGFloat(CGFloat width, BOOL apply) {
    CGFloat columnWidth = floor((width - gap * (columns.count - 1)) / MAX(1, columns.count)), tallest = 0;
    for(NSUInteger c = 0; c < columns.count; c++) {
      CGFloat y = 0;
      for(UIView *view in columns[c]) {
        CGFloat h = [(GRFlowView *)view heightForWidth:columnWidth];
        if(apply) { view.frame = CGRectMake(c * (columnWidth + gap), y, columnWidth, h); [view setNeedsLayout]; }
        y += h + gap;
      }
      tallest = MAX(tallest, y - gap);
    }
    return MAX(0, tallest);
  };
  block.measure = ^CGFloat(CGFloat width) { return place(width, NO); };
  block.layout = ^(UIView *view) { place(view.bounds.size.width, YES); };
  return block;
}

static NSString *GRShortName(NSDictionary *entity, NSArray<NSString *> *suffixes) {
  NSString *name = GRStr(entity[@"name"]) ?: GRStr(entity[@"entity_id"]) ?: @"";
  for(NSString *suffix in suffixes) {
    if(name.length > suffix.length && [name.lowercaseString hasSuffix:suffix]) { name = [name substringToIndex:name.length - suffix.length]; }
  }
  return [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

- (void)renderSecurity {
  GRTheme *t = [GRTheme current];
  BOOL connected = self.model.connected, landscape = [self landscape];
  NSDate *now = [NSDate date];
  NSDictionary *groups = [GRLogic securityGroups:self.model.entities];
  __weak GRMainViewController *weakSelf = self;

  NSUInteger open = 0;
  for(NSDictionary *entity in groups[@"openings"]) { if([entity[@"status"] isEqual:@"ok"] && [entity[@"state"] isEqual:@"on"]) { open++; } }
  NSArray *openings = groups[@"openings"];
  UILabel *title = GRLabel(nil, GRFont(40, UIFontWeightThin), t.highlight);
  title.attributedText = GRKerned(@"Seguretat", title.font, t.highlight, -1);
  title.accessibilityTraits = UIAccessibilityTraitHeader;
  NSString *summary = !connected ? @"Pendent de connexió" : (!openings.count ? @"" : (open ? (open == 1 ? @"1 porta o finestra oberta" : [NSString stringWithFormat:@"%lu portes o finestres obertes", (unsigned long)open]) : @"Tot tancat"));
  UILabel *badge = GRLabel(summary, GRFont(15, UIFontWeightMedium), open ? t.issue : t.accent);
  badge.textAlignment = NSTextAlignmentCenter;
  badge.layer.cornerRadius = GRRadius(18); badge.layer.borderWidth = summary.length ? 1 : 0; badge.layer.borderColor = (open ? t.issue : t.edge).CGColor;
  GRBlockView *header = [GRBlockView new];
  [header addSubview:title]; [header addSubview:badge];
  header.measure = ^CGFloat(CGFloat width) { return 52; };
  header.layout = ^(UIView *view) {
    CGFloat w = view.bounds.size.width, bw = summary.length ? ceil([badge sizeThatFits:CGSizeZero].width) + 32 : 0;
    badge.frame = CGRectMake(w - bw, 8, bw, 36);
    title.frame = CGRectMake(0, 0, w - bw - 12, 52);
  };
  [_viewFlow addView:header top:0];

  // Alarm
  NSDictionary *alarm = [groups[@"alarm"] firstObject];
  GRFlowView *alarmCard = [self card:@"ALARMA" note:alarm ? GRShortName(alarm, @[]) : @""];
  if(alarm) {
    NSString *state = GRStr(alarm[@"state"]) ?: @"";
    BOOL ok = [alarm[@"status"] isEqual:@"ok"] && connected;
    BOOL armed = ok && ([state hasPrefix:@"armed"] || [state isEqualToString:@"arming"] || [state isEqualToString:@"pending"]);
    BOOL alert = ok && [state isEqualToString:@"triggered"];
    UILabel *big = GRLabel([GRLogic stateTextForEntity:alarm connected:connected demo:self.model.demo], GRFont(46, UIFontWeightThin),
                           alert || !ok ? t.issue : (armed ? t.highlight : t.text));
    big.adjustsFontSizeToFitWidth = YES; big.minimumScaleFactor = .5;
    [alarmCard addView:big top:12 height:56];
    NSString *since = [GRLogic agoText:GRStr(alarm[@"changed"]) now:now];
    if(since && ok) { [alarmCard addView:GRLabel([@"Des de " stringByAppendingString:since], GRFont(14, UIFontWeightRegular), t.muted) top:0]; }
    NSMutableArray *arm = [NSMutableArray array];
    NSDictionary *disarm = nil;
    NSMutableOrderedSet *reasons = [NSMutableOrderedSet orderedSet];
    for(id item in GRArray(alarm[@"controls"]) ?: @[]) {
      NSDictionary *control = GRDict(item);
      if(![control[@"kind"] isEqual:@"alarm"]) { continue; }
      if([control[@"action"] isEqual:@"alarm_disarm"]) { disarm = control; } else { [arm addObject:control]; }
      if(![control[@"enabled"] isEqual:@YES] && GRStr(control[@"reason"]).length) { [reasons addObject:control[@"reason"]]; }
    }
    BOOL canCommand = connected && !self.model.preview && !self.model.busy;
    GRButton *(^button)(NSDictionary *, GRButtonStyle) = ^GRButton *(NSDictionary *control, GRButtonStyle style) {
      GRButton *b = [GRButton buttonWithTitle:GRStr(control[@"label"]) style:style handler:^(GRButton *sender) { [weakSelf alarmPrompt:alarm control:control]; }];
      b.enabled = canCommand && [control[@"enabled"] isEqual:@YES];
      return b;
    };
    NSMutableArray *buttons = [NSMutableArray array];
    if(disarm && (armed || alert)) { [buttons addObject:button(disarm, GRButtonStylePrimary)]; }
    if(!armed && !alert) { for(NSDictionary *control in arm) { [buttons addObject:button(control, GRButtonStyleOutline)]; } }
    if(buttons.count) {
      GRBlockView *grid = [GRBlockView new];
      for(UIView *b in buttons) { [grid addSubview:b]; }
      NSUInteger perRow = buttons.count == 1 ? 1 : 2;
      grid.measure = ^CGFloat(CGFloat width) { return ((buttons.count + perRow - 1) / perRow) * 64 - 10; };
      grid.layout = ^(UIView *view) {
        CGFloat w = floor((view.bounds.size.width - 10 * (perRow - 1)) / perRow);
        for(NSUInteger i = 0; i < buttons.count; i++) { [buttons[i] setFrame:CGRectMake((i % perRow) * (w + 10), (i / perRow) * 64, w, 54)]; }
      };
      [alarmCard addView:grid top:18];
    } else if(ok) {
      [alarmCard addView:[self note:@"Cap ordre verificada per a l’estat actual. Revisa verified_actions i alarm_modes."] top:14];
    }
    for(NSString *reason in reasons) { [alarmCard addView:[self note:reason] top:8]; }
  } else {
    [alarmCard addView:[self note:@"Afegeix l’alarma (alarm_control_panel) a entity_ids per veure-la i armar-la des d’aquí."] top:12];
  }

  // Camera and detections
  NSArray *cameras = groups[@"cameras"];
  BOOL knownCamera = NO;
  for(NSDictionary *camera in cameras) { if([camera[@"entity_id"] isEqual:_cameraEntity]) { knownCamera = YES; } }
  if(!knownCamera) { _cameraEntity = [cameras.firstObject objectForKey:@"entity_id"]; }
  GRFlowView *cameraCard = nil;
  if(cameras.count || [groups[@"detections"] count]) {
    NSDictionary *camera = nil;
    for(NSDictionary *item in cameras) { if([item[@"entity_id"] isEqual:_cameraEntity]) { camera = item; } }
    cameraCard = [self card:cameras.count ? @"CÀMERA" : @"DETECCIÓ" note:camera ? GRShortName(camera, @[@" mainstream"]) : @""];
    if(camera) {
      UIImageView *image = [[UIImageView alloc] initWithImage:_cameraImages[_cameraEntity]];
      image.contentMode = UIViewContentModeScaleAspectFill; image.clipsToBounds = YES;
      image.backgroundColor = t.line; image.layer.cornerRadius = GRRadius(14);
      image.userInteractionEnabled = YES;
      image.isAccessibilityElement = YES; image.accessibilityTraits = UIAccessibilityTraitButton | UIAccessibilityTraitImage;
      image.accessibilityLabel = [@"Imatge de la càmera; toca per ampliar-la. " stringByAppendingString:GRShortName(camera, @[@" mainstream"])];
      [image addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(zoomCamera)]];
      UILabel *live = GRLabel(nil, GRFont(11, UIFontWeightSemibold), [UIColor whiteColor]);
      live.tag = 31; live.textAlignment = NSTextAlignmentCenter;
      live.backgroundColor = GRHexA(0x000000, .55); live.layer.cornerRadius = GRRadius(10); live.clipsToBounds = YES;
      [image addSubview:live];
      UILabel *problem = GRLabel(nil, GRFont(14, UIFontWeightRegular), t.muted);
      problem.tag = 33; problem.textAlignment = NSTextAlignmentCenter; problem.numberOfLines = 3;
      [image addSubview:problem];
      [self updateCameraBadge:live];
      [_cameraViews setObject:image forKey:_cameraEntity];
      GRBlockView *frame = [GRBlockView new];
      [frame addSubview:image];
      frame.measure = ^CGFloat(CGFloat width) { return floor(width * 9 / 16); };
      frame.layout = ^(UIView *view) {
        image.frame = view.bounds;
        CGFloat lw = ceil([live sizeThatFits:CGSizeZero].width) + 20;
        live.frame = CGRectMake(10, view.bounds.size.height - 30, lw, 20);
        problem.frame = CGRectInset(view.bounds, 24, 40);
      };
      [cameraCard addView:frame top:14];
      if(cameras.count > 1) {
        GRWrapView *choices = [GRWrapView new];
        choices.horizontalSpacing = 8;
        for(NSDictionary *item in cameras) {
          NSString *entityId = item[@"entity_id"];
          GRButton *choice = [GRButton buttonWithTitle:GRShortName(item, @[@" mainstream"]) style:GRButtonStylePeriod handler:^(GRButton *b) {
            GRMainViewController *strongSelf = weakSelf;
            if(!strongSelf) { return; }
            strongSelf->_cameraEntity = entityId; [strongSelf renderView];
          }];
          choice.selectedLook = [entityId isEqualToString:_cameraEntity];
          [choices addSubview:choice];
        }
        [cameraCard addView:choices top:10];
      }
    }
    for(NSDictionary *detection in groups[@"detections"]) {
      BOOL ok = [detection[@"status"] isEqual:@"ok"] && connected;
      BOOL on = ok && [detection[@"state"] isEqual:@"on"];
      NSString *ago = [GRLogic agoText:GRStr(detection[@"changed"]) now:now];
      NSString *name = GRShortName(detection, @[]);
      NSString *lower = GRStr(detection[@"entity_id"]) ?: @"";
      if([lower rangeOfString:@"person"].location != NSNotFound) { name = @"Persona detectada"; }
      else if([lower rangeOfString:@"motion_alarm"].location != NSNotFound) { name = @"Alarma de moviment"; }
      else if([lower rangeOfString:@"motion"].location != NSNotFound) { name = @"Moviment"; }
      NSString *detail = ok && ago ? [NSString stringWithFormat:@"%@ %@", on ? @"Des de" : @"Últim canvi", ago] : nil;
      [cameraCard addView:[self statusRow:name detail:detail state:ok ? (on ? @"Detectat" : @"Res") : [GRLogic stateTextForEntity:detection connected:connected demo:NO]
                                       lit:on issue:!ok] top:cameraCard.subviews.count > 2 ? 0 : 10];
    }
  }

  // Doors and windows
  GRFlowView *openingsCard = nil;
  if(openings.count) {
    openingsCard = [self card:@"PORTES I FINESTRES" note:connected ? (open ? [NSString stringWithFormat:@"%lu %@", (unsigned long)open, open == 1 ? @"oberta" : @"obertes"] : @"Tot tancat") : @""];
    BOOL first = YES;
    for(NSDictionary *entity in openings) {
      BOOL ok = [entity[@"status"] isEqual:@"ok"] && connected;
      BOOL isOpen = ok && [entity[@"state"] isEqual:@"on"];
      NSString *dc = GRStr(GRDict(entity[@"attributes"])[@"device_class"]) ?: @"";
      BOOL window = [dc isEqualToString:@"window"] || [GRStr(entity[@"entity_id"]) rangeOfString:@"finestra"].location != NSNotFound;
      NSString *state = !ok ? [GRLogic stateTextForEntity:entity connected:connected demo:NO] : (isOpen ? (window ? @"Oberta" : @"Oberta") : @"Tancada");
      NSString *ago = ok ? [GRLogic agoText:GRStr(entity[@"changed"]) now:now] : nil;
      [openingsCard addView:[self statusRow:GRShortName(entity, @[]) detail:ago ? [@"Des de " stringByAppendingString:ago] : nil state:state lit:NO issue:isOpen || !ok] top:first ? 10 : 0];
      first = NO;
    }
  }

  // Batteries: lowest first, warning below 20 %.
  GRFlowView *batteryCard = nil;
  NSMutableArray *batteries = [NSMutableArray array];
  for(NSDictionary *battery in groups[@"batteries"]) {
    NSNumber *value = [GRLogic numericState:battery connected:connected];
    [batteries addObject:@[battery, value ?: @(-1)]];
  }
  [batteries sortUsingComparator:^NSComparisonResult(NSArray *a, NSArray *b) { return [a[1] compare:b[1]]; }];
  if(batteries.count) {
    NSUInteger low = 0;
    for(NSArray *pair in batteries) { if([pair[1] doubleValue] >= 0 && [pair[1] doubleValue] < 20) { low++; } }
    batteryCard = [self card:@"BATERIES" note:low ? [NSString stringWithFormat:@"%lu %@", (unsigned long)low, low == 1 ? @"baixa" : @"baixes"] : (connected ? @"Totes bé" : @"")];
    NSMutableArray *tiles = [NSMutableArray array];
    for(NSArray *pair in batteries) {
      double value = [pair[1] doubleValue];
      BOOL known = value >= 0, weak = known && value < 20;
      UILabel *name = GRLabel(GRShortName(pair[0], @[@" battery", @" bateria"]), GRFont(14, UIFontWeightRegular), t.text);
      name.adjustsFontSizeToFitWidth = YES; name.minimumScaleFactor = .75;
      UILabel *percent = GRLabel(known ? [NSString stringWithFormat:@"%ld %%", GRRound(value)] : @"—", GRDigits(22, UIFontWeightLight), weak ? t.issue : t.highlight);
      UIView *track = [UIView new]; track.backgroundColor = t.line; track.layer.cornerRadius = 3;
      UIView *fill = [UIView new]; fill.backgroundColor = weak ? t.issue : t.accent; fill.layer.cornerRadius = 3;
      GRBlockView *tile = [GRBlockView new];
      for(UIView *view in @[name, percent, track, fill]) { [tile addSubview:view]; }
      tile.isAccessibilityElement = YES;
      tile.accessibilityLabel = [NSString stringWithFormat:@"Bateria de %@: %@%@", name.text, percent.text, weak ? @", baixa" : @""];
      tile.layout = ^(UIView *view) {
        CGFloat w = view.bounds.size.width;
        name.frame = CGRectMake(0, 0, w, 18);
        percent.frame = CGRectMake(0, 20, w, 28);
        track.frame = CGRectMake(0, 54, w, 6);
        fill.frame = CGRectMake(0, 54, known ? w * MIN(1, value / 100) : 0, 6);
      };
      [tiles addObject:tile];
    }
    NSInteger perRow = landscape ? 4 : 3;
    GRBlockView *grid = [GRBlockView new];
    for(UIView *tile in tiles) { [grid addSubview:tile]; }
    NSUInteger rows = (tiles.count + perRow - 1) / perRow;
    grid.measure = ^CGFloat(CGFloat width) { return rows * 60 + (rows - 1) * 18; };
    grid.layout = ^(UIView *view) {
      CGFloat w = floor((view.bounds.size.width - 22 * (perRow - 1)) / perRow);
      for(NSUInteger i = 0; i < tiles.count; i++) {
        [tiles[i] setFrame:CGRectMake((i % perRow) * (w + 22), (i / perRow) * 78, w, 60)];
        [tiles[i] setNeedsLayout];
      }
    };
    [batteryCard addView:grid top:16];
  }

  // Arrangement: doors and windows under the alarm, the camera beside them (below them in portrait), then batteries.
  NSArray *left = openingsCard ? @[alarmCard, openingsCard] : @[alarmCard];
  if(landscape && cameraCard) {
    [_viewFlow addView:[self columns:@[left, @[cameraCard]] gap:16] top:16];
  } else {
    for(UIView *card in left) { [_viewFlow addView:card top:16]; }
    if(cameraCard) { [_viewFlow addView:cameraCard top:16]; }
  }
  if(batteryCard) { [_viewFlow addView:batteryCard top:16]; }
  if(!alarm && !cameras.count && !openings.count && !batteries.count) {
    [_viewFlow addView:[self note:@"Afegeix a entity_ids l’alarma, els sensors de portes i finestres, la càmera i les bateries que vulguis veure aquí."] top:16];
  }
}

#pragma mark - Lights together

static NSDictionary *GRControl(NSDictionary *entity, NSString *action) {
  for(id item in GRArray(entity[@"controls"]) ?: @[]) { if([GRStr(GRDict(item)[@"action"]) isEqualToString:action]) { return item; } }
  return nil;
}

// One brightness and one warmth slider for every light that has them (the Philips Hue lights): the lit ones
// change; when none is lit, all of them switch on with that value.
- (void)addLightGroup:(NSArray *)lights to:(GRFlowView *)flow title:(NSString *)title top:(CGFloat)top {
  GRTheme *t = [GRTheme current];
  BOOL canCommand = self.model.connected && !self.model.preview && !self.model.busy;
  __weak GRMainViewController *weakSelf = self;
  BOOL headed = NO;
  for(NSArray *kind in @[@[@"brightness", @"Brillantor"], @[@"color_temp_kelvin", @"Escalfor"]]) {
    NSString *action = kind[0];
    BOOL warmth = [action isEqualToString:@"color_temp_kelvin"];
    NSMutableArray *capable = [NSMutableArray array];
    double low = DBL_MAX, high = -DBL_MAX;
    NSString *reason = nil;
    for(NSDictionary *light in lights) {
      NSDictionary *control = GRControl(light, action);
      if(![control[@"kind"] isEqual:@"range"] || !GRNum(control[@"min"]) || !GRNum(control[@"max"])) { continue; }
      [capable addObject:light];
      low = MIN(low, [control[@"min"] doubleValue]); high = MAX(high, [control[@"max"] doubleValue]);
      if(!reason && ![control[@"enabled"] isEqual:@YES]) { reason = GRStr(control[@"reason"]); }
    }
    if(!capable.count || low >= high) { continue; }
    NSArray *ready = [GRLogic availableLights:capable action:action];
    NSMutableArray *lit = [NSMutableArray array];
    double total = 0; NSUInteger counted = 0;
    for(NSDictionary *light in ready) {
      if(![GRStr(light[@"state"]) isEqualToString:@"on"]) { continue; }
      [lit addObject:light];
      NSNumber *value = GRNum(GRDict(light[@"attributes"])[action]);
      if(value) { total += value.doubleValue; counted++; }
    }
    NSArray *targets = lit.count ? lit : ready;
    double current = counted ? total / counted : (warmth ? MIN(high, MAX(low, 2700)) : 255);
    if(!headed) { [flow addView:[self sectionLabel:title] top:top]; headed = YES; }
    UILabel *caption = GRLabel(nil, GRFont(15, UIFontWeightRegular), t.text);
    UISlider *slider = [UISlider new];
    slider.minimumValue = warmth ? low : 1; slider.maximumValue = warmth ? high : 255;
    slider.value = current;
    slider.enabled = canCommand && targets.count;
    slider.minimumTrackTintColor = warmth ? GRHex(0xffa647) : t.accent;
    slider.maximumTrackTintColor = warmth ? GRHex(0xa8dcff) : t.line;
    slider.accessibilityLabel = [NSString stringWithFormat:@"%@ de tots els llums", [kind[1] lowercaseString]];
    NSString *(^shown)(double) = ^NSString *(double value) {
      if(!warmth) { return [NSString stringWithFormat:@"%ld %%", GRRound(value / 255 * 100)]; }
      NSString *word = value < 3300 ? @"càlida" : (value < 4600 ? @"neutra" : @"freda");
      return [NSString stringWithFormat:@"%ld K · %@", GRRound(value), word];
    };
    void (^update)(void) = ^{
      caption.text = [NSString stringWithFormat:@"%@ · %@", kind[1], shown(slider.value)];
      slider.accessibilityValue = shown(slider.value);
    };
    update();
    GROnEvent(slider, UIControlEventValueChanged, ^{ update(); weakSelf.modalDirtyFlag = YES; });
    GROnEvent(slider, UIControlEventTouchUpInside | UIControlEventTouchUpOutside, ^{
      weakSelf.modalDirtyFlag = NO;
      [weakSelf.model adjustLights:targets action:action value:@(GRRound(slider.value))];
    });
    [flow addView:caption top:14];
    [flow addView:slider top:4 height:36];
    if(warmth) {
      UILabel *warm = GRLabel(@"Càlida", GRFont(12, UIFontWeightRegular), t.muted), *cool = GRLabel(@"Freda", GRFont(12, UIFontWeightRegular), t.muted);
      cool.textAlignment = NSTextAlignmentRight;
      GRBlockView *ends = [GRBlockView new];
      [ends addSubview:warm]; [ends addSubview:cool];
      ends.measure = ^CGFloat(CGFloat width) { return 16; };
      ends.layout = ^(UIView *view) { CGFloat w = view.bounds.size.width / 2; warm.frame = CGRectMake(0, 0, w, 16); cool.frame = CGRectMake(w, 0, w, 16); };
      [flow addView:ends top:0];
    }
    NSString *note = !ready.count ? (reason ?: @"Cap llum té aquesta ordre verificada.")
      : (lit.count ? [NSString stringWithFormat:@"Canvia %lu %@.", (unsigned long)lit.count, lit.count == 1 ? @"llum encès" : @"llums encesos"]
                   : [NSString stringWithFormat:@"Cap llum encès: se n’encendran %lu.", (unsigned long)ready.count]);
    if(ready.count < capable.count && ready.count) { note = [note stringByAppendingFormat:@" %lu sense l’ordre verificada.", (unsigned long)(capable.count - ready.count)]; }
    [flow addView:[self note:note] top:4];
  }
}

#pragma mark - Devices page (water heater, fans, remotes)

// Label on the left, value on the right, hairline below.
- (UIView *)infoRow:(NSString *)label value:(NSString *)value issue:(BOOL)issue {
  GRTheme *t = [GRTheme current];
  UILabel *name = GRLabel(label, GRFont(15, UIFontWeightRegular), t.muted);
  UILabel *text = GRLabel(value, GRDigits(16, UIFontWeightRegular), issue ? t.issue : t.text);
  text.textAlignment = NSTextAlignmentRight;
  text.adjustsFontSizeToFitWidth = YES; text.minimumScaleFactor = .7;
  UIView *rule = [UIView new]; rule.backgroundColor = t.line;
  GRBlockView *row = [GRBlockView new];
  for(UIView *view in @[name, text, rule]) { [row addSubview:view]; }
  row.isAccessibilityElement = YES;
  row.accessibilityLabel = [NSString stringWithFormat:@"%@: %@", label, value];
  row.measure = ^CGFloat(CGFloat width) { return 42; };
  row.layout = ^(UIView *view) {
    CGFloat w = view.bounds.size.width;
    CGFloat vw = MIN(w * .55, ceil([text sizeThatFits:CGSizeZero].width));
    text.frame = CGRectMake(w - vw, 11, vw, 20);
    name.frame = CGRectMake(0, 11, w - vw - 10, 20);
    rule.frame = CGRectMake(0, 41, w, 1);
  };
  return row;
}

static NSString *GRAttributeValue(NSString *key, id value, NSString *unit) {
  // JSON true/false arrive as CFBoolean, which objCType cannot tell apart from a small number.
  if(value && CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID()) { return [value boolValue] ? @"Sí" : @"No"; }
  if([value isKindOfClass:[NSNumber class]]) {
    NSString *number = [GRFormatNumber([value doubleValue]) stringByReplacingOccurrencesOfString:@"." withString:@","];
    return [key rangeOfString:@"temp"].location != NSNotFound ? [NSString stringWithFormat:@"%@ %@", number, unit] : number;
  }
  NSString *text = GRStr(value) ?: @"—";
  return [text isEqualToString:@"on"] ? @"Activat" : ([text isEqualToString:@"off"] ? @"Desactivat" : text);
}

- (GRFlowView *)heaterCard:(NSDictionary *)heater {
  GRTheme *t = [GRTheme current];
  __weak GRMainViewController *weakSelf = self;
  NSDictionary *a = GRDict(heater[@"attributes"]) ?: @{};
  NSString *entityId = GRStr(heater[@"entity_id"]) ?: @"";
  BOOL ok = [heater[@"status"] isEqual:@"ok"] && self.model.connected;
  BOOL canCommand = self.model.connected && !self.model.preview && !self.model.busy;
  NSString *unit = GRStr(a[@"temperature_unit"]) ?: @"°C";
  NSDictionary *setTemperature = GRControl(heater, @"set_temperature"), *mode = GRControl(heater, @"set_operation_mode");
  NSDictionary *turnOn = GRControl(heater, @"turn_on"), *turnOff = GRControl(heater, @"turn_off");
  NSDictionary *awayOn = GRControl(heater, @"away_mode_on"), *awayOff = GRControl(heater, @"away_mode_off");
  NSMutableOrderedSet *reasons = [NSMutableOrderedSet orderedSet];
  for(id control in GRArray(heater[@"controls"]) ?: @[]) {
    if(![GRDict(control)[@"enabled"] isEqual:@YES] && GRStr(GRDict(control)[@"reason"]).length) { [reasons addObject:control[@"reason"]]; }
  }
  GRFlowView *card = [self card:@"ESCALFADOR" note:GRShortName(heater, @[])];

  // Current water temperature in large, the target next to it, the state and the power switch.
  NSNumber *current = ok ? GRNum(a[@"current_temperature"]) : nil, *target = ok ? GRNum(a[@"temperature"]) : nil;
  UILabel *nowLabel = GRLabel(nil, GRFont(12, UIFontWeightMedium), t.section);
  nowLabel.attributedText = GRKerned(@"ARA", nowLabel.font, t.section, 1.5);
  UILabel *now = GRLabel(current ? [[GRLogic shortNumber:current.doubleValue] stringByAppendingString:@"°"] : @"—", GRDigits(64, UIFontWeightThin), t.highlight);
  GRGlow(now.layer, t.highlight, 12);
  UILabel *targetLabel = GRLabel(nil, GRFont(12, UIFontWeightMedium), t.section);
  targetLabel.attributedText = GRKerned(@"OBJECTIU", targetLabel.font, t.section, 1.5);
  UILabel *targetValue = GRLabel(target ? [[GRLogic shortNumber:target.doubleValue] stringByAppendingString:@"°"] : @"—", GRDigits(34, UIFontWeightLight), t.text);
  UILabel *state = GRLabel([GRLogic stateTextForEntity:heater connected:self.model.connected demo:self.model.demo], GRFont(16, UIFontWeightRegular), ok ? t.muted : t.issue);
  state.textAlignment = NSTextAlignmentRight;
  UISwitch *power = nil;
  if(turnOn && turnOff) {
    power = [UISwitch new];
    power.on = ok && ![GRStr(heater[@"state"]) isEqualToString:@"off"];
    power.enabled = canCommand && ok && [turnOn[@"enabled"] isEqual:@YES] && [turnOff[@"enabled"] isEqual:@YES];
    GRStyleSwitch(power);
    power.accessibilityLabel = @"Escalfador encès";
    __weak UISwitch *weakPower = power;
    GROnEvent(power, UIControlEventValueChanged, ^{ GRStyleSwitch(weakPower); [weakSelf sendAction:heater control:weakPower.on ? turnOn : turnOff value:nil code:nil]; });
  }
  GRBlockView *top = [GRBlockView new];
  for(UIView *view in @[nowLabel, now, targetLabel, targetValue, state]) { [top addSubview:view]; }
  if(power) { [top addSubview:power]; }
  top.measure = ^CGFloat(CGFloat width) { return 96; };
  top.layout = ^(UIView *view) {
    CGFloat w = view.bounds.size.width;
    nowLabel.frame = CGRectMake(0, 4, 140, 16); now.frame = CGRectMake(0, 20, 160, 72);
    targetLabel.frame = CGRectMake(168, 4, 110, 16); targetValue.frame = CGRectMake(168, 30, 110, 42);
    CGSize ps = power ? [power sizeThatFits:CGSizeZero] : CGSizeZero;
    if(power) { power.frame = CGRectMake(w - ps.width, 8, ps.width, ps.height); }
    state.frame = CGRectMake(280, power ? 50 : 30, w - 280, 22);
  };
  [card addView:top top:12];

  // Target temperature: - and + change it, and it is sent 1.5 s after the last tap.
  if(setTemperature && ok) {
    double step = GRNum(setTemperature[@"step"]).doubleValue > 0 ? GRNum(setTemperature[@"step"]).doubleValue : .5;
    double minimum = [GRNum(setTemperature[@"min"]) doubleValue], maximum = [GRNum(setTemperature[@"max"]) doubleValue];
    NSNumber *pending = _heaterTargets[entityId] ?: GRNum(setTemperature[@"value"]) ?: @(minimum);
    BOOL enabled = canCommand && [setTemperature[@"enabled"] isEqual:@YES];
    UILabel *value = GRLabel(nil, GRDigits(30, UIFontWeightLight), _heaterTargets[entityId] ? t.accent : t.text);
    value.textAlignment = NSTextAlignmentCenter;
    void (^show)(double) = ^(double v) { value.text = [NSString stringWithFormat:@"%@ %@", [[GRLogic shortNumber:v] stringByReplacingOccurrencesOfString:@",0" withString:@""], unit]; };
    show(pending.doubleValue);
    void (^change)(double) = ^(double delta) {
      GRMainViewController *strongSelf = weakSelf;
      if(!strongSelf) { return; }
      double next = (strongSelf->_heaterTargets[entityId] ?: pending).doubleValue + delta;
      next = MAX(minimum, MIN(maximum, round(next / step) * step));
      strongSelf->_heaterTargets[entityId] = @(next);
      show(next); value.textColor = [GRTheme current].accent;
      [strongSelf->_heaterTimer cancel];
      strongSelf->_heaterTimer = [GRTimer after:1.5 block:^{
        GRMainViewController *inner = weakSelf;
        NSNumber *chosen = inner ? inner->_heaterTargets[entityId] : nil;
        if(!chosen) { return; }
        [inner->_heaterTargets removeObjectForKey:entityId];
        double v = chosen.doubleValue;
        [inner sendAction:heater control:setTemperature value:v == floor(v) ? @((long long)v) : @(v) code:nil];
      }];
    };
    GRButton *minus = [GRButton buttonWithTitle:@"−" style:GRButtonStyleOutline handler:^(GRButton *b) { change(-step); }];
    GRButton *plus = [GRButton buttonWithTitle:@"+" style:GRButtonStyleOutline handler:^(GRButton *b) { change(step); }];
    minus.fontSize = 30; plus.fontSize = 30;
    minus.enabled = enabled; plus.enabled = enabled;
    minus.accessibilityLabel = @"Baixa la temperatura objectiu"; plus.accessibilityLabel = @"Puja la temperatura objectiu";
    GRBlockView *stepper = [GRBlockView new];
    for(UIView *view in @[minus, value, plus]) { [stepper addSubview:view]; }
    stepper.measure = ^CGFloat(CGFloat width) { return 60; };
    stepper.layout = ^(UIView *view) {
      CGFloat w = view.bounds.size.width;
      minus.frame = CGRectMake(0, 0, 84, 60); plus.frame = CGRectMake(w - 84, 0, 84, 60); value.frame = CGRectMake(90, 0, w - 180, 60);
    };
    [card addView:GRLabel([NSString stringWithFormat:@"Temperatura objectiu · de %@ a %@ %@", GRFormatNumber(minimum), GRFormatNumber(maximum), unit], GRFont(13, UIFontWeightRegular), t.muted) top:16];
    [card addView:stepper top:8];
  }

  // Operation modes: one tap sends the mode.
  NSArray *options = GRArray(mode[@"options"]);
  if(mode && options.count && ok) {
    [card addView:GRLabel(@"Mode", GRFont(13, UIFontWeightRegular), t.muted) top:16];
    GRWrapView *modes = [GRWrapView new];
    modes.horizontalSpacing = 8;
    NSString *selected = GRStr(mode[@"value"]);
    for(id option in options) {
      if(!GRStr(option)) { continue; }
      GRButton *chip = [GRButton buttonWithTitle:option style:GRButtonStylePeriod handler:^(GRButton *b) {
        if(![option isEqual:selected]) { [weakSelf sendAction:heater control:mode value:option code:nil]; }
      }];
      chip.selectedLook = [option isEqual:selected];
      chip.enabled = canCommand && [mode[@"enabled"] isEqual:@YES];
      [modes addSubview:chip];
    }
    [card addView:modes top:8];
  }

  if(awayOn && awayOff && ok) {
    UIView *row = [self switchRow:@"Mode absència" on:[GRStr(a[@"away_mode"]) isEqualToString:@"on"] changed:^(BOOL on) {
      [weakSelf sendAction:heater control:on ? awayOn : awayOff value:nil code:nil];
    }];
    for(UIView *child in row.subviews) {
      if([child isKindOfClass:[UISwitch class]]) { ((UISwitch *)child).enabled = canCommand && [awayOn[@"enabled"] isEqual:@YES]; }
    }
    [card addView:row top:10];
  }
  if(ok) { for(NSString *reason in reasons) { [card addView:[self note:reason] top:8]; } }

  // Everything else the heater reports.
  if(ok) {
    NSDictionary *labels = @{@"current_temperature": @"Temperatura actual", @"temperature": @"Temperatura objectiu",
                             @"target_temp_high": @"Objectiu màxim", @"target_temp_low": @"Objectiu mínim", @"min_temp": @"Mínim admès",
                             @"max_temp": @"Màxim admès", @"target_temp_step": @"Pas de temperatura", @"operation_mode": @"Mode", @"away_mode": @"Mode absència"};
    NSArray *order = @[@"current_temperature", @"temperature", @"target_temp_low", @"target_temp_high", @"operation_mode", @"away_mode", @"min_temp", @"max_temp", @"target_temp_step"];
    NSSet *skip = [NSSet setWithArray:@[@"friendly_name", @"supported_features", @"operation_list", @"temperature_unit"]];
    NSMutableArray *keys = [NSMutableArray array];
    for(NSString *key in order) { if(a[key] && a[key] != [NSNull null]) { [keys addObject:key]; } }
    for(NSString *key in [[a allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
      if(![keys containsObject:key] && ![skip containsObject:key] && a[key] != [NSNull null] && ![a[key] isKindOfClass:[NSArray class]]) { [keys addObject:key]; }
    }
    if(keys.count) {
      [card addView:[self sectionLabel:@"TOTA LA INFORMACIÓ"] top:22];
      for(NSString *key in keys) {
        NSString *label = labels[key];
        if(!label) { label = [[key stringByReplacingOccurrencesOfString:@"_" withString:@" "] stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:[[key substringToIndex:1] uppercaseString]]; }
        [card addView:[self infoRow:label value:GRAttributeValue(key, a[key], unit) issue:NO] top:0];
      }
    }
  }
  // Sensors of the same device (sensor.<heater>_..., switch.<heater>_...).
  NSString *objectId = [entityId componentsSeparatedByString:@"."].lastObject;
  NSMutableArray *related = [NSMutableArray array];
  for(NSDictionary *entity in self.model.entities) {
    NSString *other = [GRStr(entity[@"entity_id"]) componentsSeparatedByString:@"."].lastObject ?: @"";
    if(objectId.length && ![entity[@"entity_id"] isEqual:entityId] && [other hasPrefix:[objectId stringByAppendingString:@"_"]]) { [related addObject:entity]; }
  }
  if(related.count) {
    [card addView:[self sectionLabel:@"SENSORS DE L’ESCALFADOR"] top:22];
    for(NSDictionary *entity in related) {
      BOOL fine = [entity[@"status"] isEqual:@"ok"] && self.model.connected;
      [card addView:[self infoRow:GRShortName(entity, @[]) value:[GRLogic stateTextForEntity:entity connected:self.model.connected demo:self.model.demo] issue:!fine] top:0];
    }
  }
  return card;
}

- (GRFlowView *)remoteCard:(NSDictionary *)remote {
  GRTheme *t = [GRTheme current];
  __weak GRMainViewController *weakSelf = self;
  BOOL canCommand = self.model.connected && !self.model.preview && !self.model.busy;
  GRFlowView *card = [self card:@"COMANDAMENT" note:GRShortName(remote, @[])];
  NSMutableArray *buttons = [NSMutableArray array];
  NSString *reason = nil;
  for(id item in GRArray(remote[@"controls"]) ?: @[]) {
    NSDictionary *control = GRDict(item);
    if(![GRStr(control[@"action"]) hasPrefix:@"command_"]) { continue; }
    GRButton *button = [GRButton buttonWithTitle:GRStr(control[@"label"]) style:GRButtonStyleOutline handler:^(GRButton *b) {
      [weakSelf sendAction:remote control:control value:nil code:nil];
    }];
    button.enabled = canCommand && [control[@"enabled"] isEqual:@YES];
    if(!reason && ![control[@"enabled"] isEqual:@YES]) { reason = GRStr(control[@"reason"]); }
    [buttons addObject:button];
  }
  if(buttons.count) {
    GRBlockView *grid = [GRBlockView new];
    for(UIView *button in buttons) { [grid addSubview:button]; }
    NSUInteger (^columns)(CGFloat) = ^NSUInteger(CGFloat width) { return MAX(2, MIN(5, (NSUInteger)floor((width + 10) / 120))); };
    grid.measure = ^CGFloat(CGFloat width) { NSUInteger rows = (buttons.count + columns(width) - 1) / columns(width); return rows * 64 - 10; };
    grid.layout = ^(UIView *view) {
      NSUInteger c = columns(view.bounds.size.width);
      CGFloat w = floor((view.bounds.size.width - 10 * (c - 1)) / c);
      for(NSUInteger i = 0; i < buttons.count; i++) { [buttons[i] setFrame:CGRectMake((i % c) * (w + 10), (i / c) * 64, w, 54)]; }
    };
    [card addView:grid top:14];
    if(reason.length && self.model.connected) { [card addView:[self note:reason] top:10]; }
  } else if(![remote[@"status"] isEqual:@"ok"] || !self.model.connected) {
    [card addView:GRWrappingLabel([GRLogic stateTextForEntity:remote connected:self.model.connected demo:self.model.demo], GRFont(15, UIFontWeightRegular), t.issue, 0) top:12];
  } else {
    [card addView:[self note:@"Afegeix els botons a remote_buttons (remote.entitat:dispositiu:ordre:Etiqueta) i remote.entitat:send_command a verified_actions."] top:12];
  }
  return card;
}

- (void)renderDevices {
  NSArray *entities = self.model.entities;
  NSMutableArray *heaters = [NSMutableArray array], *fans = [NSMutableArray array], *remotes = [NSMutableArray array];
  for(NSDictionary *entity in entities) {
    NSString *domain = GRStr(entity[@"domain"]);
    if([domain isEqualToString:@"water_heater"]) { [heaters addObject:entity]; }
    else if([domain isEqualToString:@"fan"]) { [fans addObject:entity]; }
    else if([domain isEqualToString:@"remote"]) { [remotes addObject:entity]; }
  }
  [_viewFlow addView:[self pageTitle:@"Aparells"] top:0 height:52];
  NSMutableArray *left = [NSMutableArray array], *right = [NSMutableArray array];
  for(NSDictionary *heater in heaters) { [left addObject:[self heaterCard:heater]]; }
  if(fans.count) {
    GRFlowView *card = [self card:@"VENTILADORS" note:@""];
    [self addEntities:fans to:card];
    [(left.count ? right : left) addObject:card];
  }
  for(NSDictionary *remote in remotes) { [(left.count ? right : left) addObject:[self remoteCard:remote]]; }
  if(!left.count) {
    [_viewFlow addView:[self note:@"Afegeix a entity_ids l’escalfador (water_heater.*), els ventiladors (fan.*) i els emissors d’infrarojos o ràdio (remote.*) per controlar-los des d’aquí."] top:16];
    return;
  }
  if([self landscape] && right.count) { [_viewFlow addView:[self columns:@[left, right] gap:16] top:16]; }
  else { for(UIView *card in [left arrayByAddingObjectsFromArray:right]) { [_viewFlow addView:card top:16]; } }
}

#pragma mark - Energy page (PVPC electricity price)

- (void)renderEnergy {
  GRTheme *t = [GRTheme current];
  __weak GRMainViewController *weakSelf = self;
  NSDictionary *sensor = [GRLogic pvpcSensor:self.model.entities];
  NSDictionary *a = GRDict(sensor[@"attributes"]) ?: @{};
  BOOL connected = self.model.connected;
  NSArray *today = sensor ? [GRLogic pvpcPrices:sensor tomorrow:NO] : @[], *tomorrow = sensor ? [GRLogic pvpcPrices:sensor tomorrow:YES] : @[];
  BOOL showTomorrow = _energyTomorrow && tomorrow.count == 24;
  NSArray *prices = showTomorrow ? tomorrow : today;
  NSNumber *current = sensor ? [GRLogic numericState:sensor connected:connected] : nil;
  NSInteger hour = [[NSCalendar currentCalendar] component:NSCalendarUnitHour fromDate:[NSDate date]];
  if(!current && today.count == 24 && GRNum(today[hour])) { current = today[hour]; }
  NSString *level = current && today.count == 24 ? [GRLogic priceLevel:current.doubleValue prices:today] : nil;
  NSDictionary *levelNames = @{@"low": @"Vall", @"normal": @"Normal", @"high": @"Alta"};
  UIColor *(^levelColor)(NSString *) = ^UIColor *(NSString *l) { return [l isEqualToString:@"low"] ? t.good : ([l isEqualToString:@"high"] ? t.issue : t.accent); };

  UILabel *title = [self pageTitle:@"Preu de la llum"];
  NSString *summary = level ? [NSString stringWithFormat:@"Ara: hora %@", [levelNames[level] lowercaseString]] : @"";
  UILabel *badge = GRLabel(summary, GRFont(15, UIFontWeightMedium), level ? levelColor(level) : t.muted);
  badge.textAlignment = NSTextAlignmentCenter;
  badge.layer.cornerRadius = GRRadius(18); badge.layer.borderWidth = summary.length ? 1 : 0; badge.layer.borderColor = (level ? levelColor(level) : t.edge).CGColor;
  GRBlockView *header = [GRBlockView new];
  [header addSubview:title]; [header addSubview:badge];
  header.measure = ^CGFloat(CGFloat width) { return 52; };
  header.layout = ^(UIView *view) {
    CGFloat w = view.bounds.size.width, bw = summary.length ? ceil([badge sizeThatFits:CGSizeZero].width) + 32 : 0;
    badge.frame = CGRectMake(w - bw, 8, bw, 36); title.frame = CGRectMake(0, 0, w - bw - 12, 52);
  };
  [_viewFlow addView:header top:0];
  if(!sensor) {
    [_viewFlow addView:[self note:@"Afegeix a entity_ids el sensor de la integració «Spain electricity hourly pricing (PVPC)» de Home Assistant (per exemple sensor.esios_pvpc). El panell en llegeix el preu de cada hora del dia i, a partir de les 20.30, el de l’endemà."] top:16];
    return;
  }

  // The reading: the inspected hour or the current price, then the day's minimum, maximum and mean.
  NSInteger inspected = _energyHour >= 0 && _energyHour < (NSInteger)prices.count && GRNum(prices[_energyHour]) ? _energyHour : -1;
  NSNumber *shownPrice = inspected >= 0 ? prices[inspected] : (showTomorrow ? nil : current);
  NSString *shownLevel = shownPrice && prices.count == 24 ? [GRLogic priceLevel:shownPrice.doubleValue prices:prices] : nil;
  UILabel *value = GRLabel(shownPrice ? [GRLogic centsText:shownPrice.doubleValue] : @"—", GRDigits(72, UIFontWeightThin), shownLevel ? levelColor(shownLevel) : t.highlight);
  GRGlow(value.layer, value.textColor, 12);
  UILabel *unit = GRLabel(@"cèntims €/kWh", GRFont(15, UIFontWeightRegular), t.muted);
  NSString *when = inspected >= 0 ? [NSString stringWithFormat:@"%@ de %@ a %@ h", showTomorrow ? @"Demà" : @"Avui", GRPad2(inspected), GRPad2((inspected + 1) % 24)]
    : (showTomorrow ? @"Demà · toca una hora per veure’n el preu" : [NSString stringWithFormat:@"Ara, de %@ a %@ h", GRPad2(hour), GRPad2((hour + 1) % 24)]);
  if(shownLevel) { when = [when stringByAppendingFormat:@" · %@", [levelNames[shownLevel] lowercaseString]]; }
  UILabel *whenLabel = GRLabel(when, GRFont(16, UIFontWeightRegular), t.text);
  double minimum = DBL_MAX, maximum = -DBL_MAX, total = 0; NSInteger count = 0, minHour = -1, maxHour = -1;
  for(NSInteger i = 0; i < (NSInteger)prices.count; i++) {
    NSNumber *price = GRNum(prices[i]);
    if(!price) { continue; }
    if(price.doubleValue < minimum) { minimum = price.doubleValue; minHour = i; }
    if(price.doubleValue > maximum) { maximum = price.doubleValue; maxHour = i; }
    total += price.doubleValue; count++;
  }
  NSMutableArray *statViews = [NSMutableArray array];
  NSArray *stats = @[@[@"MÍNIM", count ? @(minimum) : [NSNull null], minHour >= 0 ? [NSString stringWithFormat:@"a les %@ h", GRPad2(minHour)] : @""],
                     @[@"MÀXIM", count ? @(maximum) : [NSNull null], maxHour >= 0 ? [NSString stringWithFormat:@"a les %@ h", GRPad2(maxHour)] : @""],
                     @[@"MITJANA", count ? @(total / count) : [NSNull null], @"del dia"]];
  for(NSArray *stat in stats) {
    UILabel *label = GRLabel(nil, GRFont(12, UIFontWeightMedium), t.section);
    label.attributedText = GRKerned(stat[0], label.font, t.section, 1.2);
    UILabel *number = GRLabel([stat[1] isKindOfClass:[NSNumber class]] ? [GRLogic centsText:[stat[1] doubleValue]] : @"—", GRDigits(28, UIFontWeightLight), t.text);
    UILabel *detail = GRLabel(stat[2], GRFont(12, UIFontWeightRegular), t.muted);
    [statViews addObject:@[label, number, detail]];
  }
  GRBlockView *readout = [GRBlockView new];
  for(UIView *view in @[value, unit, whenLabel]) { [readout addSubview:view]; }
  for(NSArray *views in statViews) { for(UIView *view in views) { [readout addSubview:view]; } }
  readout.measure = ^CGFloat(CGFloat width) { return 112; };
  readout.layout = ^(UIView *view) {
    CGFloat w = view.bounds.size.width, x = w;
    for(NSArray *views in [statViews reverseObjectEnumerator]) {
      CGFloat cw = MAX(92, ceil([views[1] sizeThatFits:CGSizeZero].width));
      x -= cw;
      [views[0] setFrame:CGRectMake(x, 18, cw, 16)]; [views[1] setFrame:CGRectMake(x, 36, cw, 34)]; [views[2] setFrame:CGRectMake(x, 72, cw, 16)];
      x -= 24;
    }
    CGFloat vw = ceil([value sizeThatFits:CGSizeZero].width);
    value.frame = CGRectMake(0, 0, vw, 80);
    unit.frame = CGRectMake(vw + 10, 46, MAX(0, x - vw - 20), 20);
    whenLabel.frame = CGRectMake(2, 84, x - 10, 22);
  };
  [_viewFlow addView:readout top:16];

  if(tomorrow.count == 24) {
    GRWrapView *days = [GRWrapView new];
    days.horizontalSpacing = 8;
    for(NSArray *day in @[@[@NO, @"Avui"], @[@YES, @"Demà"]]) {
      GRButton *button = [GRButton buttonWithTitle:day[1] style:GRButtonStylePeriod handler:^(GRButton *b) {
        GRMainViewController *strongSelf = weakSelf;
        if(!strongSelf) { return; }
        strongSelf->_energyTomorrow = [day[0] boolValue]; strongSelf->_energyHour = -1; [strongSelf renderView];
      }];
      button.selectedLook = showTomorrow == [day[0] boolValue];
      [days addSubview:button];
    }
    [_viewFlow addView:days top:14];
  }

  if(prices.count == 24) {
    GRPriceChartView *chart = [GRPriceChartView new];
    chart.prices = prices;
    chart.currentHour = showTomorrow ? -1 : hour;
    chart.selectedHour = inspected;
    chart.onSelect = ^(NSInteger selected) {
      GRMainViewController *strongSelf = weakSelf;
      if(strongSelf) { strongSelf->_energyHour = selected; [strongSelf renderView]; }
    };
    GRBlockView *chartRow = [GRBlockView new];
    [chartRow addSubview:chart];
    chartRow.measure = ^CGFloat(CGFloat width) { return 300; };
    chartRow.layout = ^(UIView *view) { chart.frame = view.bounds; [chart setNeedsDisplay]; };
    [_viewFlow addView:chartRow top:14];
    // Legend: the three levels and what they mean.
    GRWrapView *legend = [GRWrapView new];
    legend.horizontalSpacing = 22;
    for(NSString *key in @[@"low", @"normal", @"high"]) {
      UILabel *item = GRLabel([NSString stringWithFormat:@"■  %@", levelNames[key]], GRFont(14, UIFontWeightMedium), levelColor(key));
      [legend addSubview:item];
    }
    [_viewFlow addView:legend top:8];
    [_viewFlow addView:[self note:@"Vall: les 8 hores més barates del dia. Alta: les 8 més cares. Normal: la resta. Toca o arrossega sobre la gràfica per veure el preu de cada hora."] top:6];
  } else {
    [_viewFlow addView:[self note:@"Home Assistant encara no ha publicat els preus de cada hora d’aquest sensor."] top:16];
  }

  // Tariff period, the next cheaper hour and the cheapest hours left today.
  GRFlowView *info = [self card:@"TARIFA" note:GRStr(a[@"tariff"]) ?: @""];
  NSDictionary *periods = @{@"P1": @"Punta (P1)", @"P2": @"Pla (P2)", @"P3": @"Vall (P3)"};
  NSString *period = GRStr(a[@"period"]);
  if(period) { [info addView:[self infoRow:@"Període horari ara" value:periods[period] ?: period issue:NO] top:10]; }
  NSString *next = GRStr(a[@"next_period"]);
  NSNumber *hoursToNext = GRNum(a[@"hours_to_next_period"]);
  if(next) { [info addView:[self infoRow:@"Període següent" value:[NSString stringWithFormat:@"%@%@", periods[next] ?: next, hoursToNext ? [NSString stringWithFormat:@" d’aquí a %@ h", GRFormatNumber(hoursToNext.doubleValue)] : @""] issue:NO] top:0]; }
  NSNumber *better = GRNum(a[@"next_better_price"]), *hoursToBetter = GRNum(a[@"hours_to_better_price"]);
  if(better) { [info addView:[self infoRow:@"Propera hora més barata" value:[NSString stringWithFormat:@"%@ c€%@", [GRLogic centsText:better.doubleValue], hoursToBetter ? [NSString stringWithFormat:@" d’aquí a %@ h", GRFormatNumber(hoursToBetter.doubleValue)] : @""] issue:NO] top:0]; }
  if(today.count == 24 && !showTomorrow) {
    NSMutableArray *left = [NSMutableArray array];
    for(NSInteger i = hour; i < 24; i++) { if(GRNum(today[i])) { [left addObject:@[@(i), today[i]]]; } }
    [left sortUsingComparator:^NSComparisonResult(NSArray *x, NSArray *y) { return [x[1] compare:y[1]]; }];
    NSMutableArray *names = [NSMutableArray array];
    for(NSArray *item in [left subarrayWithRange:NSMakeRange(0, MIN(3, left.count))]) {
      [names addObject:[NSString stringWithFormat:@"%@ h (%@)", GRPad2([item[0] integerValue]), [GRLogic centsText:[item[1] doubleValue]]]];
    }
    if(names.count) { [info addView:[self infoRow:@"Hores més barates que queden" value:[names componentsJoinedByString:@", "] issue:NO] top:0]; }
  }
  if(info.subviews.count > 1) { [_viewFlow addView:info top:18]; }
}

#pragma mark Camera refresh

// The badge says whether the image is live; with no image yet, the reason of the last failure is shown over it.
- (void)updateCameraBadge:(UILabel *)badge {
  BOOL hasImage = _cameraImages[_cameraEntity ?: @""] != nil;
  badge.text = hasImage ? (_cameraFailed ? @"SENSE SENYAL" : @"●  EN DIRECTE") : (_cameraFailed ? @"SENSE IMATGE" : @"CARREGANT…");
  UILabel *problem = (UILabel *)[badge.superview viewWithTag:33];
  problem.text = !hasImage && _cameraFailed ? _cameraError : nil;
  [badge.superview.superview setNeedsLayout];
}

- (void)updateCameraRefresh {
  BOOL wanted = [_currentView isEqualToString:@"security"] && _cameraEntity && self.model.connected
    && [UIApplication sharedApplication].applicationState != UIApplicationStateBackground;
  if(!wanted) { [self stopCameraRefresh]; return; }
  if(!_cameraTask && !_cameraTimer) { [self fetchCamera]; }
}

- (void)stopCameraRefresh {
  [_cameraTimer cancel]; _cameraTimer = nil;
  [_cameraTask cancel]; _cameraTask = nil;
}

// One image at a time, the next one 2.5 s after the previous answer, so a slow camera never queues requests.
- (void)fetchCamera {
  _cameraTimer = nil;
  NSString *entityId = _cameraEntity;
  if(!entityId || !self.model.client) { return; }
  NSString *path = [@"/api/camera?entity_id=" stringByAppendingString:[entityId stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
  __weak GRMainViewController *weakSelf = self;
  _cameraTask = [self.model.client GETData:path timeout:20 completion:^(NSString *error, NSData *data, NSInteger status) {
    GRMainViewController *strongSelf = weakSelf;
    if(!strongSelf) { return; }
    strongSelf->_cameraTask = nil;
    UIImage *image = data ? [UIImage imageWithData:data] : nil;
    strongSelf->_cameraFailed = image == nil;
    strongSelf->_cameraError = image ? nil : (error ?: @"La imatge de la càmera no s’ha pogut llegir.");
    if(image) { strongSelf->_cameraImages[entityId] = image; }
    UIImageView *view = [strongSelf->_cameraViews objectForKey:entityId];
    if(image) { view.image = image; }
    [strongSelf updateCameraBadge:(UILabel *)[view viewWithTag:31]];
    UIImageView *zoomed = (UIImageView *)[strongSelf->_cameraZoom viewWithTag:32];
    if(image && zoomed) { zoomed.image = image; }
    if([strongSelf->_currentView isEqualToString:@"security"] && [entityId isEqualToString:strongSelf->_cameraEntity]
       && [UIApplication sharedApplication].applicationState != UIApplicationStateBackground) {
      strongSelf->_cameraTimer = [GRTimer after:status == 429 ? 10 : 2.5 block:^{ [weakSelf fetchCamera]; }];
    } else { [strongSelf updateCameraRefresh]; }
  }];
}

- (void)zoomCamera {
  if(_cameraZoom) { return; }
  _cameraZoom = [[UIControl alloc] initWithFrame:self.view.bounds];
  _cameraZoom.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  _cameraZoom.backgroundColor = [UIColor blackColor];
  _cameraZoom.isAccessibilityElement = YES;
  _cameraZoom.accessibilityLabel = @"Imatge de la càmera ampliada; toca per tancar-la";
  UIImageView *image = [[UIImageView alloc] initWithFrame:_cameraZoom.bounds];
  image.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  image.contentMode = UIViewContentModeScaleAspectFit; image.tag = 32;
  image.image = _cameraImages[_cameraEntity ?: @""];
  image.userInteractionEnabled = NO;
  [_cameraZoom addSubview:image];
  [_cameraZoom addTarget:self action:@selector(closeCameraZoom) forControlEvents:UIControlEventTouchUpInside];
  _cameraZoom.alpha = 0;
  [self.view addSubview:_cameraZoom];
  [UIView animateWithDuration:.2 animations:^{ self->_cameraZoom.alpha = 1; }];
}

- (void)closeCameraZoom {
  UIView *zoom = _cameraZoom;
  _cameraZoom = nil;
  [UIView animateWithDuration:.2 animations:^{ zoom.alpha = 0; } completion:^(BOOL finished) { [zoom removeFromSuperview]; }];
}

#pragma mark - Side drawer

- (void)layoutModal {
  CGSize size = self.view.bounds.size;
  _modalLayer.frame = self.view.bounds;
  _backdrop.frame = _modalLayer.bounds;
  if(!_modal) { return; }
  CGFloat top = [self statusBarHeight];
  CGFloat width = [self landscape] ? MIN(540, floor(size.width * .52)) : MIN(580, size.width - 80);
  // bounds and centre (not frame) so the slide-in transform stays valid.
  _drawer.bounds = CGRectMake(0, 0, width, size.height);
  _drawer.center = CGPointMake(size.width - width / 2, size.height / 2);
  [_drawer viewWithTag:8].frame = CGRectMake(0, 0, 1, size.height);
  CGFloat pad = 36;
  _modalEyebrow.frame = CGRectMake(pad, top + 30, width - 2 * pad - 60, 16);
  _modalTitle.frame = CGRectMake(pad, top + 30 + 20, width - 2 * pad - 60, 50);
  _closeButton.frame = CGRectMake(width - pad - 44, top + 30, 44, 44);
  CGFloat scrollTop = top + 30 + 20 + 50 + 14;
  _modalScroll.frame = CGRectMake(0, scrollTop, width, size.height - scrollTop);
  UIEdgeInsets inset = _modalScroll.contentInset;
  inset.bottom = _keyboardHeight;
  _modalScroll.contentInset = inset; _modalScroll.scrollIndicatorInsets = inset;
  CGFloat height = [_modalFlow heightForWidth:width];
  _modalFlow.frame = CGRectMake(0, 0, width, height);
  [_modalFlow setNeedsLayout];
  _modalScroll.contentSize = CGSizeMake(width, height);
}

- (GRFlowView *)openModal:(NSString *)title eyebrow:(NSString *)eyebrow type:(NSString *)type modalId:(NSString *)modalId {
  BOOL changed = !_modal || ![_modal[@"type"] isEqual:type] || ![_modal[@"id"] isEqual:modalId];
  BOOL wasOpen = _modal != nil;
  _modal = @{@"type": type, @"id": modalId, @"title": title};
  if(changed) { _modalDirty = NO; }
  GRTheme *t = [GRTheme current];
  _modalEyebrow.attributedText = GRKerned(eyebrow, GRFont(12, UIFontWeightMedium), t.muted, 2);
  _modalTitle.attributedText = GRKerned(title, GRFont(40, UIFontWeightThin), t.highlight, -1);
  [_modalFlow removeFromSuperview];
  _modalFlow = [GRFlowView new];
  _modalFlow.insets = UIEdgeInsetsMake(0, 36, 36, 36);
  [_modalScroll addSubview:_modalFlow];
  [self clearAlarmCode]; _alarmDots = nil;
  if(changed) { _modalScroll.contentOffset = CGPointZero; }
  if(!wasOpen) {
    _modalLayer.hidden = NO;
    [self.view bringSubviewToFront:_modalLayer];
    [self.view bringSubviewToFront:_toastView];
    [self layoutModal];
    _backdrop.alpha = 0;
    _drawer.transform = CGAffineTransformMakeTranslation(_drawer.bounds.size.width, 0);
    [UIView animateWithDuration:.24 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
      self->_backdrop.alpha = 1; self->_drawer.transform = CGAffineTransformIdentity;
    } completion:nil];
  }
  [self.view setNeedsLayout];
  if(changed) { UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, _modalTitle); }
  return _modalFlow;
}

- (void)finishModal { [self layoutModal]; }

- (void)closeModal {
  if(!_modal) { return; }
  [self.view endEditing:YES];
  [self clearAlarmCode];
  _modal = nil; _modalDirty = NO;
  UIView *layer = _modalLayer;
  [UIView animateWithDuration:.2 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
    self->_backdrop.alpha = 0; self->_drawer.transform = CGAffineTransformMakeTranslation(self->_drawer.bounds.size.width, 0);
  } completion:^(BOOL finished) {
    if(!self->_modal) {
      layer.hidden = YES;
      self->_drawer.transform = CGAffineTransformIdentity;
      [self->_modalFlow removeFromSuperview];
      self->_modalFlow = [GRFlowView new];
      [self->_modalScroll addSubview:self->_modalFlow];
    }
  }];
  _alarmDots = nil;
}

- (void)rebuildModal {
  if(!_modal) { return; }
  CGPoint offset = _modalScroll.contentOffset;
  NSString *type = _modal[@"type"];
  if([type isEqualToString:@"category"]) { [self openCategory:_modal[@"id"] title:_modal[@"title"]]; }
  else if([type isEqualToString:@"room"]) { [self openRoom:_modal[@"id"]]; }
  else if([type isEqualToString:@"audit"]) { [self showAudit]; }
  else if([type isEqualToString:@"alarm"]) { [self closeModal]; return; }
  [self layoutModal];
  CGFloat maxY = MAX(0, _modalScroll.contentSize.height - _modalScroll.bounds.size.height + _modalScroll.contentInset.bottom);
  _modalScroll.contentOffset = CGPointMake(0, MIN(offset.y, maxY));
}

- (BOOL)isEditingModal {
  return _modalDirty || _alarmCode.length > 0;
}

- (BOOL)isEditingSettings { return _serverField.isFirstResponder || _tokenField.isFirstResponder || _lockField.isFirstResponder; }

- (void)refreshModal {
  if(!_modal || self.model.busy) { return; }
  NSString *type = _modal[@"type"];
  if([self isEditingModal] && self.model.connected) { return; }
  if([type isEqualToString:@"alarm"]) { if(!self.model.connected) { [self closeModal]; } return; }
  if([type isEqualToString:@"audit"]) { return; }
  [self rebuildModal];
}

- (void)openRoom:(NSString *)roomId {
  NSDictionary *room = [GRLogic roomWithId:roomId];
  if(!room) { return; }
  GRFlowView *parent = [self openModal:room[@"name"] eyebrow:@"ESTANÇA" type:@"room" modalId:roomId];
  NSArray *entities = [GRLogic entities:self.model.entities inRoom:roomId];
  NSArray *roomLights = [GRLogic lights:entities];
  if(roomLights.count > 1) { [self addLightGroup:roomLights to:parent title:@"TOTS ELS LLUMS DE L’ESTANÇA" top:4]; [parent addView:[GRRuleView ruleWithColor:[GRTheme current].line] top:22]; }
  if(entities.count) { [self addEntities:entities to:parent]; }
  else {
    [parent addView:GRWrappingLabel(@"Un espai per definir.", GRFont(24, UIFontWeightLight), [GRTheme current].text, 0) top:12];
    [parent addView:[self note:@"Encara no s’ha confirmat quins dispositius hi ha en aquesta estança. Els pots consultar al resum mentre completes la ubicació."] top:10];
    __weak GRMainViewController *weakSelf = self;
    [parent addView:[GRButton buttonWithTitle:@"Veure dispositius" style:GRButtonStyleAction handler:^(GRButton *b) { [weakSelf openCategory:@"all" title:@"Tots els dispositius"]; }] top:20 fill:NO];
  }
  [self finishModal];
}

- (void)openCategory:(NSString *)category title:(NSString *)title {
  GRFlowView *parent = [self openModal:title eyebrow:@"A CASA" type:@"category" modalId:category];
  NSArray *items = [category isEqualToString:@"all"] ? self.model.entities : [GRLogic entities:self.model.entities inCategory:category];
  if(!items.count) { [parent addView:[self note:@"Pendent de carregar l’inventari. Comprova la connexió amb el panell."] top:12]; }
  [self addEntities:items to:parent];
  [self finishModal];
}

- (UIView *)infoBox:(NSString *)text color:(UIColor *)color {
  GRTheme *t = [GRTheme current];
  GRFlowView *box = [GRFlowView new];
  box.insets = UIEdgeInsetsMake(16, 18, 16, 18);
  box.layer.cornerRadius = GRRadius(14); box.layer.borderWidth = 1; box.layer.borderColor = (color ?: t.edge).CGColor;
  [box addView:GRWrappingLabel(text, GRFont(14, UIFontWeightRegular), color ?: t.muted, 21)];
  return box;
}

// Lit dot: something switched on, playing or armed. Sensors only report, so they never light up.
static BOOL GRIsActiveState(NSString *domain, NSString *state) {
  if(!state) { return NO; }
  if([domain isEqualToString:@"alarm_control_panel"]) { return [state hasPrefix:@"armed"] || [state isEqualToString:@"triggered"]; }
  if([domain isEqualToString:@"media_player"]) { return [state isEqualToString:@"playing"]; }
  if([@[@"light", @"switch", @"input_boolean", @"fan"] containsObject:domain ?: @""]) { return [state isEqualToString:@"on"]; }
  return NO;
}

- (void)addEntities:(NSArray *)entities to:(GRFlowView *)parent {
  GRTheme *t = [GRTheme current];
  BOOL live = [self live];
  BOOL canCommand = self.model.connected && !self.model.preview && !self.model.busy;
  __weak GRMainViewController *weakSelf = self;
  for(NSDictionary *entity in entities) {
    NSArray *controls = GRArray(entity[@"controls"]) ?: @[];
    NSDictionary *turnOn = nil, *turnOff = nil;
    for(id control in controls) {
      NSString *action = GRStr(GRDict(control)[@"action"]);
      if([action isEqualToString:@"turn_on"] && [GRDict(control)[@"kind"] isEqual:@"button"]) { turnOn = control; }
      if([action isEqualToString:@"turn_off"] && [GRDict(control)[@"kind"] isEqual:@"button"]) { turnOff = control; }
    }
    BOOL ok = [entity[@"status"] isEqual:@"ok"] && live;
    BOOL on = ok && ![@[@"off", @"standby"] containsObject:GRStr(entity[@"state"]) ?: @"off"];
    BOOL active = ok && GRIsActiveState(GRStr(entity[@"domain"]), GRStr(entity[@"state"]));
    UISwitch *toggle = nil;
    if(turnOn && turnOff) {
      toggle = [UISwitch new];
      toggle.on = on;
      toggle.enabled = canCommand && ok && [turnOn[@"enabled"] isEqual:@YES] && [turnOff[@"enabled"] isEqual:@YES];
      GRStyleSwitch(toggle);
      toggle.accessibilityLabel = GRStr(entity[@"name"]) ?: entity[@"entity_id"];
      __weak UISwitch *weakToggle = toggle;
      GROnEvent(toggle, UIControlEventValueChanged, ^{
        UISwitch *s = weakToggle;
        GRStyleSwitch(s);
        [weakSelf sendAction:entity control:s.on ? turnOn : turnOff value:nil code:nil];
      });
    }

    GRFlowView *item = [GRFlowView new];
    item.insets = UIEdgeInsetsMake(18, 0, 18, 0);
    NSMutableString *title = [(GRStr(entity[@"name"]) ?: entity[@"entity_id"]) mutableCopy];
    if([entity[@"is_group"] isEqual:@YES]) { [title appendString:@" · grup"]; }
    UILabel *name = GRWrappingLabel(title, GRFont(20, UIFontWeightLight), active ? t.highlight : t.text, 0);
    NSString *stateText = [GRLogic stateTextForEntity:entity connected:self.model.connected demo:self.model.demo];
    NSString *attributes = [GRLogic attributeSummary:entity live:live];
    UILabel *state = GRWrappingLabel(attributes ? [NSString stringWithFormat:@"%@ · %@", stateText, attributes] : stateText,
                                     GRFont(13, UIFontWeightRegular), ok ? t.muted : t.issue, 18);
    UIView *dot = GRDot(active);
    GRBlockView *head = [GRBlockView new];
    for(UIView *view in @[dot, name, state]) { [head addSubview:view]; }
    if(toggle) { [head addSubview:toggle]; }
    CGSize switchSize = toggle ? [toggle sizeThatFits:CGSizeZero] : CGSizeZero;
    CGFloat (^textWidth)(CGFloat) = ^CGFloat(CGFloat width) { return width - 26 - (toggle ? switchSize.width + 16 : 0); };
    head.measure = ^CGFloat(CGFloat width) {
      CGFloat text = ceil([name sizeThatFits:CGSizeMake(textWidth(width), CGFLOAT_MAX)].height) + 4 + ceil([state sizeThatFits:CGSizeMake(textWidth(width), CGFLOAT_MAX)].height);
      return MAX(text, switchSize.height);
    };
    head.layout = ^(UIView *view) {
      CGFloat w = view.bounds.size.width, tw = textWidth(w);
      CGFloat nameHeight = ceil([name sizeThatFits:CGSizeMake(tw, CGFLOAT_MAX)].height);
      name.frame = CGRectMake(26, 0, tw, nameHeight);
      state.frame = CGRectMake(26, nameHeight + 4, tw, ceil([state sizeThatFits:CGSizeMake(tw, CGFLOAT_MAX)].height));
      dot.center = CGPointMake(5, nameHeight / 2);
      if(toggle) { toggle.frame = CGRectMake(w - switchSize.width, MAX(0, (nameHeight - switchSize.height) / 2), switchSize.width, switchSize.height); }
    };
    [item addView:head top:0];
    if(GRStr(entity[@"note"]).length) { [item addView:[self note:entity[@"note"]] top:6]; }
    if(GRStr(entity[@"inventory_area"]).length && !GRStr(entity[@"room"])) {
      [item addView:[self note:[NSString stringWithFormat:@"Àrea de l’inventari: %@ · ubicació física pendent", entity[@"inventory_area"]]] top:4];
    }

    GRFlowView *group = [GRFlowView new];
    group.insets = UIEdgeInsetsMake(0, 26, 0, 0);
    __block GRWrapView *buttons = nil;
    for(id control in controls) {
      // On and off live in the switch when both exist.
      if(!GRDict(control) || (toggle && (control == turnOn || control == turnOff))) { continue; }
      [self addControl:control entity:entity to:group buttons:&buttons];
    }
    if(toggle && !toggle.enabled && ok) {
      NSString *reason = GRStr(turnOn[@"reason"]) ?: GRStr(turnOff[@"reason"]);
      if(reason.length) { [group addView:[self note:reason] top:8]; }
    }
    if(!controls.count && ![entity[@"domain"] isEqual:@"sensor"] && ![entity[@"domain"] isEqual:@"binary_sensor"]) {
      [group addView:[self note:@"Controls pendents de verificar."] top:6];
    }
    UILabel *identifier = GRWrappingLabel(entity[@"entity_id"], GRFont(11, UIFontWeightRegular), t.faint, 0);
    identifier.lineBreakMode = NSLineBreakByCharWrapping;
    [group addView:identifier top:8];
    [item addView:group top:0];
    [parent addView:item top:0];
    [parent addView:[GRRuleView ruleWithColor:t.line] top:0];
  }
}

- (void)addControl:(NSDictionary *)control entity:(NSDictionary *)entity to:(GRFlowView *)group buttons:(GRWrapView *__strong *)buttons {
  GRTheme *t = [GRTheme current];
  BOOL enabled = [control[@"enabled"] isEqual:@YES] && self.model.connected && !self.model.preview && !self.model.busy;
  NSString *kind = GRStr(control[@"kind"]), *action = GRStr(control[@"action"]), *label = GRStr(control[@"label"]) ?: action;
  __weak GRMainViewController *weakSelf = self;
  void (^act)(id) = ^(id value) {
    if([kind isEqualToString:@"alarm"] || [action hasPrefix:@"alarm_"]) { [weakSelf alarmPrompt:entity control:control]; }
    else { [weakSelf sendAction:entity control:control value:value code:nil]; }
  };
  NSInteger speeds = [action isEqualToString:@"set_percentage"] ? [GRNum(control[@"speeds"]) integerValue] : 0;
  if(speeds >= 2 && speeds <= 10) {
    // Fans with a fixed number of speeds (CREATE: 1 to 6) get one button per speed instead of a percentage slider.
    *buttons = nil;
    NSNumber *current = GRNum(control[@"value"]);
    NSInteger speed = [GRStr(entity[@"state"]) isEqualToString:@"on"] && current ? [GRLogic fanSpeedForPercentage:current.doubleValue speeds:speeds] : 0;
    [group addView:GRLabel(speed ? [NSString stringWithFormat:@"Velocitat · %ld de %ld", (long)speed, (long)speeds] : @"Velocitat", GRFont(13, UIFontWeightRegular), t.muted) top:14];
    NSMutableArray *chips = [NSMutableArray array];
    GRBlockView *row = [GRBlockView new];
    for(NSInteger i = 1; i <= speeds; i++) {
      NSInteger percentage = [GRLogic percentageForFanSpeed:i speeds:speeds];
      GRButton *chip = [GRButton buttonWithTitle:[NSString stringWithFormat:@"%ld", (long)i] style:GRButtonStyleSegment handler:^(GRButton *b) { act(@(percentage)); }];
      chip.fontSize = 20;
      chip.selectedLook = i == speed;
      chip.enabled = enabled;
      chip.accessibilityLabel = [NSString stringWithFormat:@"Velocitat %ld", (long)i];
      [row addSubview:chip]; [chips addObject:chip];
    }
    row.measure = ^CGFloat(CGFloat width) { return 52; };
    row.layout = ^(UIView *view) {
      CGFloat w = floor((view.bounds.size.width - 8 * (chips.count - 1)) / chips.count);
      for(NSUInteger i = 0; i < chips.count; i++) { [chips[i] setFrame:CGRectMake(i * (w + 8), 0, w, 52)]; }
    };
    [group addView:row top:8];
  } else if([kind isEqualToString:@"range"]) {
    *buttons = nil;
    NSNumber *minimum = GRNum(control[@"min"]) ?: @0, *maximum = GRNum(control[@"max"]) ?: @100, *current = GRNum(control[@"value"]);
    double step = GRNum(control[@"step"]).doubleValue > 0 ? GRNum(control[@"step"]).doubleValue : 1;
    BOOL hasValue = current != nil;
    __block BOOL touched = NO;
    UILabel *caption = GRLabel(nil, GRFont(13, UIFontWeightRegular), t.muted);
    UISlider *slider = [UISlider new];
    slider.minimumValue = minimum.floatValue; slider.maximumValue = maximum.floatValue;
    slider.value = (current ?: minimum).floatValue;
    slider.enabled = enabled;
    slider.minimumTrackTintColor = t.accent; slider.maximumTrackTintColor = t.line;
    slider.accessibilityLabel = label;
    double (^snapped)(void) = ^double {
      double raw = minimum.doubleValue + round((slider.value - minimum.doubleValue) / step) * step;
      raw = MAX(minimum.doubleValue, MIN(maximum.doubleValue, raw));
      return round(raw * 1e9) / 1e9;
    };
    // Brightness (1-255) and volume (0-1) read better as percentages; the server still gets its own scale.
    NSString *(^shown)(double) = ^NSString *(double value) {
      if([action isEqualToString:@"brightness"]) { return [NSString stringWithFormat:@"%ld %%", GRRound(value / 255 * 100)]; }
      if([action isEqualToString:@"volume_set"]) { return [NSString stringWithFormat:@"%ld %%", GRRound(value * 100)]; }
      if([action isEqualToString:@"set_percentage"]) { return [NSString stringWithFormat:@"%@ %%", GRFormatNumber(value)]; }
      if([action isEqualToString:@"color_temp_kelvin"]) { return [NSString stringWithFormat:@"%@ K", GRFormatNumber(value)]; }
      if([action isEqualToString:@"set_temperature"]) { return [NSString stringWithFormat:@"%@ °", GRFormatNumber(value)]; }
      return GRFormatNumber(value);
    };
    NSString *title = [[label stringByReplacingOccurrencesOfString:@" (K)" withString:@""] stringByReplacingOccurrencesOfString:@" (%)" withString:@""];
    void (^updateLabel)(void) = ^{
      caption.text = [NSString stringWithFormat:@"%@ · %@", title, hasValue || touched ? shown(snapped()) : @"—"];
      slider.accessibilityValue = hasValue || touched ? shown(snapped()) : nil;
    };
    GROnEvent(slider, UIControlEventValueChanged, ^{ touched = YES; updateLabel(); weakSelf.modalDirtyFlag = YES; });
    // The value is sent when the finger lifts, so dragging does not flood the server.
    GROnEvent(slider, UIControlEventTouchUpInside | UIControlEventTouchUpOutside, ^{
      if(!touched) { return; }
      double value = snapped();
      act([action isEqualToString:@"set_percentage"] ? @(GRRound(value)) : (value == floor(value) ? @((long long)value) : @(value)));
    });
    updateLabel();
    [group addView:caption top:14];
    [group addView:slider top:4 height:36];
  } else if([kind isEqualToString:@"select"]) {
    *buttons = nil;
    NSArray *options = GRArray(control[@"options"]) ?: @[];
    __block NSString *selected = GRStr(control[@"value"]);
    if(![options containsObject:selected]) { selected = GRStr(options.firstObject); }
    GRButton *field = [GRButton buttonWithTitle:nil style:GRButtonStyleAction handler:nil];
    field.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [field setTitle:[NSString stringWithFormat:@"%@  ▾", selected ?: @""] forState:UIControlStateNormal];
    field.enabled = enabled;
    field.accessibilityLabel = label;
    field.handler = ^(GRButton *button) {
      UIAlertController *sheet = [UIAlertController alertControllerWithTitle:label message:nil preferredStyle:UIAlertControllerStyleActionSheet];
      for(NSString *option in options) {
        if(![option isKindOfClass:[NSString class]]) { continue; }
        [sheet addAction:[UIAlertAction actionWithTitle:option style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
          selected = option;
          weakSelf.modalDirtyFlag = YES;
          [button setTitle:[NSString stringWithFormat:@"%@  ▾", option] forState:UIControlStateNormal];
        }]];
      }
      [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel·la" style:UIAlertActionStyleCancel handler:nil]];
      sheet.popoverPresentationController.sourceView = button;
      sheet.popoverPresentationController.sourceRect = button.bounds;
      [weakSelf presentViewController:sheet animated:YES completion:nil];
    };
    GRButton *submit = [GRButton buttonWithTitle:@"Aplica el mode" style:GRButtonStyleAction handler:^(GRButton *b) { act(selected); }];
    submit.enabled = enabled;
    [group addView:GRLabel(label, GRFont(13, UIFontWeightRegular), t.muted) top:14];
    [group addView:field top:8];
    [group addView:submit top:8 fill:NO];
  } else {
    if(!*buttons) { *buttons = [GRWrapView new]; (*buttons).horizontalSpacing = 8; [group addView:*buttons top:12]; }
    GRButton *button = [GRButton buttonWithTitle:label style:GRButtonStyleAction handler:^(GRButton *b) { act(nil); }];
    button.enabled = enabled;
    [*buttons addSubview:button];
  }
  if(!enabled && GRStr(control[@"reason"]).length) {
    *buttons = nil;
    [group addView:[self note:control[@"reason"]] top:6];
  }
}

- (void)setModalDirtyFlag:(BOOL)dirty { _modalDirty = dirty; }
- (BOOL)modalDirtyFlag { return _modalDirty; }

- (void)clearAlarmCode {
  [_alarmCode setString:@""];
  [self updateAlarmDots];
}

- (void)updateAlarmDots {
  if(!_alarmDots) { return; }
  NSMutableArray *dots = [NSMutableArray array];
  for(NSUInteger i = 0; i < _alarmCode.length; i++) { [dots addObject:@"●"]; }
  _alarmDots.text = dots.count ? [dots componentsJoinedByString:@" "] : @"– – – –";
  _alarmDots.textColor = dots.count ? [GRTheme current].highlight : [GRTheme current].faint;
  _alarmDots.accessibilityLabel = [NSString stringWithFormat:@"PIN de l’alarma: %lu dígits", (unsigned long)_alarmCode.length];
}

// Numeric pad drawn by the app: the alarm code never opens the iOS keyboard.
- (UIView *)alarmPinPad {
  __weak GRMainViewController *weakSelf = self;
  NSMutableArray *keys = [NSMutableArray array];
  for(NSString *key in @[@"1", @"2", @"3", @"4", @"5", @"6", @"7", @"8", @"9", @"C", @"0", @"⌫"]) {
    GRButton *button = [GRButton buttonWithTitle:key style:GRButtonStyleOutline handler:^(GRButton *b) {
      GRMainViewController *strongSelf = weakSelf;
      if(!strongSelf) { return; }
      if([key isEqualToString:@"C"]) { [strongSelf->_alarmCode setString:@""]; }
      else if([key isEqualToString:@"⌫"]) { if(strongSelf->_alarmCode.length) { [strongSelf->_alarmCode deleteCharactersInRange:NSMakeRange(strongSelf->_alarmCode.length - 1, 1)]; } }
      else if(strongSelf->_alarmCode.length < 12) { [strongSelf->_alarmCode appendString:key]; }
      [strongSelf updateAlarmDots];
    }];
    button.fontSize = [key isEqualToString:@"C"] ? 20 : 28;
    button.accessibilityLabel = [key isEqualToString:@"C"] ? @"Esborra tot" : ([key isEqualToString:@"⌫"] ? @"Esborra l’últim dígit" : key);
    [keys addObject:button];
  }
  GRBlockView *pad = [GRBlockView new];
  for(UIView *key in keys) { [pad addSubview:key]; }
  pad.measure = ^CGFloat(CGFloat width) { return 4 * 68 + 3 * 10; };
  pad.layout = ^(UIView *view) {
    CGFloat total = MIN(view.bounds.size.width, 360), x0 = (view.bounds.size.width - total) / 2;
    CGFloat w = floor((total - 20) / 3);
    for(NSUInteger i = 0; i < keys.count; i++) { [keys[i] setFrame:CGRectMake(x0 + (i % 3) * (w + 10), (i / 3) * 78, w, 68)]; }
  };
  return pad;
}

- (void)alarmPrompt:(NSDictionary *)entity control:(NSDictionary *)control {
  GRTheme *t = [GRTheme current];
  GRFlowView *parent = [self openModal:GRStr(control[@"label"]) ?: @"Alarma" eyebrow:@"SEGURETAT" type:@"alarm" modalId:entity[@"entity_id"]];
  [parent addView:[self infoBox:[NSString stringWithFormat:@"Estat actual: %@. Confirma l’ordre abans d’enviar-la.", [GRLogic stateTextForEntity:entity connected:self.model.connected demo:self.model.demo]] color:nil] top:8];
  BOOL needsCode = [control[@"requires_code"] isEqual:@YES];
  if(needsCode) {
    [parent addView:GRLabel(@"PIN de l’alarma", GRFont(13, UIFontWeightRegular), t.muted) top:18];
    _alarmDots = GRLabel(nil, GRDigits(30, UIFontWeightLight), t.highlight);
    _alarmDots.textAlignment = NSTextAlignmentCenter;
    _alarmDots.isAccessibilityElement = YES;
    [self updateAlarmDots];
    [parent addView:_alarmDots top:6 height:44];
    [parent addView:[self alarmPinPad] top:10];
    [parent addView:[self note:@"El PIN només s’envia amb aquesta ordre i s’esborra immediatament."] top:12];
  }
  __weak GRMainViewController *weakSelf = self;
  GRButton *submit = [GRButton buttonWithTitle:GRStr(control[@"label"]) style:GRButtonStylePrimary handler:^(GRButton *b) {
    GRMainViewController *strongSelf = weakSelf;
    if(!strongSelf) { return; }
    NSString *code = needsCode ? [strongSelf->_alarmCode copy] : nil;
    [strongSelf clearAlarmCode];
    if(needsCode && !code.length) { [strongSelf toast:@"Escriu el PIN de l’alarma amb el teclat."]; return; }
    [strongSelf sendAction:entity control:control value:nil code:code];
  }];
  [parent addView:submit top:22];
  [self finishModal];
}

- (void)sendAction:(NSDictionary *)entity control:(NSDictionary *)control value:(id)value code:(NSString *)code {
  if(self.model.busy || !self.model.connected || self.model.preview || ![control[@"enabled"] isEqual:@YES]) {
    [self toast:@"Aquest control encara no està disponible."];
    [self rebuildModal];
    return;
  }
  [self.view endEditing:YES];
  [self setControlsEnabled:NO in:_modalFlow];
  _modalDirty = NO;
  __weak GRMainViewController *weakSelf = self;
  [self.model sendAction:entity control:control value:value code:code completion:^(NSString *error) {
    GRMainViewController *strongSelf = weakSelf;
    if(strongSelf && [strongSelf->_modal[@"type"] isEqualToString:@"alarm"]) { [strongSelf closeModal]; }
  }];
}

- (void)setControlsEnabled:(BOOL)enabled in:(UIView *)view {
  for(UIView *child in view.subviews) {
    if([child isKindOfClass:[UIControl class]]) { ((UIControl *)child).enabled = enabled; }
    [self setControlsEnabled:enabled in:child];
  }
}

#pragma mark Settings

- (UITextField *)textField:(NSString *)text placeholder:(NSString *)placeholder secure:(BOOL)secure {
  GRTheme *t = [GRTheme current];
  UITextField *field = [UITextField new];
  field.text = text;
  if(placeholder) { field.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeholder attributes:@{NSForegroundColorAttributeName: t.muted}]; }
  field.secureTextEntry = secure;
  field.font = GRFont(17, UIFontWeightRegular);
  field.textColor = t.text;
  field.tintColor = t.accent;
  field.backgroundColor = t.field;
  field.layer.cornerRadius = GRRadius(12); field.layer.borderWidth = 1; field.layer.borderColor = t.edge.CGColor;
  field.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 14, 10)]; field.leftViewMode = UITextFieldViewModeAlways;
  field.autocapitalizationType = UITextAutocapitalizationTypeNone;
  field.autocorrectionType = UITextAutocorrectionTypeNo;
  field.spellCheckingType = UITextSpellCheckingTypeNo;
  field.clearButtonMode = UITextFieldViewModeWhileEditing;
  field.keyboardAppearance = t.night ? UIKeyboardAppearanceDark : UIKeyboardAppearanceDefault;
  field.delegate = self;
  return field;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
  if(textField == _serverField) { [_tokenField becomeFirstResponder]; }
  else if(textField == _lockField) { [self saveScreenLock]; }
  else { [textField resignFirstResponder]; }
  return NO;
}

- (GRFlowView *)settingsSection:(NSString *)title { return [self card:title.uppercaseString note:@""]; }

- (UIView *)switchRow:(NSString *)text on:(BOOL)on changed:(void (^)(BOOL on))changed {
  UISwitch *toggle = [UISwitch new];
  toggle.on = on;
  GRStyleSwitch(toggle);
  __weak UISwitch *weakToggle = toggle;
  GROnEvent(toggle, UIControlEventValueChanged, ^{ GRStyleSwitch(weakToggle); changed(weakToggle.on); });
  toggle.accessibilityLabel = text;
  UILabel *label = GRWrappingLabel(text, GRFont(18, UIFontWeightLight), [GRTheme current].text, 0);
  label.isAccessibilityElement = NO;
  GRBlockView *row = [GRBlockView new];
  [row addSubview:toggle]; [row addSubview:label];
  CGSize size = [toggle sizeThatFits:CGSizeZero];
  row.measure = ^CGFloat(CGFloat width) { return 51; };
  row.layout = ^(UIView *view) {
    CGFloat w = view.bounds.size.width;
    toggle.frame = CGRectMake(w - size.width, (51 - size.height) / 2, size.width, size.height);
    label.frame = CGRectMake(0, 0, w - size.width - 16, 51);
  };
  return row;
}

- (GRFlowView *)connectionSection {
  GRTheme *t = [GRTheme current];
  GRPreferences *preferences = [GRPreferences shared];
  __weak GRMainViewController *weakSelf = self;
  GRFlowView *section = [self settingsSection:@"Connexió"];
  NSString *status = self.model.demo ? @"Previsualització amb llums ficticis. No hi ha connexió amb Home Assistant ni controls actius."
    : (self.model.preview ? @"Previsualització local. No hi ha dades de Home Assistant ni controls actius."
    : (self.model.connected ? @"Home Assistant connectat." : @"Pendent de connectar amb Home Assistant."));
  NSString *live = self.model.liveUpdates ? @"Canvis d’estat en directe actius." : (self.model.connected ? @"Connexió d’esdeveniments reconnectant; comprovació de seguretat cada 30 segons." : @"Esperant la connexió d’esdeveniments.");
  NSURL *base = self.model.client.baseURL;
  NSString *transport = !base ? @"Sense servidor configurat." : ([base.scheme isEqualToString:@"https"] ? @"Transport HTTPS." : @"Transport HTTP local, sense xifrat. El PIN viatja sense protegir dins la xarxa.");
  BOOL first = YES;
  for(NSString *line in @[status, live, transport]) { [section addView:[self note:line] top:first ? 12 : 2]; first = NO; }
  if(self.model.error.length && !self.model.connected) { [section addView:GRWrappingLabel(self.model.error, GRFont(13, UIFontWeightRegular), t.issue, 19) top:6]; }

  [section addView:GRLabel(@"Adreça del panell", GRFont(13, UIFontWeightRegular), t.text) top:18];
  _serverField = [self textField:preferences.serverURL placeholder:@"http://192.168.1.10:8099" secure:NO];
  _serverField.keyboardType = UIKeyboardTypeURL;
  _serverField.returnKeyType = UIReturnKeyNext;
  _serverField.accessibilityLabel = @"Adreça del panell";
  [section addView:_serverField top:8 height:50];
  [section addView:GRLabel(@"PIN del panell (el mateix que panel_pin)", GRFont(13, UIFontWeightRegular), t.text) top:14];
  _tokenField = [self textField:preferences.token placeholder:@"6 a 8 dígits" secure:YES];
  _tokenField.keyboardType = UIKeyboardTypeNumberPad;
  _tokenField.returnKeyType = UIReturnKeyDone;
  _tokenField.accessibilityLabel = @"PIN del panell";
  [section addView:_tokenField top:8 height:50];
  NSString *storage = !preferences.token.length ? @"El PIN es desa al clauer de l’iPad perquè l’app s’obri sense demanar-lo."
    : (preferences.tokenInKeychain ? @"PIN desat al clauer de l’iPad." : @"El clauer no està disponible amb aquesta signatura; el PIN es desa dins l’espai privat de l’app.");
  [section addView:[self note:storage] top:8];
  [section addView:[GRButton buttonWithTitle:@"Desa i connecta" style:GRButtonStylePrimary handler:^(GRButton *b) { [weakSelf saveConnection]; }] top:16];
  GRWrapView *buttons = [GRWrapView new];
  buttons.horizontalSpacing = 8;
  [buttons addSubview:[GRButton buttonWithTitle:@"Comprova la connexió" style:GRButtonStyleAction handler:^(GRButton *b) { [weakSelf checkConnection]; }]];
  [buttons addSubview:[GRButton buttonWithTitle:@"Informe de verificació" style:GRButtonStyleAction handler:^(GRButton *b) { [weakSelf showAudit]; }]];
  [section addView:buttons top:10];

  NSString *seen = self.model.client.untrustedFingerprint;
  if(seen.length && ![seen isEqualToString:preferences.pinnedFingerprint]) {
    [section addView:GRLabel(@"Certificat HTTPS no reconegut", GRFont(16, UIFontWeightRegular), t.issue) top:20];
    UILabel *print = GRWrappingLabel([@"Empremta SHA-256: " stringByAppendingString:seen], [UIFont fontWithName:@"Menlo" size:11] ?: GRFont(11, UIFontWeightRegular), t.text, 0);
    print.lineBreakMode = NSLineBreakByCharWrapping;
    [section addView:print top:6];
    [section addView:[self note:@"Compara-la amb l’empremta del certificat instal·lat a Home Assistant (/ssl) abans de confiar-hi. Si no coincideix, no continuïs."] top:6];
    [section addView:[GRButton buttonWithTitle:@"Confia en aquest certificat" style:GRButtonStyleAction handler:^(GRButton *b) {
      [GRPreferences shared].pinnedFingerprint = seen; [weakSelf connectFromPreferences];
    }] top:10 fill:NO];
  } else if(preferences.pinnedFingerprint.length) {
    UILabel *print = GRWrappingLabel([@"Certificat fixat · SHA-256: " stringByAppendingString:preferences.pinnedFingerprint], [UIFont fontWithName:@"Menlo" size:11] ?: GRFont(11, UIFontWeightRegular), t.muted, 0);
    print.lineBreakMode = NSLineBreakByCharWrapping;
    [section addView:print top:16];
    [section addView:[GRButton buttonWithTitle:@"Oblida el certificat fixat" style:GRButtonStyleAction handler:^(GRButton *b) {
      [GRPreferences shared].pinnedFingerprint = nil; [weakSelf connectFromPreferences];
    }] top:10 fill:NO];
  }
  return section;
}

- (void)openSettings { [self navigate:@"settings"]; }

// Equal-width choice buttons in rows; choices are @[value, title].
- (GRBlockView *)choices:(NSArray<NSArray *> *)choices selected:(id)selected columns:(NSUInteger)columns action:(void (^)(id value))action {
  NSMutableArray *buttons = [NSMutableArray array];
  GRBlockView *grid = [GRBlockView new];
  for(NSArray *choice in choices) {
    id value = choice[0];
    GRButton *button = [GRButton buttonWithTitle:choice[1] style:GRButtonStyleSegment handler:^(GRButton *b) { action(value); }];
    button.selectedLook = [value isEqual:selected];
    button.accessibilityTraits = UIAccessibilityTraitButton | (button.selectedLook ? UIAccessibilityTraitSelected : 0);
    [grid addSubview:button]; [buttons addObject:button];
  }
  NSUInteger rows = (buttons.count + columns - 1) / columns;
  grid.measure = ^CGFloat(CGFloat width) { return rows * 46 + (rows - 1) * 8; };
  grid.layout = ^(UIView *view) {
    CGFloat w = (view.bounds.size.width - 8 * (columns - 1)) / columns;
    for(NSUInteger i = 0; i < buttons.count; i++) { [buttons[i] setFrame:CGRectMake((i % columns) * (w + 8), (i / columns) * 54, w, 46)]; }
  };
  return grid;
}

- (UILabel *)pageTitle:(NSString *)text {
  GRTheme *t = [GRTheme current];
  UILabel *title = GRLabel(nil, GRFont(40, UIFontWeightThin), t.highlight);
  title.attributedText = GRKerned(text, title.font, t.highlight, -1);
  title.accessibilityTraits = UIAccessibilityTraitHeader;
  GRGlow(title.layer, t.highlight, 12);
  return title;
}

- (void)renderSettings {
  GRTheme *t = [GRTheme current];
  GRPreferences *preferences = [GRPreferences shared];
  __weak GRMainViewController *weakSelf = self;
  [_viewFlow addView:[self pageTitle:@"Ajustos"] top:0 height:52];
  BOOL needsSetup = _configurationMessage.length && !self.model.authenticated && !self.model.preview;
  if(needsSetup) { [_viewFlow addView:[self infoBox:_configurationMessage color:t.issue] top:12]; }

  GRFlowView *look = [self settingsSection:@"Aparença"];
  [look addView:GRLabel(@"Estil", GRFont(13, UIFontWeightRegular), t.text) top:16];
  [look addView:[self choices:@[@[@"warm", @"Nit càlida"], @[@"jarvis", @"Jarvis"]] selected:preferences.style columns:2 action:^(id value) {
    [weakSelf setStyleChoice:value]; [weakSelf renderView];
  }] top:8];
  [look addView:GRLabel(@"Tema", GRFont(13, UIFontWeightRegular), t.text) top:16];
  [look addView:[self choices:@[@[@"auto", @"Automàtic"], @[@"day", @"Dia"], @[@"night", @"Nit"]] selected:preferences.theme columns:3 action:^(id value) {
    [weakSelf setThemeChoice:value]; [weakSelf renderView];
  }] top:8];
  [look addView:[self note:@"Nit càlida: negre i ambre. Jarvis: una pantalla de dades blau cian, com la d’Iron Man. Els dos estils tenen versió de dia i de nit; en automàtic, és de dia de 7 a 20 h."] top:12];

  NSInteger lock = preferences.screenLock;
  GRFlowView *screen = [self settingsSection:@"Pantalla"];
  NSArray *presets = @[@[@0, @"Com iOS"], @[@15, @"15 s"], @[@30, @"30 s"], @[@60, @"1 min"], @[@300, @"5 min"], @[@900, @"15 min"], @[@3600, @"1 h"], @[@-1, @"Mai"]];
  [screen addView:GRLabel(@"Temps sense tocar-la abans d’apagar-se", GRFont(13, UIFontWeightRegular), t.text) top:16];
  [screen addView:[self choices:presets selected:@(lock) columns:4 action:^(id value) {
    [GRPreferences shared].screenLock = [value integerValue]; [GRScreenLock restart]; [weakSelf renderView];
  }] top:8];
  [screen addView:GRLabel(@"O escriu els segons que vulguis (de 5 a 86 400)", GRFont(13, UIFontWeightRegular), t.text) top:16];
  _lockField = [self textField:lock > 0 ? [NSString stringWithFormat:@"%ld", (long)lock] : nil placeholder:@"Segons" secure:NO];
  _lockField.keyboardType = UIKeyboardTypeNumberPad;
  _lockField.returnKeyType = UIReturnKeyDone;
  _lockField.accessibilityLabel = @"Segons sense tocar la pantalla";
  UITextField *lockField = _lockField;
  GRButton *saveLock = [GRButton buttonWithTitle:@"Desa" style:GRButtonStyleAction handler:^(GRButton *b) { [weakSelf saveScreenLock]; }];
  GRBlockView *lockRow = [GRBlockView new];
  [lockRow addSubview:lockField]; [lockRow addSubview:saveLock];
  lockRow.measure = ^CGFloat(CGFloat width) { return 50; };
  lockRow.layout = ^(UIView *view) {
    CGFloat w = view.bounds.size.width;
    lockField.frame = CGRectMake(0, 0, w - 110, 50); saveLock.frame = CGRectMake(w - 100, 0, 100, 50);
  };
  [screen addView:lockRow top:8];
  NSString *now = lock == 0 ? @"Ara: la pantalla s’apaga amb el bloqueig automàtic d’iOS." : (lock < 0 ? @"Ara: la pantalla no s’apaga mai."
    : [NSString stringWithFormat:@"Ara: la pantalla s’apaga després de %@ sense tocar-la.", GRDuration(lock)]);
  [screen addView:GRWrappingLabel(now, GRFont(15, UIFontWeightRegular), t.highlight, 21) top:12];
  [screen addView:[self switchRow:@"Apaga-la del tot en passar el temps (negre i brillantor mínima)" on:preferences.screenDim changed:^(BOOL on) {
    [GRPreferences shared].screenDim = on; [GRScreenLock restart];
  }] top:10];
  [screen addView:[self note:@"Una app no pot bloquejar l’iPad: quan passa el temps, l’app apaga la pantalla (tota negra i amb la brillantor al mínim) i després el bloqueig automàtic d’iOS (Configuració → Pantalla i brillantor) la bloqueja. Tocar la pantalla negra només l’encén; no prem cap botó. Si desactives l’opció, només es deixa fer a iOS."] top:10];

  GRFlowView *connection = [self connectionSection];
  NSArray *left = needsSetup ? @[connection] : @[look, screen];
  NSArray *right = needsSetup ? @[look, screen] : @[connection];
  if([self landscape]) { [_viewFlow addView:[self columns:@[left, right] gap:16] top:16]; }
  else { for(UIView *card in [left arrayByAddingObjectsFromArray:right]) { [_viewFlow addView:card top:16]; } }
  [_viewFlow addView:[self note:[NSString stringWithFormat:@"Glass Rooms %@ · App nativa per a iPad · Actualitzacions en directe de Home Assistant.", GRVersion]] top:18];
}

- (void)saveScreenLock {
  NSString *text = [_lockField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"";
  NSRegularExpression *digits = [NSRegularExpression regularExpressionWithPattern:@"^[0-9]{1,5}$" options:0 error:NULL];
  NSInteger seconds = [digits firstMatchInString:text options:0 range:NSMakeRange(0, text.length)] ? text.integerValue : 0;
  if(seconds < 5 || seconds > 86400) { [self toast:@"Escriu un nombre de segons entre 5 i 86 400 (24 hores)."]; return; }
  [GRPreferences shared].screenLock = seconds;
  [GRScreenLock restart];
  [self.view endEditing:YES];
  [self toast:[NSString stringWithFormat:@"La pantalla s’apagarà després de %@ sense tocar-la.", GRDuration(seconds)]];
  [self renderView];
}

- (void)saveConnection {
  NSString *problem = nil;
  NSURL *base = [GRAPIClient normalizedBaseURL:_serverField.text ?: @"" error:&problem];
  if(!base) { [self toast:problem]; return; }
  NSString *token = [_tokenField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  // The panel PIN (6-8 digits); a long app_token from earlier versions is still accepted.
  NSRegularExpression *pattern = [NSRegularExpression regularExpressionWithPattern:@"^([0-9]{6,8}|[A-Za-z0-9_-]{32,128})$" options:0 error:NULL];
  if(![pattern firstMatchInString:token options:0 range:NSMakeRange(0, token.length)]) {
    [self toast:@"El PIN ha de tenir de 6 a 8 dígits, el mateix que panel_pin."];
    return;
  }
  GRPreferences *preferences = [GRPreferences shared];
  if(![preferences.serverURL isEqualToString:base.absoluteString]) { preferences.pinnedFingerprint = nil; }
  preferences.serverURL = base.absoluteString;
  preferences.token = token;
  [self.view endEditing:YES];
  _configurationMessage = nil;
  [self connectFromPreferences];
  [self toast:@"Connexió desada. Comprovant el panell…"];
}

- (void)checkConnection {
  if(!self.model.client) { [self toast:@"Configura primer l’adreça del panell."]; return; }
  if(!self.model.authenticated && !self.model.preview) { [self connectFromPreferences]; return; }
  [self.model refresh:YES];
}

- (void)showAudit {
  GRTheme *t = [GRTheme current];
  BOOL reopening = [_modal[@"type"] isEqualToString:@"audit"];
  GRFlowView *parent = [self openModal:@"Verificació" eyebrow:@"CONNEXIÓ I CAPACITATS" type:@"audit" modalId:@"audit"];
  [parent addView:[self note:@"Informe de lectura per completar la configuració. No inclou credencials."] top:4];
  UITextView *output = [UITextView new];
  output.editable = NO;
  output.font = [UIFont fontWithName:@"Menlo" size:11] ?: GRFont(11, UIFontWeightRegular);
  output.textColor = t.text; output.backgroundColor = t.background;
  output.layer.cornerRadius = GRRadius(12); output.layer.borderWidth = 1; output.layer.borderColor = t.edge.CGColor;
  output.textContainerInset = UIEdgeInsetsMake(12, 8, 12, 8);
  output.text = reopening && _auditText ? _auditText : @"Carregant…";
  [parent addView:output top:14 height:420];
  [self finishModal];
  if(reopening && _auditText) { return; }
  if(!self.model.client) { output.text = @"Configura primer l’adreça del panell."; return; }
  __weak GRMainViewController *weakSelf = self;
  __weak UITextView *weakOutput = output;
  [self.model loadAudit:^(NSString *text) {
    GRMainViewController *strongSelf = weakSelf;
    if(strongSelf) { strongSelf->_auditText = text; }
    weakOutput.text = text;
  }];
}

#pragma mark Keyboard

- (void)keyboardWillChange:(NSNotification *)notification {
  CGRect frame = [self.view convertRect:[notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue] fromView:nil];
  _keyboardHeight = MAX(0, self.view.bounds.size.height - frame.origin.y);
  [self layoutModal];
  [self layoutToast];
  UIView *field = _serverField.isFirstResponder ? _serverField : (_tokenField.isFirstResponder ? _tokenField : (_lockField.isFirstResponder ? _lockField : nil));
  [self.view setNeedsLayout]; [self.view layoutIfNeeded];
  if(field && [field isDescendantOfView:_scroll]) { [_scroll scrollRectToVisible:[_scroll convertRect:CGRectInset(field.bounds, 0, -20) fromView:field] animated:YES]; }
}

- (void)keyboardWillHide:(NSNotification *)notification {
  _keyboardHeight = 0;
  [self layoutModal];
  [self layoutToast];
  [self.view setNeedsLayout];
}

@end
