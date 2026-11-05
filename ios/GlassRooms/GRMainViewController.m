#import "GRMainViewController.h"
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
    self.layer.cornerRadius = 18; self.layer.borderWidth = 1;
    self.isAccessibilityElement = YES; self.accessibilityLabel = accessibility; self.accessibilityTraits = UIAccessibilityTraitButton;
  }
  return self;
}
- (void)applyTheme {
  GRTheme *t = [GRTheme current];
  self.icon.tintColor = self.active ? t.accent : t.muted;
  self.layer.borderColor = (self.active ? t.accent : t.edge).CGColor;
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
  UILabel *_clock, *_date, *_status, *_sparkCaption;
  NSArray<UILabel *> *_statLabels, *_statValues;
  GRSparklineView *_spark;
  NSMutableArray<GRNavButton *> *_navButtons;
  GRNavButton *_settingsButton;
  // Content column
  UIScrollView *_scroll;
  GRFlowView *_viewFlow;
  NSString *_currentView;
  // Climate page: chosen sensor and the inspected point (-1 = latest).
  NSString *_climateSensor;
  NSInteger _climateIndex;
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
  UITextField *_serverField, *_tokenField, *_alarmField;
  BOOL _night;
}

- (instancetype)init {
  if((self = [super init])) {
    _model = [GRPanelModel new];
    _model.delegate = self;
    // The clock column always shows the temperature trend, so history is loaded on every view.
    _model.climateVisible = YES;
    _currentView = @"rooms";
    _climateIndex = -1;
    _navButtons = [NSMutableArray array];
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
  _status = GRLabel(@"Esperant dades de casa", GRFont(12, UIFontWeightRegular), t.muted);
  for(UIView *view in @[_clock, _date, _spark, _sparkCaption, _status]) { [self.view addSubview:view]; }

  NSArray *items = @[@[@"home", @"rooms", @"Estances"], @[@"overview", @"overview", @"Resum de casa"],
                     @[@"thermometer", @"climate", @"Temperatura i humitat"], @[@"shield", @"security", @"Seguretat"]];
  for(NSArray *item in items) {
    GRNavButton *button = [[GRNavButton alloc] initWithIcon:item[0] destination:item[1] accessibility:item[2]];
    [button addTarget:self action:@selector(navTapped:) forControlEvents:UIControlEventTouchUpInside];
    [_navButtons addObject:button]; [self.view addSubview:button];
  }
  _settingsButton = [[GRNavButton alloc] initWithIcon:@"settings" destination:@"settings" accessibility:@"Ajustos"];
  [_settingsButton addTarget:self action:@selector(openSettings) forControlEvents:UIControlEventTouchUpInside];
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
  _toastView.layer.cornerRadius = 16; _toastView.layer.borderWidth = 1;
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
  _closeButton.layer.cornerRadius = 22; _closeButton.layer.borderWidth = 1;
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
  _date.frame = CGRectMake(side + 2, y, 420, 26);
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
    _spark.frame = CGRectMake(side + 2, statsBottom + 34, leftWidth - 2, 90);
    _sparkCaption.frame = CGRectMake(side + 2, CGRectGetMaxY(_spark.frame) + 6, leftWidth, 16);
    _status.textAlignment = NSTextAlignmentLeft;
    _status.frame = CGRectMake(side + 2, navY - 18 - 16, leftWidth, 16);
    _scroll.frame = CGRectMake(size.width - side - rightWidth, top, rightWidth, size.height - top);
    _scroll.contentInset = UIEdgeInsetsMake(clockTop - top + 4, 0, 32, 0);
  } else {
    CGFloat sparkWidth = MIN(250, size.width - 2 * side - 330);
    _spark.frame = CGRectMake(size.width - side - sparkWidth, clockTop + 16, sparkWidth, 76);
    _sparkCaption.frame = CGRectMake(size.width - side - sparkWidth, CGRectGetMaxY(_spark.frame) + 6, sparkWidth, 16);
    _status.textAlignment = NSTextAlignmentCenter;
    _status.frame = CGRectMake(side, navY - 14 - 16, size.width - 2 * side, 16);
    CGFloat scrollTop = statsBottom + 14;
    _scroll.frame = CGRectMake(side, scrollTop, size.width - 2 * side, CGRectGetMinY(_status.frame) - 6 - scrollTop);
    _scroll.contentInset = UIEdgeInsetsMake(14, 0, 14, 0);
  }

  // The climate page takes the whole screen above the navigation: the clock column steps aside.
  BOOL full = [_currentView isEqualToString:@"climate"];
  NSMutableArray *column = [@[_clock, _date, _spark, _sparkCaption] mutableCopy];
  [column addObjectsFromArray:_statLabels]; [column addObjectsFromArray:_statValues];
  for(UIView *view in column) { view.alpha = full ? 0 : 1; }
  _scroll.scrollEnabled = !full;
  if(full) {
    _scroll.frame = CGRectMake(side, top + 26, size.width - 2 * side, navY - 24 - (top + 26));
    _scroll.contentInset = UIEdgeInsetsZero;
    _scroll.contentOffset = CGPointZero;
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
  [GRTheme setNight:_night];
}

- (void)applyThemeColors {
  GRTheme *t = [GRTheme current];
  self.view.backgroundColor = t.background;
  _clock.textColor = t.highlight; _date.textColor = t.muted;
  _sparkCaption.textColor = t.muted; _status.textColor = t.muted;
  [_spark setNeedsDisplay];
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
  [self updateThemeFromPreferences];
  if(wasNight == _night) { return; }
  [self applyThemeColors];
  [self renderView];
  [self rebuildModal];
}

- (void)setThemeChoice:(NSString *)theme {
  [GRPreferences shared].theme = theme;
  [self applyTheme];
}

- (void)clockTick {
  NSDate *now = [NSDate date];
  _clock.attributedText = GRKerned([GRLogic clockText:now], _clock.font, [GRTheme current].highlight, [self landscape] ? -6 : -5);
  _clock.accessibilityLabel = [@"Són les " stringByAppendingString:[GRLogic clockText:now]];
  _date.text = [GRLogic dateText:now].lowercaseString;
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
  [_alarmField setText:@""];
  [_clockTimer cancel];
}

- (void)appWillEnterForeground {
  [self clockTick];
  [self.model enterForeground];
}

#pragma mark Model delegate

- (void)panelModel:(GRPanelModel *)model didUpdateWithForce:(BOOL)force changed:(BOOL)changed {
  if(changed) { [self renderView]; [self refreshModal]; }
  else { [self renderStatus]; }
}

- (void)panelModel:(GRPanelModel *)model showToast:(NSString *)message {
  if(message.length) { [self toast:message]; } else { [self hideToast]; }
}

- (void)panelModel:(GRPanelModel *)model needsConfiguration:(NSString *)reason {
  _configurationMessage = reason;
  if(![_modal[@"type"] isEqualToString:@"settings"]) { [self closeModal]; [self openSettings]; }
  else { [self rebuildModal]; }
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

  NSArray *values = nil; NSString *name = nil;
  for(NSDictionary *sensor in [GRLogic entities:entities inCategory:@"climate"]) {
    if(![GRStr(GRDict(sensor[@"attributes"])[@"device_class"]) isEqualToString:@"temperature"]) { continue; }
    NSArray *points = GRArray(self.model.historySeries[sensor[@"entity_id"]]);
    if(points.count < 2) { continue; }
    NSMutableArray *numbers = [NSMutableArray array];
    for(NSDictionary *point in points) { if(GRNum(GRDict(point)[@"value"])) { [numbers addObject:point[@"value"]]; } }
    if(numbers.count >= 2) { values = numbers; name = GRStr(sensor[@"name"]); break; }
  }
  NSInteger hours = self.model.historyHours;
  NSString *period = hours == 6 ? @"6 h" : (hours == 168 ? @"7 dies" : (hours == 720 ? @"mes" : @"24 h"));
  _spark.values = values ?: @[];
  _spark.hidden = !values;
  _spark.accessibilityLabel = values ? [NSString stringWithFormat:@"Evolució de la temperatura de %@", name ?: @"casa"] : nil;
  _sparkCaption.text = values ? [NSString stringWithFormat:@"%@ · últim%@ %@", name ?: @"Temperatura", hours == 720 ? @"" : @"es", period]
                              : (self.model.historyLoading ? @"Carregant l’historial…" : @"");
  [self renderStatus];
  [self.view setNeedsLayout];
}

#pragma mark Content helpers

- (UILabel *)sectionLabel:(NSString *)text {
  UILabel *label = GRLabel(nil, GRFont(13, UIFontWeightMedium), [GRTheme current].muted);
  label.attributedText = GRKerned(text, GRFont(13, UIFontWeightMedium), [GRTheme current].muted, 2);
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
  if([destination isEqualToString:@"security"]) { [self openCategory:@"security" title:@"Seguretat"]; return; }
  if([destination isEqualToString:@"scenes"]) { [self openCategory:@"scenes" title:@"Escenes i ambient"]; return; }
  _currentView = destination;
  [self renderView];
  [_scroll setContentOffset:CGPointMake(0, -_scroll.contentInset.top) animated:NO];
}

- (void)renderView {
  if(!_viewFlow) { return; }
  [_viewFlow removeFromSuperview];
  _viewFlow = [GRFlowView new];
  [_scroll addSubview:_viewFlow];
  for(GRNavButton *button in _navButtons) { button.active = [button.destination isEqualToString:_currentView]; }
  if([_currentView isEqualToString:@"climate"]) { [self renderClimate]; }
  else if([_currentView isEqualToString:@"overview"]) { [self renderOverview]; }
  else { [self renderRooms]; }
  [self renderSide];
  [self layoutViewFlow];
  [self.model loadClimateHistory];
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
                     @[@"fans", @"Ventiladors", @"fan"], @[@"switches", @"Interruptors", @"light"], @[@"scenes", @"Escenes", @"spark"],
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
  if([category isEqualToString:@"climate"]) { [self navigate:@"climate"]; return; }
  NSDictionary *titles = @{@"lights": @"Il·luminació", @"security": @"Seguretat", @"water": @"Aigua calenta", @"media": @"Música i televisió",
                           @"fans": @"Ventiladors", @"switches": @"Interruptors", @"scenes": @"Escenes", @"other": @"Altres dispositius"};
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
  for(NSArray *period in @[@[@6, @"6 h"], @[@24, @"24 h"], @[@168, @"7 dies"], @[@720, @"1 mes"]]) {
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
  GRBlockView *header = [GRBlockView new];
  [header addSubview:title];
  for(UIView *button in periods) { [header addSubview:button]; }
  header.measure = ^CGFloat(CGFloat width) { return 52; };
  header.layout = ^(UIView *view) {
    CGFloat x = view.bounds.size.width;
    for(UIView *button in [periods reverseObjectEnumerator]) {
      CGFloat w = MAX(64, ceil([button sizeThatFits:CGSizeMake(200, 44)].width));
      x -= w; button.frame = CGRectMake(x, 4, w, 44); x -= 8;
    }
    title.frame = CGRectMake(0, 0, x - 12, 52);
  };
  [_viewFlow addView:header top:0];

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
    chip.layer.cornerRadius = 16; chip.layer.borderWidth = selected ? 1.5 : 1;
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
    // Whatever height is left below the header, sensors and reading (52 + 18 + 64 + 20 + 96 + 16).
    return MAX(240, (strongSelf ? strongSelf->_scroll.bounds.size.height : 400) - 266);
  };
  chartRow.layout = ^(UIView *view) { chart.frame = view.bounds; [chart setNeedsDisplay]; };
  [_viewFlow addView:chartRow top:16];
}

- (void)climateSensorTapped:(UIControl *)chip {
  _climateSensor = chip.accessibilityIdentifier;
  _climateIndex = -1;
  [self renderView];
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
  _serverField = nil; _tokenField = nil; _alarmField = nil;
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
  _alarmField.text = @"";
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
  _serverField = nil; _tokenField = nil; _alarmField = nil;
}

- (void)rebuildModal {
  if(!_modal) { return; }
  CGPoint offset = _modalScroll.contentOffset;
  NSString *type = _modal[@"type"];
  if([type isEqualToString:@"category"]) { [self openCategory:_modal[@"id"] title:_modal[@"title"]]; }
  else if([type isEqualToString:@"room"]) { [self openRoom:_modal[@"id"]]; }
  else if([type isEqualToString:@"settings"]) { [self openSettings]; }
  else if([type isEqualToString:@"audit"]) { [self showAudit]; }
  else if([type isEqualToString:@"alarm"]) { [self openCategory:@"security" title:@"Seguretat"]; return; }
  [self layoutModal];
  CGFloat maxY = MAX(0, _modalScroll.contentSize.height - _modalScroll.bounds.size.height + _modalScroll.contentInset.bottom);
  _modalScroll.contentOffset = CGPointMake(0, MIN(offset.y, maxY));
}

- (BOOL)isEditingModal {
  return _modalDirty || _serverField.isFirstResponder || _tokenField.isFirstResponder || _alarmField.isFirstResponder;
}

- (void)refreshModal {
  if(!_modal || self.model.busy) { return; }
  NSString *type = _modal[@"type"];
  if([self isEditingModal] && self.model.connected) { return; }
  if([type isEqualToString:@"alarm"]) { if(!self.model.connected) { [self openCategory:@"security" title:@"Seguretat"]; } return; }
  if([type isEqualToString:@"settings"] && [self isEditingModal]) { return; }
  if([type isEqualToString:@"audit"]) { return; }
  [self rebuildModal];
}

- (void)openRoom:(NSString *)roomId {
  NSDictionary *room = [GRLogic roomWithId:roomId];
  if(!room) { return; }
  GRFlowView *parent = [self openModal:room[@"name"] eyebrow:@"ESTANÇA" type:@"room" modalId:roomId];
  NSArray *entities = [GRLogic entities:self.model.entities inRoom:roomId];
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
  box.layer.cornerRadius = 14; box.layer.borderWidth = 1; box.layer.borderColor = (color ?: t.edge).CGColor;
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
  if([kind isEqualToString:@"range"]) {
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

- (void)alarmPrompt:(NSDictionary *)entity control:(NSDictionary *)control {
  GRTheme *t = [GRTheme current];
  GRFlowView *parent = [self openModal:GRStr(control[@"label"]) ?: @"Alarma" eyebrow:@"SEGURETAT" type:@"alarm" modalId:entity[@"entity_id"]];
  [parent addView:[self infoBox:[NSString stringWithFormat:@"Estat actual: %@. Confirma l’ordre abans d’enviar-la.", [GRLogic stateTextForEntity:entity connected:self.model.connected demo:self.model.demo]] color:nil] top:8];
  if([control[@"requires_code"] isEqual:@YES]) {
    [parent addView:GRLabel(@"PIN de l’alarma", GRFont(13, UIFontWeightRegular), t.muted) top:18];
    _alarmField = [self textField:nil placeholder:nil secure:YES];
    _alarmField.keyboardType = UIKeyboardTypeNumberPad;
    _alarmField.accessibilityLabel = @"PIN de l’alarma";
    [parent addView:_alarmField top:8 height:50];
    [parent addView:[self note:@"El PIN només s’envia amb aquesta ordre i s’esborra del camp immediatament."] top:8];
  }
  __weak GRMainViewController *weakSelf = self;
  GRButton *submit = [GRButton buttonWithTitle:GRStr(control[@"label"]) style:GRButtonStylePrimary handler:^(GRButton *b) {
    GRMainViewController *strongSelf = weakSelf;
    if(!strongSelf) { return; }
    UITextField *field = strongSelf->_alarmField;
    NSString *code = field ? [field.text copy] : nil;
    field.text = @"";
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
    if(strongSelf && [strongSelf->_modal[@"type"] isEqualToString:@"alarm"]) { [strongSelf openCategory:@"security" title:@"Seguretat"]; }
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
  field.layer.cornerRadius = 12; field.layer.borderWidth = 1; field.layer.borderColor = t.edge.CGColor;
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
  else { [textField resignFirstResponder]; }
  return NO;
}

- (GRFlowView *)settingsSection:(NSString *)title {
  GRFlowView *section = [GRFlowView new];
  section.insets = UIEdgeInsetsMake(22, 0, 24, 0);
  [section addView:[self sectionLabel:title.uppercaseString] top:0];
  return section;
}

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

- (void)openSettings {
  GRTheme *t = [GRTheme current];
  GRPreferences *preferences = [GRPreferences shared];
  GRFlowView *parent = [self openModal:@"Ajustos" eyebrow:@"PREFERÈNCIES" type:@"settings" modalId:@"settings"];
  __weak GRMainViewController *weakSelf = self;
  BOOL needsSetup = _configurationMessage.length && !self.model.authenticated && !self.model.preview;
  if(needsSetup) {
    // The connection fields come first until the app can reach the panel.
    [parent addView:[self infoBox:_configurationMessage color:t.issue] top:4];
    [parent addView:[self connectionSection] top:0];
    [parent addView:[GRRuleView ruleWithColor:t.line] top:0];
  }
  GRFlowView *section = [self settingsSection:@"Tema"];
  NSMutableArray *segments = [NSMutableArray array];
  GRBlockView *segmentRow = [GRBlockView new];
  for(NSArray *choice in @[@[@"auto", @"Automàtic"], @[@"day", @"Dia"], @[@"night", @"Nit"]]) {
    GRButton *button = [GRButton buttonWithTitle:choice[1] style:GRButtonStyleSegment handler:^(GRButton *b) { [weakSelf setThemeChoice:choice[0]]; [weakSelf openSettings]; }];
    button.selectedLook = [preferences.theme isEqualToString:choice[0]];
    button.accessibilityTraits = UIAccessibilityTraitButton | (button.selectedLook ? UIAccessibilityTraitSelected : 0);
    [segmentRow addSubview:button]; [segments addObject:button];
  }
  segmentRow.measure = ^CGFloat(CGFloat width) { return 46; };
  segmentRow.layout = ^(UIView *view) {
    CGFloat w = (view.bounds.size.width - 16) / 3;
    for(NSUInteger i = 0; i < segments.count; i++) { [segments[i] setFrame:CGRectMake(i * (w + 8), 0, w, 46)]; }
  };
  [section addView:segmentRow top:14];
  [section addView:[self note:@"Automàtic: dia de 7 a 20 h, segons el rellotge de l’iPad."] top:10];
  [parent addView:section top:0];
  [parent addView:[GRRuleView ruleWithColor:t.line] top:0];

  section = [self settingsSection:@"Pantalla"];
  [section addView:[self switchRow:@"Mantén la pantalla encesa" on:preferences.keepAwake changed:^(BOOL on) {
    [GRPreferences shared].keepAwake = on; [UIApplication sharedApplication].idleTimerDisabled = on;
  }] top:8];
  [section addView:[self note:@"Útil si l’iPad queda fix a la paret i connectat al carregador."] top:4];
  [parent addView:section top:0];
  [parent addView:[GRRuleView ruleWithColor:t.line] top:0];

  if(!needsSetup) { [parent addView:[self connectionSection] top:0]; }
  [parent addView:[self note:[NSString stringWithFormat:@"Glass Rooms %@ · App nativa per a iPad · Actualitzacions en directe de Home Assistant.", GRVersion]] top:18];
  [self finishModal];
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
  output.layer.cornerRadius = 12; output.layer.borderWidth = 1; output.layer.borderColor = t.edge.CGColor;
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
  UIView *field = _serverField.isFirstResponder ? _serverField : (_tokenField.isFirstResponder ? _tokenField : (_alarmField.isFirstResponder ? _alarmField : nil));
  if(field) { [_modalScroll scrollRectToVisible:[_modalScroll convertRect:CGRectInset(field.bounds, 0, -20) fromView:field] animated:YES]; }
}

- (void)keyboardWillHide:(NSNotification *)notification {
  _keyboardHeight = 0;
  [self layoutModal];
  [self layoutToast];
}

@end
