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

typedef struct {
  BOOL narrow;
  CGFloat rail, padTop, padSide, padBottom, cardHeight, cardPadTop, cardPadSide, cardPadBottom, art, artTop, artBottom;
  CGFloat rowGap, badge, badgeIcon, badgeBottom;
  NSInteger columns;
} GRMetrics;

static GRMetrics GRMetricsForWidth(CGFloat width) {
  // style.css rules for max-width 1100px (iPad landscape) and max-width 820px (iPad portrait).
  GRMetrics m;
  m.narrow = width <= 820; m.rail = 80;
  if(!m.narrow) {
    m.padTop = 24; m.padSide = 29; m.padBottom = 18; m.columns = 4; m.cardHeight = 211;
    m.cardPadTop = 13; m.cardPadSide = 13; m.cardPadBottom = 10; m.art = 127; m.artTop = -3; m.artBottom = -1;
    m.rowGap = 12; m.badge = 88; m.badgeIcon = 44; m.badgeBottom = 12;
  } else {
    m.padTop = 24; m.padSide = 24; m.padBottom = 24; m.columns = 2; m.cardHeight = 160;
    m.cardPadTop = 10; m.cardPadSide = 13; m.cardPadBottom = 8; m.art = 95; m.artTop = -5; m.artBottom = -3;
    m.rowGap = 8; m.badge = 72; m.badgeIcon = 38; m.badgeBottom = 8;
  }
  return m;
}

#pragma mark - Small views

@interface GRNavButton : UIControl
@property (nonatomic, copy) NSString *destination;
@property (nonatomic, strong) UIImageView *icon;
@property (nonatomic, strong) UILabel *label;
@property (nonatomic) BOOL active;
@end

@implementation GRNavButton
- (instancetype)initWithIcon:(NSString *)icon label:(NSString *)label destination:(NSString *)destination accessibility:(NSString *)accessibility {
  if((self = [super initWithFrame:CGRectMake(0, 0, 64, 65)])) {
    _destination = destination;
    _icon = GRIconView(icon, NO, [GRTheme current].nav);
    _label = GRLabel(nil, GRFont(10, UIFontWeightRegular), [GRTheme current].nav);
    _label.attributedText = GRKerned(label, GRFont(10, UIFontWeightRegular), [GRTheme current].nav, .2);
    _label.textAlignment = NSTextAlignmentCenter;
    [self addSubview:_icon]; [self addSubview:_label];
    self.layer.cornerRadius = 17;
    self.isAccessibilityElement = YES; self.accessibilityLabel = accessibility; self.accessibilityTraits = UIAccessibilityTraitButton;
  }
  return self;
}
- (void)applyTheme {
  GRTheme *t = [GRTheme current];
  UIColor *color = self.active ? t.navActive : t.nav;
  self.icon.tintColor = color;
  self.label.attributedText = GRKerned(self.label.attributedText.string, GRFont(10, UIFontWeightRegular), color, .2);
  self.backgroundColor = self.active ? t.navActiveBackground : [UIColor clearColor];
  self.accessibilityTraits = UIAccessibilityTraitButton | (self.active ? UIAccessibilityTraitSelected : 0);
}
- (void)setActive:(BOOL)active { _active = active; [self applyTheme]; }
- (void)setHighlighted:(BOOL)highlighted { [super setHighlighted:highlighted]; self.alpha = highlighted ? .7 : 1; }
- (void)layoutSubviews {
  [super layoutSubviews];
  CGFloat top = (self.bounds.size.height - 23 - 4 - 14) / 2;
  self.icon.frame = CGRectMake((self.bounds.size.width - 23) / 2, top, 23, 23);
  self.label.frame = CGRectMake(0, top + 27, self.bounds.size.width, 14);
}
@end

// Rounded card that highlights on touch, used for room and summary cards.
@interface GRCardControl : UIControl
@end
@implementation GRCardControl
- (void)setHighlighted:(BOOL)highlighted { [super setHighlighted:highlighted]; self.alpha = highlighted ? .86 : 1; }
@end

#pragma mark - Controller

@interface GRMainViewController () <UITextFieldDelegate>
@property (nonatomic, strong, readwrite) GRPanelModel *model;
@property (nonatomic) BOOL modalDirtyFlag;
@end

@implementation GRMainViewController {
  GRBackgroundView *_background;
  UIView *_rail, *_railBorder, *_brand, *_main, *_toastView, *_footer;
  NSMutableArray<GRNavButton *> *_navButtons;
  GRNavButton *_settingsButton;
  UILabel *_title, *_subtitle, *_clock, *_date, *_footerLeft, *_lastUpdate, *_toastLabel;
  UIButton *_timeIcon;
  UIScrollView *_scroll;
  GRFlowView *_viewFlow;
  NSString *_currentView, *_headingTitle, *_headingSubtitle;
  CGFloat _renderedWidth;
  GRTimer *_toastTimer, *_clockTimer;
  // Modal drawer
  UIView *_modalLayer, *_backdrop, *_drawer, *_drawerLine;
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
    _currentView = @"rooms";
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

#pragma mark View setup

- (void)viewDidLoad {
  [super viewDidLoad];
  [self updateThemeFromPreferences];
  _background = [[GRBackgroundView alloc] initWithFrame:self.view.bounds];
  _background.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  [self.view addSubview:_background];

  _rail = [UIView new];
  _railBorder = [UIView new];
  [_rail addSubview:_railBorder];
  _brand = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 30, 32)];
  _brand.clipsToBounds = YES;
  for(NSInteger i = 0; i < 4; i++) {
    UIView *square = [[UIView alloc] initWithFrame:CGRectMake(1 + (i % 2) * 14, 1 + (i / 2) * 15, 12, 13)];
    square.layer.cornerRadius = 4; square.layer.borderWidth = 1; square.tag = 100 + i;
    [_brand addSubview:square];
  }
  _brand.transform = CGAffineTransformMakeRotation(-5 * M_PI / 180);
  _brand.isAccessibilityElement = YES; _brand.accessibilityLabel = @"Glass Rooms";
  [_rail addSubview:_brand];
  NSArray *items = @[@[@"home", @"Casa", @"rooms", @"Habitacions"], @[@"overview", @"Resum", @"overview", @"Resum general"],
                     @[@"thermometer", @"Clima", @"climate", @"Temperatura i humitat"], @[@"light", @"Llums", @"lights", @"Llums"],
                     @[@"shield", @"Alarma", @"security", @"Seguretat"], @[@"spark", @"Ambient", @"scenes", @"Escenes i ambient"]];
  for(NSArray *item in items) {
    GRNavButton *button = [[GRNavButton alloc] initWithIcon:item[0] label:item[1] destination:item[2] accessibility:item[3]];
    [button addTarget:self action:@selector(navTapped:) forControlEvents:UIControlEventTouchUpInside];
    [_navButtons addObject:button]; [_rail addSubview:button];
  }
  _settingsButton = [[GRNavButton alloc] initWithIcon:@"settings" label:@"Ajustos" destination:@"settings" accessibility:@"Preferències"];
  [_settingsButton addTarget:self action:@selector(openSettings) forControlEvents:UIControlEventTouchUpInside];
  [_rail addSubview:_settingsButton];
  [self.view addSubview:_rail];

  _main = [UIView new];
  [self.view addSubview:_main];
  _title = GRLabel(nil, GRFont(33, UIFontWeightRegular), [GRTheme current].text);
  _title.numberOfLines = 0;
  _subtitle = GRLabel(nil, GRFont(14, UIFontWeightRegular), [GRTheme current].subtitle);
  _clock = GRLabel(@"--:--", [UIFont monospacedDigitSystemFontOfSize:30 weight:UIFontWeightLight], [GRTheme current].text);
  _clock.textAlignment = NSTextAlignmentRight;
  _date = GRLabel(nil, GRFont(11, UIFontWeightRegular), [GRTheme current].subtitle);
  _date.textAlignment = NSTextAlignmentRight;
  _timeIcon = [UIButton buttonWithType:UIButtonTypeCustom];
  _timeIcon.layer.cornerRadius = 12;
  [_timeIcon addTarget:self action:@selector(toggleTheme) forControlEvents:UIControlEventTouchUpInside];
  for(UIView *view in @[_title, _subtitle, _timeIcon, _clock, _date]) { [_main addSubview:view]; }

  _scroll = [UIScrollView new];
  _scroll.alwaysBounceVertical = YES;
  _scroll.delaysContentTouches = NO;
  _viewFlow = [GRFlowView new];
  [_scroll addSubview:_viewFlow];
  [_main addSubview:_scroll];

  _footer = [UIView new];
  _footerLeft = GRLabel(nil, GRFont(10, UIFontWeightRegular), [GRTheme current].footer);
  _lastUpdate = GRLabel(@"Esperant dades de casa", GRFont(10, UIFontWeightRegular), [GRTheme current].footer);
  [_footer addSubview:_footerLeft]; [_footer addSubview:_lastUpdate];
  [_main addSubview:_footer];

  [self buildModalLayer];
  _toastView = [UIView new];
  _toastView.layer.cornerRadius = 14; _toastView.layer.borderWidth = 1; _toastView.layer.borderColor = GRHexA(0xffffff, .2).CGColor;
  _toastView.layer.shadowColor = [UIColor blackColor].CGColor; _toastView.layer.shadowOpacity = .15; _toastView.layer.shadowRadius = 12; _toastView.layer.shadowOffset = CGSizeMake(0, 5);
  _toastView.hidden = YES; _toastView.userInteractionEnabled = NO;
  _toastLabel = GRWrappingLabel(nil, GRFont(13, UIFontWeightRegular), [UIColor whiteColor], 0);
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
  _drawer.layer.cornerRadius = 25; _drawer.layer.borderWidth = 1; _drawer.clipsToBounds = NO;
  _drawer.layer.shadowColor = GRHex(0x2b3625).CGColor; _drawer.layer.shadowOpacity = .13; _drawer.layer.shadowRadius = 35; _drawer.layer.shadowOffset = CGSizeMake(0, 20);
  _drawer.accessibilityViewIsModal = YES;
  _modalEyebrow = GRLabel(nil, GRFont(10, UIFontWeightSemibold), [GRTheme current].muted);
  _modalTitle = GRLabel(nil, GRFont(28, UIFontWeightRegular), [GRTheme current].text);
  _modalTitle.adjustsFontSizeToFitWidth = YES; _modalTitle.minimumScaleFactor = .6;
  _drawerLine = [UIView new];
  _closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
  _closeButton.layer.cornerRadius = 23;
  _closeButton.accessibilityLabel = @"Tanca";
  [_closeButton setImage:GRIcon(@"close", NO) forState:UIControlStateNormal];
  [_closeButton addTarget:self action:@selector(closeModal) forControlEvents:UIControlEventTouchUpInside];
  _modalScroll = [UIScrollView new];
  _modalScroll.alwaysBounceVertical = YES;
  _modalScroll.delaysContentTouches = NO;
  _modalScroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
  _modalFlow = [GRFlowView new];
  [_modalScroll addSubview:_modalFlow];
  UIView *clip = [UIView new];
  clip.tag = 7; clip.clipsToBounds = YES; clip.layer.cornerRadius = 25;
  for(UIView *view in @[_modalEyebrow, _modalTitle, _drawerLine, _closeButton, _modalScroll]) { [clip addSubview:view]; }
  [_drawer addSubview:clip];
  [_modalLayer addSubview:_drawer];
  [self.view addSubview:_modalLayer];
}

