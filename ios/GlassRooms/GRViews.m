#import "GRViews.h"
#import "GRTheme.h"
#import <objc/runtime.h>

UIImage *GRIcon(NSString *name, BOOL large) {
  NSString *file = [NSString stringWithFormat:@"icon-%@%@", name, large ? @"-large" : @""];
  return [[UIImage imageNamed:file] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

UIImageView *GRIconView(NSString *name, BOOL large, UIColor *tint) {
  UIImageView *view = [[UIImageView alloc] initWithImage:GRIcon(name, large)];
  view.tintColor = tint;
  view.contentMode = UIViewContentModeScaleAspectFit;
  return view;
}

UILabel *GRLabel(NSString *text, UIFont *font, UIColor *color) {
  UILabel *label = [UILabel new];
  label.text = text; label.font = font; label.textColor = color;
  label.backgroundColor = [UIColor clearColor];
  return label;
}

UILabel *GRWrappingLabel(NSString *text, UIFont *font, UIColor *color, CGFloat lineHeight) {
  UILabel *label = GRLabel(nil, font, color);
  label.numberOfLines = 0;
  NSMutableParagraphStyle *paragraph = [NSMutableParagraphStyle new];
  if(lineHeight > 0) { paragraph.minimumLineHeight = lineHeight; paragraph.maximumLineHeight = lineHeight; }
  label.attributedText = [[NSAttributedString alloc] initWithString:text ?: @"" attributes:@{NSFontAttributeName: font, NSForegroundColorAttributeName: color, NSParagraphStyleAttributeName: paragraph}];
  return label;
}

@implementation GRBackgroundView
- (instancetype)initWithFrame:(CGRect)frame {
  if((self = [super initWithFrame:frame])) { self.contentMode = UIViewContentModeRedraw; self.opaque = YES; }
  return self;
}
- (void)drawRect:(CGRect)rect {
  NSArray<UIColor *> *stops = [GRTheme current].backgroundStops;
  CGContextRef context = UIGraphicsGetCurrentContext();
  CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
  CGFloat locations[3] = {0, .45, 1};
  NSArray *colors = @[(__bridge id)stops[0].CGColor, (__bridge id)stops[1].CGColor, (__bridge id)stops[2].CGColor];
  CGGradientRef gradient = CGGradientCreateWithColors(space, (__bridge CFArrayRef)colors, locations);
  // radial-gradient(ellipse at 85% 0%): farthest-corner ellipse, scaled from a circle.
  CGSize size = self.bounds.size;
  CGPoint centre = CGPointMake(size.width * .85, 0);
  CGFloat rx = MAX(centre.x, size.width - centre.x) * M_SQRT2, ry = size.height * M_SQRT2;
  CGContextSaveGState(context);
  CGContextTranslateCTM(context, centre.x, centre.y);
  CGContextScaleCTM(context, 1, ry / rx);
  CGContextDrawRadialGradient(context, gradient, CGPointZero, 0, CGPointZero, rx, kCGGradientDrawsAfterEndLocation);
  CGContextRestoreGState(context);
  CGGradientRelease(gradient);
  CGColorSpaceRelease(space);
}
@end

@implementation GRButton

+ (instancetype)buttonWithTitle:(NSString *)title style:(GRButtonStyle)style handler:(void (^)(GRButton *))handler {
  GRButton *button = [GRButton buttonWithType:UIButtonTypeCustom];
  button.style = style;
  button.handler = handler;
  button.minimumHeight = style == GRButtonStylePrimary ? 48 : (style == GRButtonStylePeriod ? 42 : (style == GRButtonStyleSegment ? 45 : 46));
  button.titleLabel.numberOfLines = 0;
  button.adjustsImageWhenHighlighted = NO;
  [button setTitle:title forState:UIControlStateNormal];
  [button addTarget:button action:@selector(tapped) forControlEvents:UIControlEventTouchUpInside];
  [button applyTheme];
  return button;
}

- (void)tapped { if(self.handler) { self.handler(self); } }

- (UIEdgeInsets)padding {
  switch(self.style) {
    case GRButtonStyleOutline: return UIEdgeInsetsMake(10, 17, 10, 17);
    case GRButtonStylePrimary: return UIEdgeInsetsMake(13, 18, 13, 18);
    case GRButtonStylePeriod: return UIEdgeInsetsMake(8, 14, 8, 14);
    case GRButtonStyleSegment: return UIEdgeInsetsMake(6, 8, 6, 8);
    case GRButtonStylePlain: return UIEdgeInsetsZero;
    default: return UIEdgeInsetsMake(10, 14, 10, 14);
  }
}

- (void)applyTheme {
  GRTheme *t = [GRTheme current];
  UIColor *background = [UIColor clearColor], *border = nil, *text = t.text;
  CGFloat radius = 10, size = 12, weight = UIFontWeightRegular;
  switch(self.style) {
    case GRButtonStyleAction:
      background = self.enabled ? t.action : t.actionDisabled; border = self.enabled ? t.actionBorder : t.actionDisabledBorder; text = t.actionText; break;
    case GRButtonStyleOutline: background = t.outline; border = t.outlineBorder; text = t.outlineText; radius = 14; break;
    case GRButtonStylePrimary: background = t.primary; text = [UIColor whiteColor]; radius = 11; size = 14; break;
    case GRButtonStylePeriod:
      background = self.selectedLook ? t.periodSelected : t.period; border = self.selectedLook ? t.periodSelectedBorder : t.periodBorder;
      text = t.periodText; radius = 11; size = 13; weight = self.selectedLook ? UIFontWeightSemibold : UIFontWeightRegular; break;
    case GRButtonStyleSegment:
      background = self.selectedLook ? t.segmentedSelected : [UIColor clearColor];
      text = self.selectedLook ? t.segmentedSelectedText : t.text; size = 13; break;
    case GRButtonStylePlain: radius = 0; size = 15; break;
  }
  self.backgroundColor = background;
  self.layer.cornerRadius = radius;
  self.layer.borderWidth = border ? 1 : 0;
  self.layer.borderColor = border.CGColor;
  if(self.style == GRButtonStyleSegment && self.selectedLook) {
    self.layer.shadowColor = [UIColor blackColor].CGColor; self.layer.shadowOpacity = .06; self.layer.shadowRadius = 2; self.layer.shadowOffset = CGSizeMake(0, 2);
  } else { self.layer.shadowOpacity = 0; }
  if(self.style != GRButtonStylePlain) {
    self.titleLabel.font = GRFont(size, weight);
    [self setTitleColor:text forState:UIControlStateNormal];
    [self setTitleColor:text forState:UIControlStateDisabled];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.contentEdgeInsets = [self padding];
  }
  self.alpha = self.enabled ? 1 : .52;
}

- (void)setEnabled:(BOOL)enabled { [super setEnabled:enabled]; [self applyTheme]; }
- (void)setSelectedLook:(BOOL)selectedLook { _selectedLook = selectedLook; [self applyTheme]; }

- (void)setHighlighted:(BOOL)highlighted {
  [super setHighlighted:highlighted];
  if(self.style != GRButtonStylePlain) { self.alpha = !self.enabled ? .52 : (highlighted ? .7 : 1); }
}

- (CGSize)sizeThatFits:(CGSize)size {
  UIEdgeInsets padding = self.contentEdgeInsets;
  CGFloat maxWidth = MAX(1, size.width - padding.left - padding.right);
  CGSize text = [self.titleLabel sizeThatFits:CGSizeMake(maxWidth, CGFLOAT_MAX)];
  CGFloat width = MIN(size.width, ceil(text.width) + padding.left + padding.right);
  return CGSizeMake(width, MAX(self.minimumHeight, ceil(text.height) + padding.top + padding.bottom));
}

@end

@interface GRFlowItem : NSObject
@property (nonatomic, weak) UIView *view;
@property (nonatomic) CGFloat top, height;
@property (nonatomic) BOOL fill;
@end
@implementation GRFlowItem
@end

static CGFloat GRFittingHeight(UIView *view, CGFloat width) {
  if([view respondsToSelector:@selector(heightForWidth:)]) { return [(GRFlowView *)view heightForWidth:width]; }
  return ceil([view sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)].height);
}

@implementation GRFlowView {
  NSMutableArray<GRFlowItem *> *_items;
}

- (instancetype)initWithFrame:(CGRect)frame {
  if((self = [super initWithFrame:frame])) { _items = [NSMutableArray array]; }
  return self;
}

- (void)addView:(UIView *)view { [self addView:view top:0 fill:YES]; }
- (void)addView:(UIView *)view top:(CGFloat)top { [self addView:view top:top fill:YES]; }
- (void)addView:(UIView *)view top:(CGFloat)top fill:(BOOL)fill {
  GRFlowItem *item = [GRFlowItem new];
  item.view = view; item.top = top; item.fill = fill;
  [_items addObject:item];
  [self addSubview:view];
  [self setNeedsLayout];
}
- (void)addView:(UIView *)view top:(CGFloat)top height:(CGFloat)height {
  [self addView:view top:top fill:YES];
  _items.lastObject.height = height;
}

- (CGFloat)layoutForWidth:(CGFloat)width apply:(BOOL)apply {
  CGFloat inner = MAX(0, width - self.insets.left - self.insets.right), y = self.insets.top;
  for(GRFlowItem *item in _items) {
    UIView *view = item.view;
    if(!view || view.hidden) { continue; }
    CGFloat w = inner, h;
    if(!item.fill) { w = MIN(inner, ceil([view sizeThatFits:CGSizeMake(inner, CGFLOAT_MAX)].width)); }
    h = item.height > 0 ? item.height : GRFittingHeight(view, w);
    y += item.top;
    if(apply) { view.frame = CGRectMake(self.insets.left, y, w, h); }
    y += h;
  }
  return ceil(y + self.insets.bottom);
}

- (CGFloat)heightForWidth:(CGFloat)width { return [self layoutForWidth:width apply:NO]; }
- (CGSize)sizeThatFits:(CGSize)size { return CGSizeMake(size.width, [self heightForWidth:size.width]); }
- (void)layoutSubviews { [super layoutSubviews]; [self layoutForWidth:self.bounds.size.width apply:YES]; }

@end

@implementation GRWrapView

- (instancetype)initWithFrame:(CGRect)frame {
  if((self = [super initWithFrame:frame])) { _horizontalSpacing = 6; _verticalSpacing = 8; }
  return self;
}

- (CGFloat)layoutForWidth:(CGFloat)width apply:(BOOL)apply {
  CGFloat x = 0, y = 0, lineHeight = 0;
  for(UIView *view in self.subviews) {
    if(view.hidden) { continue; }
    CGSize size = [view sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)];
    size.width = MIN(width, ceil(size.width)); size.height = ceil(size.height);
    if(x > 0 && x + size.width > width) { x = 0; y += lineHeight + self.verticalSpacing; lineHeight = 0; }
    if(apply) { view.frame = CGRectMake(x, y, size.width, size.height); }
    x += size.width + self.horizontalSpacing;
    lineHeight = MAX(lineHeight, size.height);
  }
  return y + lineHeight;
}

