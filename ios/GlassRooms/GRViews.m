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

void GRStyleSwitch(UISwitch *toggle) {
  GRTheme *t = [GRTheme current];
  toggle.onTintColor = t.accent;
  toggle.tintColor = t.track;
  toggle.backgroundColor = t.track;
  toggle.layer.cornerRadius = 15.5;
  toggle.thumbTintColor = toggle.on ? t.onAccent : t.knob;
}

@implementation GRButton

+ (instancetype)buttonWithTitle:(NSString *)title style:(GRButtonStyle)style handler:(void (^)(GRButton *))handler {
  GRButton *button = [GRButton buttonWithType:UIButtonTypeCustom];
  button.style = style;
  button.handler = handler;
  button.minimumHeight = style == GRButtonStylePrimary || style == GRButtonStyleOutline ? 52 : (style == GRButtonStylePeriod ? 40 : (style == GRButtonStyleSegment ? 45 : 46));
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
    case GRButtonStyleOutline: return UIEdgeInsetsMake(12, 20, 12, 20);
    case GRButtonStylePrimary: return UIEdgeInsetsMake(14, 20, 14, 20);
    case GRButtonStylePeriod: return UIEdgeInsetsMake(8, 15, 8, 15);
    case GRButtonStyleSegment: return UIEdgeInsetsMake(6, 8, 6, 8);
    case GRButtonStylePlain: return UIEdgeInsetsZero;
    default: return UIEdgeInsetsMake(11, 16, 11, 16);
  }
}

- (void)applyTheme {
  GRTheme *t = [GRTheme current];
  UIColor *background = [UIColor clearColor], *border = t.edge, *text = t.text;
  CGFloat radius = 14, size = 15, weight = UIFontWeightRegular;
  switch(self.style) {
    case GRButtonStyleAction: break;
    case GRButtonStyleOutline: radius = 16; size = 16; break;
    case GRButtonStylePrimary: background = t.accent; border = nil; text = t.onAccent; radius = 16; size = 16; weight = UIFontWeightSemibold; break;
    case GRButtonStylePeriod:
    case GRButtonStyleSegment:
      border = self.selectedLook ? t.accent : t.edge; text = self.selectedLook ? t.accent : t.muted; radius = 12; size = 14;
      weight = self.selectedLook ? UIFontWeightMedium : UIFontWeightRegular; break;
    case GRButtonStylePlain: border = nil; radius = 0; break;
  }
  self.backgroundColor = background;
  self.layer.cornerRadius = radius;
  self.layer.borderWidth = border ? 1 : 0;
  self.layer.borderColor = border.CGColor;
  if(self.style != GRButtonStylePlain) {
    self.titleLabel.font = GRFont(size, weight);
    [self setTitleColor:text forState:UIControlStateNormal];
    [self setTitleColor:text forState:UIControlStateDisabled];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.contentEdgeInsets = [self padding];
  }
  self.alpha = self.enabled ? 1 : .45;
}

- (void)setEnabled:(BOOL)enabled { [super setEnabled:enabled]; [self applyTheme]; }
- (void)setSelectedLook:(BOOL)selectedLook { _selectedLook = selectedLook; [self applyTheme]; }

- (void)setHighlighted:(BOOL)highlighted {
  [super setHighlighted:highlighted];
  if(self.style != GRButtonStylePlain) { self.alpha = !self.enabled ? .45 : (highlighted ? .65 : 1); }
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