#pragma mark Layout

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  CGSize size = self.view.bounds.size;
  GRMetrics m = GRMetricsForWidth(size.width);
  CGFloat top = [self statusBarHeight];
  _rail.frame = CGRectMake(0, 0, m.rail, size.height);
  _railBorder.frame = CGRectMake(m.rail - 1, 0, 1, size.height);
  _brand.center = CGPointMake(m.rail / 2, top + 33 + 16);
  CGFloat y = top + 33 + 32 + 49;
  for(GRNavButton *button in _navButtons) { button.frame = CGRectMake((m.rail - 64) / 2, y, 64, 65); y += 65 + 13; }
  _settingsButton.frame = CGRectMake((m.rail - 64) / 2, size.height - 18 - 65, 64, 65);

  _main.frame = CGRectMake(m.rail, top, size.width - m.rail, size.height - top);
  CGFloat width = _main.bounds.size.width - 2 * m.padSide, x = m.padSide;
  CGFloat clockWidth = MAX(ceil([_clock sizeThatFits:CGSizeMake(200, 50)].width), 70);
  CGFloat clockBlock = 44 + 3 + clockWidth;
  _timeIcon.frame = CGRectMake(x + width - clockBlock, m.padTop, 44, 44);
  _clock.frame = CGRectMake(x + width - clockWidth, m.padTop, clockWidth, 44);
  _date.frame = CGRectMake(x + width - 220, m.padTop + 42, 220, 16);
  CGFloat titleWidth = width - clockBlock - 16;
  CGFloat titleHeight = ceil([_title sizeThatFits:CGSizeMake(titleWidth, CGFLOAT_MAX)].height);
  _title.frame = CGRectMake(x, m.padTop, titleWidth, titleHeight);
  _subtitle.frame = CGRectMake(x, m.padTop + titleHeight + 9, titleWidth, 20);
  CGFloat topbar = MAX(105, titleHeight + 9 + 20 + 8);

  CGFloat footerHeight = m.narrow ? 42 : 25;
  _footer.frame = CGRectMake(x, _main.bounds.size.height - m.padBottom - footerHeight, width, footerHeight);
  _footerLeft.frame = CGRectMake(0, 0, width, 25);
  _lastUpdate.textAlignment = m.narrow ? NSTextAlignmentLeft : NSTextAlignmentRight;
  _lastUpdate.frame = m.narrow ? CGRectMake(0, 25, width, 16) : CGRectMake(width / 2, 6, width / 2, 16);
  CGFloat scrollTop = m.padTop + topbar;
  _scroll.frame = CGRectMake(x, scrollTop, width, CGRectGetMinY(_footer.frame) - 11 - scrollTop);

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
  GRPreferences *preferences = [GRPreferences shared];
  _night = [GRLogic isNightForTheme:preferences.theme date:[NSDate date]];
  [GRTheme setNight:_night glass:preferences.glass];
}

- (void)applyThemeColors {
  GRTheme *t = [GRTheme current];
  [_background setNeedsDisplay];
  _rail.backgroundColor = t.rail; _railBorder.backgroundColor = t.railBorder;
  for(UIView *square in _brand.subviews) {
    square.layer.borderColor = t.brandBorder.CGColor;
    square.backgroundColor = square.tag == 101 ? t.brandFillStrong : t.brandFill;
  }
  for(GRNavButton *button in _navButtons) { [button applyTheme]; }
  [_settingsButton applyTheme];
  _title.textColor = t.text; _subtitle.textColor = t.subtitle; _clock.textColor = t.text; _date.textColor = t.subtitle;
  [_timeIcon setImage:GRIcon(_night ? @"moon" : @"sun", NO) forState:UIControlStateNormal];
  _timeIcon.tintColor = t.timeIcon;
  _timeIcon.accessibilityLabel = _night ? @"Activa el mode clar" : @"Activa el mode fosc";
  [self updateHeadingLabels];
  NSMutableAttributedString *leaf = [[NSMutableAttributedString alloc] initWithString:@"⌁ " attributes:@{NSFontAttributeName: GRFont(22, UIFontWeightRegular), NSForegroundColorAttributeName: t.leaf, NSBaselineOffsetAttributeName: @(-2)}];
  [leaf appendAttributedString:GRKerned(@"Un espai per viure-hi bé.", GRFont(10, UIFontWeightRegular), t.footer, .2)];
  _footerLeft.attributedText = leaf;
  _lastUpdate.textColor = t.footer;
  _backdrop.backgroundColor = t.backdrop;
  _drawer.backgroundColor = t.drawer; _drawer.layer.borderColor = t.drawerBorder.CGColor;
  _drawerLine.backgroundColor = t.drawerLine;
  _modalTitle.textColor = t.text;
  _closeButton.backgroundColor = t.iconButton; _closeButton.tintColor = t.text;
  _toastView.backgroundColor = t.toast;
  [self setNeedsStatusBarAppearanceUpdate];
}

- (void)applyTheme {
  BOOL wasNight = _night, wasGlass = [GRTheme current].glass;
  [self updateThemeFromPreferences];
  if(wasNight == _night && wasGlass == [GRTheme current].glass) { return; }
  [self applyThemeColors];
  [self renderView];
  [self rebuildModal];
}

- (void)toggleTheme {
  [GRPreferences shared].theme = _night ? @"day" : @"night";
  [self applyTheme];
}

- (void)setThemeChoice:(NSString *)theme {
  [GRPreferences shared].theme = theme;
  [self applyTheme];
}

- (void)clockTick {
  NSDate *now = [NSDate date];
  _clock.text = [GRLogic clockText:now];
  _date.text = [GRLogic dateText:now];
  [self applyTheme];
  [_clockTimer cancel];
  __weak GRMainViewController *weakSelf = self;
  NSTimeInterval next = 30 - fmod(now.timeIntervalSince1970, 30) + .05;
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
  if([_currentView isEqualToString:@"climate"]) { [self renderView]; }
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
  CGFloat width = MIN(380, size.width * .9);
  CGFloat textHeight = ceil([_toastLabel sizeThatFits:CGSizeMake(width - 42, CGFLOAT_MAX)].height);
  CGFloat height = textHeight + 36;
  _toastView.frame = CGRectMake((size.width - width) / 2, size.height - 25 - height - _keyboardHeight, width, height);
  _toastLabel.frame = CGRectMake(21, 18, width - 42, textHeight);
  _toastView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:_toastView.bounds cornerRadius:14].CGPath;
}

#pragma mark Rendering helpers

- (BOOL)live { return self.model.connected || self.model.demo; }

- (void)setHeading:(NSString *)title subtitle:(NSString *)subtitle {
  _headingTitle = title; _headingSubtitle = subtitle;
  [self updateHeadingLabels];
  [self.view setNeedsLayout];
}