- (CGFloat)heightForWidth:(CGFloat)width { return [self layoutForWidth:width apply:NO]; }
- (CGSize)sizeThatFits:(CGSize)size { return CGSizeMake(size.width, [self heightForWidth:size.width]); }
- (void)layoutSubviews { [super layoutSubviews]; [self layoutForWidth:self.bounds.size.width apply:YES]; }

@end

@implementation GRBlockView
- (CGFloat)heightForWidth:(CGFloat)width { return self.measure ? self.measure(width) : 0; }
- (CGSize)sizeThatFits:(CGSize)size { return CGSizeMake(size.width, [self heightForWidth:size.width]); }
- (void)layoutSubviews { [super layoutSubviews]; if(self.layout) { self.layout(self); } }
@end

@implementation GRRuleView
+ (instancetype)ruleWithColor:(UIColor *)color {
  GRRuleView *rule = [GRRuleView new];
  rule.backgroundColor = color;
  return rule;
}
- (CGSize)sizeThatFits:(CGSize)size { return CGSizeMake(size.width, 1); }
@end

@interface GRActionTarget : NSObject
@property (nonatomic, copy) void (^block)(void);
@end
@implementation GRActionTarget
- (void)fire { if(self.block) { self.block(); } }
@end

void GROnEvent(UIControl *control, UIControlEvents events, void (^block)(void)) {
  GRActionTarget *target = [GRActionTarget new];
  target.block = block;
  [control addTarget:target action:@selector(fire) forControlEvents:events];
  objc_setAssociatedObject(control, (__bridge const void *)target, target, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