- (void)updateHeadingLabels {
  GRTheme *t = [GRTheme current];
  _title.attributedText = GRKerned(_headingTitle ?: @"Casa, amb calma.", GRFont(33, UIFontWeightRegular), t.text, -1.3);
  _title.accessibilityTraits = UIAccessibilityTraitHeader;
  _subtitle.text = _headingSubtitle ?: @"Cada estança, al teu ritme.";
}

- (void)renderStatus { _lastUpdate.text = [GRLogic lastUpdateText:self.model.fetchedAt connected:self.model.connected demo:self.model.demo]; }

- (UIView *)sectionLabel:(NSString *)text note:(NSString *)note {
  GRTheme *t = [GRTheme current];
  UILabel *label = GRLabel(nil, GRFont(11, UIFontWeightMedium), t.sectionLabel);
  label.attributedText = GRKerned(text, GRFont(11, UIFontWeightMedium), t.sectionLabel, 1.7);
  label.accessibilityTraits = UIAccessibilityTraitHeader;
  UILabel *side = GRLabel(nil, GRFont(10, UIFontWeightRegular), t.sectionNote);
  side.attributedText = GRKerned(note, GRFont(10, UIFontWeightRegular), t.sectionNote, .4);
  side.textAlignment = NSTextAlignmentRight;
  GRBlockView *row = [GRBlockView new];
  [row addSubview:label]; [row addSubview:side];
  row.measure = ^CGFloat(CGFloat width) { return 16; };
  row.layout = ^(UIView *view) {
    CGFloat w = view.bounds.size.width;
    label.frame = CGRectMake(0, 0, w * .65, 16);
    side.frame = CGRectMake(w * .5, 0, w * .5, 16);
  };
  return row;
}

- (GRBlockView *)gridWithItems:(NSArray<UIView *> *)items columns:(NSInteger)columns gap:(CGFloat)gap rowGap:(CGFloat)rowGap
                    itemHeight:(CGFloat (^)(UIView *item, CGFloat width))itemHeight {
  GRBlockView *grid = [GRBlockView new];
  for(UIView *item in items) { [grid addSubview:item]; }
  CGFloat (^layout)(CGFloat, BOOL) = ^CGFloat(CGFloat width, BOOL apply) {
    CGFloat columnWidth = floor((width - gap * (columns - 1)) / columns), y = 0;
    for(NSUInteger start = 0; start < items.count; start += columns) {
      CGFloat rowHeight = 0;
      for(NSUInteger i = start; i < MIN(items.count, start + columns); i++) { rowHeight = MAX(rowHeight, itemHeight(items[i], columnWidth)); }
      for(NSUInteger i = start; i < MIN(items.count, start + columns); i++) {
        if(apply) { items[i].frame = CGRectMake((i - start) * (columnWidth + gap), y, columnWidth, rowHeight); }
      }
      y += rowHeight + rowGap;
    }
    return items.count ? y - rowGap : 0;
  };
  grid.measure = ^CGFloat(CGFloat width) { return layout(width, NO); };
  grid.layout = ^(UIView *view) { layout(view.bounds.size.width, YES); };
  return grid;
}

#pragma mark Main view

- (void)navTapped:(GRNavButton *)button { [self navigate:button.destination]; }

- (void)navigate:(NSString *)destination {
  [self closeModal];
  if([destination isEqualToString:@"lights"]) { [self openCategory:@"lights" title:@"Il·luminació"]; return; }
  if([destination isEqualToString:@"security"]) { [self openCategory:@"security" title:@"Seguretat"]; return; }
  if([destination isEqualToString:@"scenes"]) { [self openCategory:@"scenes" title:@"Escenes i ambient"]; return; }
  _currentView = destination;
  [self renderView];
  [_scroll setContentOffset:CGPointZero animated:NO];
}

- (void)renderView {
  if(!_viewFlow) { return; }
  for(UIView *view in [_viewFlow.subviews copy]) { [view removeFromSuperview]; }
  GRFlowView *fresh = [GRFlowView new];
  [_viewFlow removeFromSuperview];
  _viewFlow = fresh;
  [_scroll addSubview:_viewFlow];
  for(GRNavButton *button in _navButtons) { button.active = [button.destination isEqualToString:_currentView]; }
  self.model.climateVisible = [_currentView isEqualToString:@"climate"];
  if(![_currentView isEqualToString:@"climate"]) { [self renderGlobalLights]; }
  if([_currentView isEqualToString:@"rooms"]) {
    [self setHeading:@"Casa, amb calma." subtitle:self.model.demo ? @"Previsualització · llums simulats" : @"Cada estança, al teu ritme."];
    [self renderRooms];
  } else if([_currentView isEqualToString:@"climate"]) {
    [self setHeading:@"Temperatura i humitat." subtitle:@"Valors actuals i evolució de cada habitació."];
    [self renderClimate];
  } else {
    [self setHeading:@"Tot al seu lloc." subtitle:self.model.demo ? @"Previsualització · llums simulats" : @"L’estat de casa, sense presses."];
    [self renderOverview];
  }
  [self renderStatus];
  [self layoutViewFlow];
  if([_currentView isEqualToString:@"climate"]) { [self.model loadClimateHistory]; }
}

- (void)renderGlobalLights {
  GRTheme *t = [GRTheme current];
  NSArray *lights = [GRLogic lights:self.model.entities];
  NSMutableArray *controls = [NSMutableArray array];
  for(NSDictionary *option in @[@{@"action":@"turn_on",@"label":@"Encén",@"icon":@"lightOn"}, @{@"action":@"turn_off",@"label":@"Apaga",@"icon":@"light"}]) {
    BOOL on = [option[@"action"] isEqualToString:@"turn_on"];
    NSArray *ready = [GRLogic availableLights:lights action:option[@"action"]];
    NSUInteger skipped = lights.count - ready.count;
    NSString *label = [option[@"label"] stringByAppendingString:skipped ? @" llums disponibles" : @" tots els llums"];
    NSString *note = lights.count ? (ready.count ? [NSString stringWithFormat:@"%lu de %lu amb ordre verificada", (unsigned long)ready.count, (unsigned long)lights.count]
                                                  : @"Cap llum disponible amb aquesta ordre verificada")
                                  : @"Afegeix llums a la configuració del panell";
    GRCardControl *control = [GRCardControl new];
    UIColor *text = on ? t.allLightsOnText : t.allLightsText;
    control.backgroundColor = on ? t.allLightsOn : t.allLights;
    control.layer.borderColor = (on ? t.allLightsOnBorder : t.allLightsBorder).CGColor;
    control.layer.borderWidth = 1; control.layer.cornerRadius = 17;
    UIImageView *icon = GRIconView(option[@"icon"], YES, text);
    UILabel *title = GRLabel(lights.count ? label : @"Llums pendents de configurar", GRFont(17, UIFontWeightSemibold), text);
    UILabel *detail = GRLabel(note, GRFont(11, UIFontWeightRegular), [text colorWithAlphaComponent:.82]);
    title.adjustsFontSizeToFitWidth = YES; title.minimumScaleFactor = .75;
    detail.adjustsFontSizeToFitWidth = YES; detail.minimumScaleFactor = .8;
    for(UIView *view in @[icon, title, detail]) { view.userInteractionEnabled = NO; }
    BOOL disabled = !self.model.connected || self.model.preview || self.model.busy || !ready.count;
    control.enabled = !disabled;
    control.alpha = disabled ? .58 : 1;
    control.isAccessibilityElement = YES;
    control.accessibilityLabel = disabled ? [NSString stringWithFormat:@"%@. Sense llums disponibles amb aquesta ordre verificada", title.text] : label;
    control.accessibilityTraits = UIAccessibilityTraitButton | (disabled ? UIAccessibilityTraitNotEnabled : 0);
    [control addTarget:self action:@selector(globalLightsTapped:) forControlEvents:UIControlEventTouchUpInside];
    control.tag = on ? 1 : 2;
    GRBlockView *content = [GRBlockView new];
    content.userInteractionEnabled = NO;
    content.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    for(UIView *view in @[icon, title, detail]) { [content addSubview:view]; }
    content.layout = ^(UIView *view) {
      CGFloat w = view.bounds.size.width, h = view.bounds.size.height, left = 18 + 42 + 15;
      icon.frame = CGRectMake(18, (h - 42) / 2, 42, 42);
      title.frame = CGRectMake(left, h / 2 - 22, w - left - 18, 24);
      detail.frame = CGRectMake(left, h / 2 + 3, w - left - 18, 16);
    };
    [control addSubview:content];
    [controls addObject:control];
  }
  GRBlockView *row = [self gridWithItems:controls columns:2 gap:16 rowGap:0 itemHeight:^CGFloat(UIView *item, CGFloat width) { return 72; }];
  void (^layoutRow)(UIView *) = row.layout;
  row.layout = ^(UIView *view) {
    layoutRow(view);
    for(UIView *control in controls) { UIView *content = control.subviews.lastObject; content.frame = control.bounds; [content setNeedsLayout]; }
  };
  [_viewFlow addView:row top:0];
  [_viewFlow addView:[UIView new] top:0 height:18];
}

- (void)globalLightsTapped:(UIControl *)control {
  NSString *action = control.tag == 1 ? @"turn_on" : @"turn_off";
  NSArray *lights = [GRLogic lights:self.model.entities];
  NSArray *ready = [GRLogic availableLights:lights action:action];
  [self.model turnLights:ready place:@"tota la casa" action:action skipped:lights.count - ready.count];
}

- (void)renderRooms {
  GRTheme *t = [GRTheme current];
  GRMetrics m = GRMetricsForWidth(self.view.bounds.size.width);
  [_viewFlow addView:[self sectionLabel:@"LES HABITACIONS" note:@"8 espais"] top:0];
  NSMutableArray *wraps = [NSMutableArray array], *layouts = [NSMutableArray array];
  BOOL live = [self live];
  for(NSDictionary *room in [GRLogic rooms]) {
    NSString *roomId = room[@"id"], *name = room[@"name"];
    NSArray *entities = [GRLogic entities:self.model.entities inRoom:roomId];
    NSArray *roomLights = [GRLogic lights:entities];
    BOOL lit = NO;
    for(NSDictionary *light in roomLights) { if([light[@"status"] isEqual:@"ok"] && [light[@"state"] isEqual:@"on"]) { lit = YES; } }
    NSUInteger online = [GRLogic onlineLights:roomLights live:live], offline = roomLights.count - online;
    NSString *counts = [NSString stringWithFormat:@"%lu online · %lu offline", (unsigned long)online, (unsigned long)offline];

    UIView *wrap = [UIView new];
    GRCardControl *card = [GRCardControl new];
    card.accessibilityIdentifier = roomId;
    [card addTarget:self action:@selector(roomTapped:) forControlEvents:UIControlEventTouchUpInside];
    UIColor *background = t.card, *border = t.cardBorder;
    if(roomLights.count) { background = lit ? t.cardLit : t.cardDark; border = lit ? t.cardLitBorder : t.cardDarkBorder; }
    card.backgroundColor = background;
    card.layer.cornerRadius = 17; card.layer.borderWidth = 1; card.layer.borderColor = border.CGColor;
    if(roomLights.count && lit) {
      card.layer.shadowColor = GRHex(t.night ? 0xe5b55f : 0xab8340).CGColor; card.layer.shadowOpacity = t.night ? .18 : .13;
      card.layer.shadowRadius = 12; card.layer.shadowOffset = CGSizeMake(0, 8);
    }
    UILabel *title = GRLabel(name, GRFont(16, UIFontWeightMedium), t.text);
    UIImageView *art = [[UIImageView alloc] initWithImage:[UIImage imageNamed:[@"room-" stringByAppendingString:roomId]]];
    art.contentMode = UIViewContentModeScaleAspectFit;
    art.alpha = roomLights.count && !lit ? .42 : (t.night && !lit ? .85 : 1);
    UIView *rule = [UIView new]; rule.backgroundColor = t.metaBorder;
    UIView *dot = [UIView new]; dot.layer.cornerRadius = 2.5; dot.backgroundColor = offline ? t.dotIssue : t.dot;
    UILabel *meta = GRLabel(counts, GRFont(11, UIFontWeightRegular), offline ? t.metaIssue : t.meta);
    meta.numberOfLines = 2; meta.adjustsFontSizeToFitWidth = YES; meta.minimumScaleFactor = .8;
    for(UIView *view in @[title, art, rule, dot, meta]) { view.userInteractionEnabled = NO; [card addSubview:view]; }
    card.isAccessibilityElement = YES; card.accessibilityTraits = UIAccessibilityTraitButton;
    card.accessibilityLabel = [NSString stringWithFormat:@"Obre %@, %@%@", name, counts, roomLights.count && live ? (lit ? @", amb llums encesos" : @", llums apagats") : @""];
    [wrap addSubview:card];

    UIButton *badge = nil;
    if(roomLights.count) {
      NSString *toggle = lit ? @"turn_off" : @"turn_on";
      NSArray *pending = [GRLogic lightsNeedingAction:roomLights action:toggle];
      BOOL canToggle = [GRLogic canToggleLights:pending action:toggle];
      badge = [UIButton buttonWithType:UIButtonTypeCustom];
      UIColor *color = lit ? t.bulbLit : t.bulbDark;
      badge.backgroundColor = lit ? t.bulbLitBackground : t.bulbDarkBackground;
      badge.layer.borderWidth = 2; badge.layer.borderColor = color.CGColor; badge.layer.cornerRadius = m.badge / 2;
      if(lit) { badge.layer.shadowColor = GRHex(0xffd57c).CGColor; badge.layer.shadowOpacity = .65; badge.layer.shadowRadius = 6; badge.layer.shadowOffset = CGSizeZero; }
      UIImageView *bulb = GRIconView(lit ? @"lightOn" : @"light", YES, color);
      bulb.userInteractionEnabled = NO; bulb.tag = 9;
      [badge addSubview:bulb];
      badge.enabled = canToggle && self.model.connected && !self.model.preview && !self.model.busy;
      badge.accessibilityLabel = [NSString stringWithFormat:@"%@ totes les llums de %@", lit ? @"Apaga" : @"Encén", name];
      badge.accessibilityHint = badge.enabled ? nil : @"Control pendent de connexió o verificació";
      badge.accessibilityIdentifier = roomId;
      badge.tag = lit ? 1 : 0;
      [badge addTarget:self action:@selector(roomBadgeTapped:) forControlEvents:UIControlEventTouchUpInside];
      [wrap addSubview:badge];
    }
    GRMetrics metrics = m;
    __weak UIView *weakWrap = wrap;
    [layouts addObject:[^{
      UIView *w = weakWrap;
      if(!w) { return; }
      CGFloat width = w.bounds.size.width;
      card.frame = CGRectMake(0, 0, width, metrics.cardHeight);
      CGFloat inner = width - 2 * metrics.cardPadSide;
      title.frame = CGRectMake(metrics.cardPadSide, metrics.cardPadTop, inner, 23);
      CGFloat artTop = metrics.cardPadTop + 23 + metrics.artTop;
      art.frame = CGRectMake(metrics.cardPadSide, artTop, inner, metrics.art);
      CGFloat metaTop = artTop + metrics.art + metrics.artBottom;
      rule.frame = CGRectMake(metrics.cardPadSide, metaTop, inner, 1);
      dot.frame = CGRectMake(metrics.cardPadSide, metaTop + 8 + 6, 5, 5);
      meta.frame = CGRectMake(metrics.cardPadSide + 11, metaTop + 8, inner - 11, MAX(16, metrics.cardHeight - metaTop - 8 - metrics.cardPadBottom));
      if(meta.frame.size.height > 18) { meta.frame = CGRectMake(meta.frame.origin.x, meta.frame.origin.y, meta.frame.size.width, 16); }
      if(card.layer.shadowOpacity > 0) { card.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:card.bounds cornerRadius:17].CGPath; }
      if(badge) {
        badge.frame = CGRectMake((width - metrics.badge) / 2, (metrics.cardHeight - metrics.badge) / 2, metrics.badge, metrics.badge);
        UIView *bulb = [badge viewWithTag:9];
        bulb.frame = CGRectMake((metrics.badge - metrics.badgeIcon) / 2, (metrics.badge - metrics.badgeIcon) / 2, metrics.badgeIcon, metrics.badgeIcon);
        if(badge.layer.shadowOpacity > 0) {
          // CSS box-shadow glows outside only; a ring path keeps the translucent badge see-through.
          UIBezierPath *ring = [UIBezierPath bezierPathWithOvalInRect:badge.bounds];
          [ring appendPath:[[UIBezierPath bezierPathWithOvalInRect:CGRectInset(badge.bounds, 2, 2)] bezierPathByReversingPath]];
          badge.layer.shadowPath = ring.CGPath;
        }
      }
    } copy]];
    [wraps addObject:wrap];
  }
  CGFloat cardHeight = m.cardHeight;
  GRBlockView *grid = [self gridWithItems:wraps columns:m.columns gap:12 rowGap:m.rowGap itemHeight:^CGFloat(UIView *item, CGFloat width) { return cardHeight; }];
  CGFloat (^measure)(CGFloat) = grid.measure;
  grid.measure = ^CGFloat(CGFloat width) { return measure(width) + m.rowGap; };
  void (^layout)(UIView *) = grid.layout;
  grid.layout = ^(UIView *view) {
    layout(view);
    for(dispatch_block_t block in layouts) { block(); }
  };
  [_viewFlow addView:grid top:14];
}

- (void)roomTapped:(UIControl *)card { [self openRoom:card.accessibilityIdentifier]; }

- (void)roomBadgeTapped:(UIButton *)badge {
  NSDictionary *room = [GRLogic roomWithId:badge.accessibilityIdentifier];
  NSArray *lights = [GRLogic lights:[GRLogic entities:self.model.entities inRoom:room[@"id"]]];
  NSString *toggle = badge.tag ? @"turn_off" : @"turn_on";
  [self.model turnLights:[GRLogic lightsNeedingAction:lights action:toggle] place:room[@"name"] action:toggle skipped:0];
}

- (void)renderOverview {
  GRTheme *t = [GRTheme current];
  [_viewFlow addView:[self sectionLabel:@"D’UN COP D’ULL" note:self.model.demo ? @"Llums simulats" : @"Només lectures reals"] top:0];
  NSArray *items = @[@[@"climate", @"Temperatura i humitat", @"thermometer", @"Sensors ambientals configurats"],
                     @[@"lights", @"Il·luminació", @"light", @"Llums configurats"], @[@"security", @"Seguretat", @"shield", @"Entitats de seguretat configurades"],
                     @[@"water", @"Aigua calenta", @"water", @"Entitats d’aigua configurades"], @[@"media", @"Música i televisió", @"media", @"Reproductors configurats"],
                     @[@"fans", @"Ventiladors", @"fan", @"Ventiladors configurats"], @[@"switches", @"Interruptors", @"light", @"Interruptors configurats"],
                     @[@"scenes", @"Escenes", @"spark", @"Escenes configurades"], @[@"other", @"Altres dispositius", @"overview", @"Altres entitats configurades"]];
  NSMutableArray *cards = [NSMutableArray array];
  for(NSArray *item in items) {
    if(![GRLogic entities:self.model.entities inCategory:item[0]].count) { continue; }
    GRCardControl *card = [GRCardControl new];
    card.backgroundColor = t.card; card.layer.cornerRadius = 20; card.layer.borderWidth = 1; card.layer.borderColor = (t.night ? t.cardBorder : GRHexA(0xffffff, .8)).CGColor;
    card.accessibilityIdentifier = item[0]; card.accessibilityLabel = item[1];
    [card addTarget:self action:@selector(summaryTapped:) forControlEvents:UIControlEventTouchUpInside];
    UIImageView *icon = GRIconView(item[2], NO, t.summaryIcon);
    UILabel *name = GRLabel(item[1], GRFont(17, UIFontWeightMedium), t.text);
    UILabel *value = GRLabel(nil, GRFont(25, UIFontWeightLight), t.text);
    value.attributedText = GRKerned([GRLogic summaryValueForCategory:item[0] entities:self.model.entities connected:self.model.connected demo:self.model.demo], GRFont(25, UIFontWeightLight), t.text, -.5);
    UILabel *note = GRLabel(item[3], GRFont(12, UIFontWeightRegular), t.summaryNote);
    for(UIView *view in @[icon, name, value, note]) { view.userInteractionEnabled = NO; [card addSubview:view]; }
    GRBlockView *layout = [GRBlockView new];
    layout.userInteractionEnabled = NO; layout.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    layout.layout = ^(UIView *view) {
      CGFloat w = view.bounds.size.width - 44;
      icon.frame = CGRectMake(22, 22, 23, 23);
      name.frame = CGRectMake(22 + 23 + 10, 22, w - 33, 23);
      value.frame = CGRectMake(22, 22 + 23 + 12, w, 32);
      note.frame = CGRectMake(22, 22 + 23 + 12 + 32 + 2, w, 18);
    };
    [card addSubview:layout];
    [cards addObject:card];
  }
  GRBlockView *grid = [self gridWithItems:cards columns:2 gap:16 rowGap:16 itemHeight:^CGFloat(UIView *item, CGFloat width) { return 133; }];
  void (^layout)(UIView *) = grid.layout;
  grid.layout = ^(UIView *view) { layout(view); for(UIView *card in cards) { UIView *inner = card.subviews.lastObject; inner.frame = card.bounds; [inner setNeedsLayout]; [inner layoutIfNeeded]; } };
  [_viewFlow addView:grid top:14];
  __weak GRMainViewController *weakSelf = self;
  GRButton *all = [GRButton buttonWithTitle:@"Veure tots els dispositius" style:GRButtonStyleOutline handler:^(GRButton *button) {
    [weakSelf openCategory:@"all" title:@"Tots els dispositius"];
  }];
  [_viewFlow addView:all top:cards.count ? 26 : 0 fill:NO];
}

- (void)summaryTapped:(UIControl *)card {
  if([card.accessibilityIdentifier isEqualToString:@"climate"]) { [self navigate:@"climate"]; }
  else { [self openCategory:card.accessibilityIdentifier title:card.accessibilityLabel]; }
}

- (void)renderClimate {
  GRTheme *t = [GRTheme current];
  GRMetrics m = GRMetricsForWidth(self.view.bounds.size.width);
  NSArray *sensors = [GRLogic entities:self.model.entities inCategory:@"climate"];
  NSString *note = self.model.connected ? [NSString stringWithFormat:@"%lu %@", (unsigned long)sensors.count, sensors.count == 1 ? @"sensor configurat" : @"sensors configurats"] : @"Esperant connexió";
  [_viewFlow addView:[self sectionLabel:@"TEMPERATURA I HUMITAT" note:note] top:0];
  __weak GRMainViewController *weakSelf = self;
  if(sensors.count) {
    GRWrapView *periods = [GRWrapView new];
    periods.horizontalSpacing = 8; periods.verticalSpacing = 4;
    for(NSArray *period in @[@[@6, @"6 h"], @[@24, @"24 h"], @[@168, @"7 dies"], @[@720, @"1 mes"]]) {
      NSInteger hours = [period[0] integerValue];
      GRButton *button = [GRButton buttonWithTitle:period[1] style:GRButtonStylePeriod handler:^(GRButton *b) { [weakSelf.model changeClimatePeriod:hours]; }];
      button.selectedLook = self.model.historyHours == hours;
      button.accessibilityTraits = UIAccessibilityTraitButton | (button.selectedLook ? UIAccessibilityTraitSelected : 0);
      [periods addSubview:button];
    }
    GRFlowView *periodsRow = [GRFlowView new];
    periodsRow.insets = UIEdgeInsetsMake(0, 8, 0, 8);
    [periodsRow addView:periods];
    [_viewFlow addView:periodsRow top:14];
  }
  NSMutableArray *groups = [NSMutableArray array];
  for(NSDictionary *room in [GRLogic rooms]) { [groups addObject:room]; }
  [groups addObject:@{@"name": @"Sense habitació assignada"}];
  NSMutableArray *cards = [NSMutableArray array];
  for(NSDictionary *group in groups) {
    NSArray *matches = [GRLogic entities:sensors inRoom:group[@"id"]];
    if(!matches.count) { continue; }
    GRFlowView *card = [GRFlowView new];
    card.insets = UIEdgeInsetsMake(22, 22, 11, 22);
    card.backgroundColor = t.climateCard; card.layer.cornerRadius = 20; card.layer.borderWidth = 1; card.layer.borderColor = t.climateBorder.CGColor;
    UILabel *roomName = GRLabel(group[@"name"], GRFont(19, UIFontWeightMedium), t.text);
    roomName.accessibilityTraits = UIAccessibilityTraitHeader;
    [card addView:roomName top:0];
    BOOL firstReading = YES;
    for(NSDictionary *sensor in matches) {
      NSDictionary *attributes = GRDict(sensor[@"attributes"]) ?: @{};
      BOOL temperature = [attributes[@"device_class"] isEqual:@"temperature"];
      NSString *reading = [GRLogic climateReading:sensor connected:self.model.connected];
      GRFlowView *row = [GRFlowView new];
      row.insets = UIEdgeInsetsMake(11, 34, 11, 0);
      [row addView:[GRRuleView ruleWithColor:t.climateLine] top:-11];
      UIImageView *icon = GRIconView(temperature ? @"thermometer" : @"humidity", NO, t.climateIcon);
      [row addView:GRLabel(temperature ? @"Temperatura actual" : @"Humitat actual", GRFont(12, UIFontWeightRegular), t.climateKind) top:0];
      [row addView:GRLabel(reading, [UIFont monospacedDigitSystemFontOfSize:28 weight:UIFontWeightRegular], t.text) top:0];
      [row addView:GRLabel(GRStr(sensor[@"name"]), GRFont(11, UIFontWeightRegular), t.climateKind) top:0];
      if(![sensor[@"status"] isEqual:@"ok"] || !self.model.connected) {
        [row addView:GRLabel([GRLogic stateTextForEntity:sensor connected:self.model.connected demo:self.model.demo], GRFont(11, UIFontWeightRegular), t.climateIssue) top:0];
      } else if([reading isEqualToString:@"—"]) {
        [row addView:GRLabel(@"Lectura no vàlida", GRFont(11, UIFontWeightRegular), t.climateIssue) top:0];
      }
      NSArray *points = GRArray(self.model.historySeries[sensor[@"entity_id"]]) ?: @[];
      NSString *message = self.model.historyLoading ? @"Carregant l’historial…" : (self.model.historyError ?: @"Encara no hi ha historial disponible.");
      GRClimateChartView *chart = [[GRClimateChartView alloc] initWithPoints:points unit:GRStr(attributes[@"unit_of_measurement"]) ?: @""
                                                                    humidity:[attributes[@"device_class"] isEqual:@"humidity"]
                                                                        name:GRStr(sensor[@"name"]) ?: @"" message:message];
      GRBlockView *chartRow = [GRBlockView new];
      [chartRow addSubview:chart];
      chartRow.measure = ^CGFloat(CGFloat width) { return [chart heightForWidth:width + 34]; };
      chartRow.layout = ^(UIView *view) { chart.frame = CGRectMake(-34, 0, view.bounds.size.width + 34, view.bounds.size.height); };
      [row addView:chartRow top:14];
      [row addSubview:icon];
      icon.frame = CGRectMake(0, 14, 23, 23);
      [card addView:row top:firstReading ? 13 : 0];
      firstReading = NO;
    }
    [cards addObject:card];
  }
  if(!sensors.count) {
    GRFlowView *empty = [GRFlowView new];
    empty.insets = UIEdgeInsetsMake(26, 0, 26, 0);
    [empty addView:GRWrappingLabel(self.model.connected ? @"Encara no hi ha lectures ambientals." : @"Esperant dades de Home Assistant.", GRFont(21, UIFontWeightRegular), t.text, 0) top:0];
    [empty addView:GRWrappingLabel(self.model.connected ? @"Afegeix els IDs dels sensors de temperatura i humitat a entity_ids. Home Assistant ha de publicar device_class: temperature o humidity. Assigna cada sensor a una habitació amb room_assignments." : @"Quan es recuperi la connexió, apareixeran els sensors ambientals configurats.", GRFont(13, UIFontWeightRegular), t.infoText, 22) top:10];
    [_viewFlow addView:empty top:14];
    return;
  }
  NSInteger columns = m.narrow ? 1 : 2;
  GRBlockView *grid = [self gridWithItems:cards columns:columns gap:16 rowGap:16 itemHeight:^CGFloat(UIView *item, CGFloat width) { return [(GRFlowView *)item heightForWidth:width]; }];
  [_viewFlow addView:grid top:14];
}

#pragma mark - Modal drawer

- (void)layoutModal {
  CGSize size = self.view.bounds.size;
  _modalLayer.frame = self.view.bounds;
  _backdrop.frame = _modalLayer.bounds;
  if(!_modal) { return; }
  CGFloat top = [self statusBarHeight];
  CGRect frame;
  if([_modal[@"type"] isEqualToString:@"room"]) {
    CGFloat width = MIN(680, size.width - 36), height = MIN((size.height - top) * .8, size.height - top - 36);
    frame = CGRectMake((size.width - width) / 2, top + (size.height - top - height) / 2, width, height);
  } else {
    frame = CGRectMake(size.width - 18 - 440, top + 18, 440, size.height - top - 36);
  }
  _drawer.frame = frame;
  _drawer.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:_drawer.bounds cornerRadius:25].CGPath;
  UIView *clip = [_drawer viewWithTag:7];
  clip.frame = _drawer.bounds;
  CGFloat width = frame.size.width;
  _modalEyebrow.frame = CGRectMake(26, 26, width - 26 - 80, 14);
  _modalTitle.frame = CGRectMake(26, 26 + 14 + 8, width - 26 - 80, 38);
  _closeButton.frame = CGRectMake(width - 18 - 46, 30, 46, 46);
  _drawerLine.frame = CGRectMake(0, 109, width, 1);
  _modalScroll.frame = CGRectMake(0, 110, width, frame.size.height - 110);
  UIEdgeInsets inset = _modalScroll.contentInset;
  CGFloat overlap = _keyboardHeight > 0 ? MAX(0, CGRectGetMaxY(frame) - (size.height - _keyboardHeight)) : 0;
  inset.bottom = overlap;
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
  _modalEyebrow.attributedText = GRKerned(eyebrow, GRFont(10, UIFontWeightSemibold), t.muted, 2.4);
  _modalTitle.attributedText = GRKerned(title, GRFont(28, UIFontWeightRegular), t.text, -1.3);
  [_modalFlow removeFromSuperview];
  _modalFlow = [GRFlowView new];
  _modalFlow.insets = UIEdgeInsetsMake(0, 26, 28, 26);
  [_modalScroll addSubview:_modalFlow];
  _serverField = nil; _tokenField = nil; _alarmField = nil;
  if(changed) { _modalScroll.contentOffset = CGPointZero; }
  if(!wasOpen) {
    _modalLayer.hidden = NO; _modalLayer.alpha = 0;
    [self.view bringSubviewToFront:_modalLayer];
    [self.view bringSubviewToFront:_toastView];
    [UIView animateWithDuration:.18 animations:^{ self->_modalLayer.alpha = 1; }];
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
  [UIView animateWithDuration:.15 animations:^{ layer.alpha = 0; } completion:^(BOOL finished) {
    if(!self->_modal) {
      layer.hidden = YES;
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
  GRTheme *t = [GRTheme current];
  GRFlowView *parent = [self openModal:room[@"name"] eyebrow:@"LES HABITACIONS" type:@"room" modalId:roomId];
  UIImageView *art = [[UIImageView alloc] initWithImage:[UIImage imageNamed:[@"room-" stringByAppendingString:roomId]]];
  art.contentMode = UIViewContentModeScaleAspectFit;
  art.alpha = t.night ? .85 : 1;
  art.isAccessibilityElement = YES; art.accessibilityLabel = @"Il·lustració conceptual de l’estança";
  [parent addView:art top:12 height:190];
  NSArray *entities = [GRLogic entities:self.model.entities inRoom:roomId];
  if(entities.count) { [self addEntities:entities to:parent]; }
  else {
    [parent addView:GRWrappingLabel(@"Un espai per definir.", GRFont(21, UIFontWeightRegular), t.text, 0) top:38];
    [parent addView:GRWrappingLabel(@"Encara no s’ha confirmat quins dispositius hi ha en aquesta estança. Els pots consultar al resum general mentre completes la ubicació.", GRFont(13, UIFontWeightRegular), t.infoText, 22) top:10];
    __weak GRMainViewController *weakSelf = self;
    [parent addView:[GRButton buttonWithTitle:@"Veure dispositius" style:GRButtonStyleOutline handler:^(GRButton *b) { [weakSelf openCategory:@"all" title:@"Tots els dispositius"]; }] top:20 fill:NO];
  }
  [self finishModal];
}

- (void)openCategory:(NSString *)category title:(NSString *)title {
  GRFlowView *parent = [self openModal:title eyebrow:@"A CASA" type:@"category" modalId:category];
  NSArray *items = [category isEqualToString:@"all"] ? self.model.entities : [GRLogic entities:self.model.entities inCategory:category];
  if(!items.count) {
    [parent addView:GRWrappingLabel(@"Pendent de carregar l’inventari. Comprova la connexió amb el panell.", GRFont(13, UIFontWeightRegular), [GRTheme current].infoText, 22) top:26];
  }
  [self addEntities:items to:parent];
  [self finishModal];
}

- (UIView *)infoBox:(NSString *)text color:(UIColor *)color {
  GRTheme *t = [GRTheme current];
  GRFlowView *box = [GRFlowView new];
  box.insets = UIEdgeInsetsMake(16, 16, 16, 16);
  box.backgroundColor = t.infoBox; box.layer.cornerRadius = 12;
  [box addView:GRWrappingLabel(text, GRFont(13, UIFontWeightRegular), color ?: t.infoText, 22)];
  return box;
}

- (void)addEntities:(NSArray *)entities to:(GRFlowView *)parent {
  GRTheme *t = [GRTheme current];
  BOOL live = [self live];
  for(NSDictionary *entity in entities) {
    GRFlowView *item = [GRFlowView new];
    item.insets = UIEdgeInsetsMake(18, 0, 18, 0);
    UILabel *name = GRWrappingLabel(GRStr(entity[@"name"]) ?: entity[@"entity_id"], GRFont(15, UIFontWeightMedium), t.text, 0);
    if([entity[@"is_group"] isEqual:@YES]) {
      UILabel *badge = GRLabel(nil, GRFont(9, UIFontWeightRegular), t.text);
      badge.attributedText = GRKerned(@"GRUP", GRFont(9, UIFontWeightRegular), t.text, .6);
      badge.backgroundColor = t.groupBadge; badge.layer.cornerRadius = 4; badge.clipsToBounds = YES; badge.textAlignment = NSTextAlignmentCenter;
      GRBlockView *row = [GRBlockView new];
      [row addSubview:name]; [row addSubview:badge];
      row.measure = ^CGFloat(CGFloat width) { return MAX(20, ceil([name sizeThatFits:CGSizeMake(width - 50, CGFLOAT_MAX)].height)); };
      row.layout = ^(UIView *view) {
        CGFloat w = view.bounds.size.width;
        CGSize size = [name sizeThatFits:CGSizeMake(w - 50, CGFLOAT_MAX)];
        name.frame = CGRectMake(0, 0, ceil(MIN(size.width, w - 50)), ceil(size.height));
        badge.frame = CGRectMake(CGRectGetMaxX(name.frame) + 5, 2, 40, 16);
      };
      [item addView:row top:0];
    } else { [item addView:name top:0]; }
    BOOL issue = !([entity[@"status"] isEqual:@"ok"] && live);
    [item addView:GRWrappingLabel([GRLogic stateTextForEntity:entity connected:self.model.connected demo:self.model.demo], GRFont(12, UIFontWeightRegular), issue ? t.deviceIssue : t.deviceState, 0) top:5];
    NSString *attributes = [GRLogic attributeSummary:entity live:live];
    if(attributes) { [item addView:[self note:attributes] top:5]; }
    if(GRStr(entity[@"note"]).length) { [item addView:[self note:entity[@"note"]] top:2]; }
    if(GRStr(entity[@"inventory_area"]).length && !GRStr(entity[@"room"])) {
      [item addView:[self note:[NSString stringWithFormat:@"Àrea de l’inventari: %@ · ubicació física pendent", entity[@"inventory_area"]]] top:2];
    }
    NSArray *controls = GRArray(entity[@"controls"]) ?: @[];
    if(controls.count) {
      GRFlowView *group = [GRFlowView new];
      __block GRWrapView *buttons = nil;
      for(id control in controls) { if(GRDict(control)) { [self addControl:control entity:entity to:group buttons:&buttons]; } }
      [item addView:group top:9];
    } else if(![entity[@"domain"] isEqual:@"sensor"] && ![entity[@"domain"] isEqual:@"binary_sensor"]) {
      [item addView:[self note:@"Controls pendents de verificar."] top:5];
    }
    UILabel *identifier = GRWrappingLabel(entity[@"entity_id"], GRFont(10, UIFontWeightRegular), t.entityId, 0);
    identifier.lineBreakMode = NSLineBreakByCharWrapping;
    [item addView:identifier top:5];
    [parent addView:item top:0];
    [parent addView:[GRRuleView ruleWithColor:t.drawerLine] top:0];
  }
}

- (UILabel *)note:(NSString *)text { return GRWrappingLabel(text, GRFont(12, UIFontWeightRegular), [GRTheme current].deviceNote, 19); }

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
    UILabel *caption = GRLabel(nil, GRFont(12, UIFontWeightRegular), t.text);
    UISlider *slider = [UISlider new];
    slider.minimumValue = minimum.floatValue; slider.maximumValue = maximum.floatValue;
    slider.value = (current ?: minimum).floatValue;
    slider.enabled = enabled;
    slider.minimumTrackTintColor = t.primary;
    slider.accessibilityLabel = label;
    double (^snapped)(void) = ^double {
      double raw = minimum.doubleValue + round((slider.value - minimum.doubleValue) / step) * step;
      raw = MAX(minimum.doubleValue, MIN(maximum.doubleValue, raw));
      return round(raw * 1e9) / 1e9;
    };
    void (^updateLabel)(void) = ^{
      BOOL shown = hasValue || touched;
      caption.text = [NSString stringWithFormat:@"%@: %@%@", label, shown ? GRFormatNumber(snapped()) : @"tria un valor",
                      [action isEqualToString:@"color_temp_kelvin"] && shown ? @" K" : @""];
    };
    GRButton *apply = [GRButton buttonWithTitle:@"Aplica" style:GRButtonStyleAction handler:^(GRButton *b) {
      double value = snapped();
      act([action isEqualToString:@"set_percentage"] ? @(GRRound(value)) : (value == floor(value) ? @((long long)value) : @(value)));
    }];
    apply.enabled = enabled && hasValue;
    GROnEvent(slider, UIControlEventValueChanged, ^{ touched = YES; updateLabel(); apply.enabled = enabled; weakSelf.modalDirtyFlag = YES; });
    updateLabel();
    GRBlockView *row = [GRBlockView new];
    [row addSubview:slider]; [row addSubview:apply];
    row.measure = ^CGFloat(CGFloat width) { return 54; };
    row.layout = ^(UIView *view) {
      CGFloat w = view.bounds.size.width;
      slider.frame = CGRectMake(0, 0, w - 92, 44);
      apply.frame = CGRectMake(w - 82, 0, 82, 46);
    };
    [group addView:caption top:12];
    [group addView:row top:6];
  } else if([kind isEqualToString:@"select"]) {
    *buttons = nil;
    NSArray *options = GRArray(control[@"options"]) ?: @[];
    __block NSString *selected = GRStr(control[@"value"]);
    if(![options containsObject:selected]) { selected = GRStr(options.firstObject); }
    GRButton *field = [GRButton buttonWithTitle:nil style:GRButtonStyleAction handler:nil];
    field.backgroundColor = t.field; field.layer.borderColor = t.fieldBorder.CGColor;
    field.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    field.titleLabel.font = GRFont(16, UIFontWeightRegular);
    [field setTitleColor:t.fieldText forState:UIControlStateNormal];
    [field setTitle:[NSString stringWithFormat:@"%@  ▾", selected ?: @""] forState:UIControlStateNormal];
    field.contentEdgeInsets = UIEdgeInsetsMake(10, 12, 10, 12);
    field.enabled = enabled;
    field.backgroundColor = t.field;
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
    [group addView:GRLabel(label, GRFont(12, UIFontWeightRegular), t.text) top:12];
    [group addView:field top:10];
    [group addView:submit top:8 fill:NO];
  } else {
    if(!*buttons) { *buttons = [GRWrapView new]; [group addView:*buttons top:4]; }
    GRButton *button = [GRButton buttonWithTitle:label style:GRButtonStyleAction handler:^(GRButton *b) { act(nil); }];
    button.enabled = enabled;
    [*buttons addSubview:button];
  }
  if(!enabled && GRStr(control[@"reason"]).length) {
    *buttons = nil;
    [group addView:[self note:control[@"reason"]] top:4];
  }
}

- (void)setModalDirtyFlag:(BOOL)dirty { _modalDirty = dirty; }
- (BOOL)modalDirtyFlag { return _modalDirty; }

- (void)alarmPrompt:(NSDictionary *)entity control:(NSDictionary *)control {
  GRTheme *t = [GRTheme current];
  GRFlowView *parent = [self openModal:GRStr(control[@"label"]) ?: @"Alarma" eyebrow:@"SEGURETAT" type:@"alarm" modalId:entity[@"entity_id"]];
  [parent addView:[self infoBox:[NSString stringWithFormat:@"Estat actual: %@. Confirma l’ordre abans d’enviar-la.", [GRLogic stateTextForEntity:entity connected:self.model.connected demo:self.model.demo]] color:nil] top:18];
  if([control[@"requires_code"] isEqual:@YES]) {
    [parent addView:GRLabel(@"PIN de l’alarma", GRFont(12, UIFontWeightRegular), t.text) top:12];
    _alarmField = [self textField:nil placeholder:nil secure:YES];
    _alarmField.accessibilityLabel = @"PIN de l’alarma";
    [parent addView:_alarmField top:6 height:46];
    [parent addView:GRWrappingLabel(@"El PIN només s’envia amb aquesta ordre i s’esborra del camp immediatament.", GRFont(12, UIFontWeightRegular), t.muted, 19) top:6];
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
  [parent addView:submit top:18];
  [self finishModal];
}

- (void)sendAction:(NSDictionary *)entity control:(NSDictionary *)control value:(id)value code:(NSString *)code {
  if(self.model.busy || !self.model.connected || self.model.preview || ![control[@"enabled"] isEqual:@YES]) {
    [self toast:@"Aquest control encara no està disponible."];
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
  field.placeholder = placeholder;
  field.secureTextEntry = secure;
  field.font = GRFont(16, UIFontWeightRegular);
  field.textColor = t.fieldText;
  field.backgroundColor = t.field;
  field.layer.cornerRadius = 10; field.layer.borderWidth = 1; field.layer.borderColor = t.fieldBorder.CGColor;
  field.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 10)]; field.leftViewMode = UITextFieldViewModeAlways;
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
  section.insets = UIEdgeInsetsMake(23, 0, 23, 0);
  UILabel *heading = GRLabel(title, GRFont(17, UIFontWeightMedium), [GRTheme current].text);
  heading.accessibilityTraits = UIAccessibilityTraitHeader;
  [section addView:heading top:0];
  return section;
}

- (UIView *)switchRow:(NSString *)text on:(BOOL)on changed:(void (^)(BOOL on))changed {
  UISwitch *toggle = [UISwitch new];
  toggle.on = on;
  toggle.onTintColor = [GRTheme current].primary;
  toggle.tintColor = [GRTheme current].fieldBorder;
  __weak UISwitch *weakToggle = toggle;
  GROnEvent(toggle, UIControlEventValueChanged, ^{ changed(weakToggle.on); });
  toggle.accessibilityLabel = text;
  UILabel *label = GRWrappingLabel(text, GRFont(14, UIFontWeightRegular), [GRTheme current].text, 0);
  GRBlockView *row = [GRBlockView new];
  [row addSubview:toggle]; [row addSubview:label];
  row.measure = ^CGFloat(CGFloat width) { return 51; };
  row.layout = ^(UIView *view) {
    toggle.frame = CGRectMake(0, 10, 51, 31);
    label.frame = CGRectMake(63, 0, view.bounds.size.width - 63, 51);
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
  for(NSString *line in @[status, live, transport]) { [section addView:GRWrappingLabel(line, GRFont(12, UIFontWeightRegular), t.muted, 19) top:2]; }
  if(self.model.error.length && !self.model.connected) { [section addView:GRWrappingLabel(self.model.error, GRFont(12, UIFontWeightRegular), t.deviceIssue, 19) top:4]; }

  [section addView:GRLabel(@"Adreça del panell", GRFont(12, UIFontWeightRegular), t.text) top:16];
  _serverField = [self textField:preferences.serverURL placeholder:@"http://192.168.1.10:8099" secure:NO];
  _serverField.keyboardType = UIKeyboardTypeURL;
  _serverField.returnKeyType = UIReturnKeyNext;
  _serverField.accessibilityLabel = @"Adreça del panell";
  [section addView:_serverField top:6 height:46];
  [section addView:GRLabel(@"PIN del panell (el mateix que panel_pin)", GRFont(12, UIFontWeightRegular), t.text) top:12];
  _tokenField = [self textField:preferences.token placeholder:@"6 a 8 dígits" secure:YES];
  _tokenField.keyboardType = UIKeyboardTypeNumberPad;
  _tokenField.returnKeyType = UIReturnKeyDone;
  _tokenField.accessibilityLabel = @"PIN del panell";
  [section addView:_tokenField top:6 height:46];
  NSString *storage = !preferences.token.length ? @"El PIN es desa al clauer de l’iPad perquè l’app s’obri sense demanar-lo."
    : (preferences.tokenInKeychain ? @"PIN desat al clauer de l’iPad." : @"El clauer no està disponible amb aquesta signatura; el PIN es desa dins l’espai privat de l’app.");
  [section addView:GRWrappingLabel(storage, GRFont(12, UIFontWeightRegular), t.muted, 19) top:6];
  GRWrapView *buttons = [GRWrapView new];
  [buttons addSubview:[GRButton buttonWithTitle:@"Desa i connecta" style:GRButtonStyleAction handler:^(GRButton *b) { [weakSelf saveConnection]; }]];
  [buttons addSubview:[GRButton buttonWithTitle:@"Comprova la connexió" style:GRButtonStyleAction handler:^(GRButton *b) { [weakSelf checkConnection]; }]];
  [buttons addSubview:[GRButton buttonWithTitle:@"Informe de verificació" style:GRButtonStyleAction handler:^(GRButton *b) { [weakSelf showAudit]; }]];
  [section addView:buttons top:12];

  NSString *seen = self.model.client.untrustedFingerprint;
  if(seen.length && ![seen isEqualToString:preferences.pinnedFingerprint]) {
    [section addView:GRLabel(@"Certificat HTTPS no reconegut", GRFont(14, UIFontWeightMedium), t.deviceIssue) top:18];
    UILabel *print = GRWrappingLabel([@"Empremta SHA-256: " stringByAppendingString:seen], [UIFont fontWithName:@"Menlo" size:11] ?: GRFont(11, UIFontWeightRegular), t.text, 0);
    print.lineBreakMode = NSLineBreakByCharWrapping;
    [section addView:print top:6];
    [section addView:GRWrappingLabel(@"Compara-la amb l’empremta del certificat instal·lat a Home Assistant (/ssl) abans de confiar-hi. Si no coincideix, no continuïs.", GRFont(12, UIFontWeightRegular), t.muted, 19) top:6];
    [section addView:[GRButton buttonWithTitle:@"Confia en aquest certificat" style:GRButtonStyleAction handler:^(GRButton *b) {
      [GRPreferences shared].pinnedFingerprint = seen; [weakSelf connectFromPreferences];
    }] top:8 fill:NO];
  } else if(preferences.pinnedFingerprint.length) {
    UILabel *print = GRWrappingLabel([@"Certificat fixat · SHA-256: " stringByAppendingString:preferences.pinnedFingerprint], [UIFont fontWithName:@"Menlo" size:11] ?: GRFont(11, UIFontWeightRegular), t.muted, 0);
    print.lineBreakMode = NSLineBreakByCharWrapping;
    [section addView:print top:14];
    [section addView:[GRButton buttonWithTitle:@"Oblida el certificat fixat" style:GRButtonStyleAction handler:^(GRButton *b) {
      [GRPreferences shared].pinnedFingerprint = nil; [weakSelf connectFromPreferences];
    }] top:8 fill:NO];
  }
  return section;
}

- (void)openSettings {
  GRTheme *t = [GRTheme current];
  GRPreferences *preferences = [GRPreferences shared];
  GRFlowView *parent = [self openModal:@"Al teu gust." eyebrow:@"PREFERÈNCIES" type:@"settings" modalId:@"settings"];
  __weak GRMainViewController *weakSelf = self;
  BOOL needsSetup = _configurationMessage.length && !self.model.authenticated && !self.model.preview;
  if(needsSetup) {
    // The connection fields come first until the app can reach the panel.
    [parent addView:[self infoBox:_configurationMessage color:t.errorText] top:18];
    [parent addView:[self connectionSection] top:0];
    [parent addView:[GRRuleView ruleWithColor:t.drawerLine] top:0];
  }
  GRFlowView *section = [self settingsSection:@"Llum i color"];
  UIView *segmented = [UIView new];
  segmented.backgroundColor = t.segmented; segmented.layer.cornerRadius = 13;
  NSMutableArray *segments = [NSMutableArray array];
  for(NSArray *choice in @[@[@"auto", @"Automàtic"], @[@"day", @"Dia"], @[@"night", @"Nit"]]) {
    GRButton *button = [GRButton buttonWithTitle:choice[1] style:GRButtonStyleSegment handler:^(GRButton *b) { [weakSelf setThemeChoice:choice[0]]; [weakSelf openSettings]; }];
    button.selectedLook = [preferences.theme isEqualToString:choice[0]];
    button.accessibilityTraits = UIAccessibilityTraitButton | (button.selectedLook ? UIAccessibilityTraitSelected : 0);
    [segmented addSubview:button]; [segments addObject:button];
  }
  GRBlockView *segmentRow = [GRBlockView new];
  [segmentRow addSubview:segmented];
  segmentRow.measure = ^CGFloat(CGFloat width) { return 53; };
  segmentRow.layout = ^(UIView *view) {
    segmented.frame = view.bounds;
    CGFloat w = (view.bounds.size.width - 8) / 3;
    for(NSUInteger i = 0; i < segments.count; i++) { [segments[i] setFrame:CGRectMake(4 + i * w, 4, w, 45)]; }
  };
  [section addView:segmentRow top:13];
  [section addView:GRWrappingLabel(@"Automàtic: dia de 7 a 20 h, segons el rellotge de l’iPad.", GRFont(12, UIFontWeightRegular), t.muted, 19) top:8];
  [parent addView:section top:0];
  [parent addView:[GRRuleView ruleWithColor:t.drawerLine] top:0];

  section = [self settingsSection:@"Una vista lleugera"];
  [section addView:[self switchRow:@"Activa el contrast suau" on:preferences.glass changed:^(BOOL on) {
    [GRPreferences shared].glass = on; [weakSelf applyTheme];
  }] top:8];
  [section addView:GRWrappingLabel(@"Superfícies opaques i sense desenfocament, pensades per a l’iPad mini amb iOS 9.3.5.", GRFont(12, UIFontWeightRegular), t.muted, 19) top:4];
  [parent addView:section top:0];
  [parent addView:[GRRuleView ruleWithColor:t.drawerLine] top:0];

  section = [self settingsSection:@"Pantalla"];
  [section addView:[self switchRow:@"Mantén la pantalla encesa" on:preferences.keepAwake changed:^(BOOL on) {
    [GRPreferences shared].keepAwake = on; [UIApplication sharedApplication].idleTimerDisabled = on;
  }] top:8];
  [section addView:GRWrappingLabel(@"Útil si l’iPad queda fix a la paret i connectat al carregador.", GRFont(12, UIFontWeightRegular), t.muted, 19) top:4];
  [parent addView:section top:0];
  [parent addView:[GRRuleView ruleWithColor:t.drawerLine] top:0];

  if(!needsSetup) { [parent addView:[self connectionSection] top:0]; }
  [parent addView:[self infoBox:[NSString stringWithFormat:@"Glass Rooms %@ · App nativa per a iPad · Actualitzacions en directe de Home Assistant.", GRVersion] color:nil] top:18];
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
  [parent addView:[self infoBox:@"Informe de lectura per completar la configuració. No inclou credencials." color:nil] top:18];
  UITextView *output = [UITextView new];
  output.editable = NO;
  output.font = [UIFont fontWithName:@"Menlo" size:11] ?: GRFont(11, UIFontWeightRegular);
  output.textColor = t.text; output.backgroundColor = t.infoBox;
  output.layer.cornerRadius = 10; output.textContainerInset = UIEdgeInsetsMake(12, 8, 12, 8);
  output.text = reopening && _auditText ? _auditText : @"Carregant…";
  [parent addView:output top:0 height:360];
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
