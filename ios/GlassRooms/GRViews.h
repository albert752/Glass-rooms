// Glass Rooms for iOS 9: small UIKit building blocks with manual layout (no storyboards).
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

UIImage *_Nullable GRIcon(NSString *name, BOOL large);
UIImageView *GRIconView(NSString *name, BOOL large, UIColor *tint);
UILabel *GRLabel(NSString *_Nullable text, UIFont *font, UIColor *color);
UILabel *GRWrappingLabel(NSString *_Nullable text, UIFont *font, UIColor *color, CGFloat lineHeight);

// Colours a UISwitch with the theme: accent track when on, flat track when off.
void GRStyleSwitch(UISwitch *toggle);

typedef NS_ENUM(NSInteger, GRButtonStyle) {
  GRButtonStyleAction,    // hairline border, body text
  GRButtonStyleOutline,   // same look, larger corner
  GRButtonStylePrimary,   // accent fill
  GRButtonStylePeriod,
  GRButtonStyleSegment,
  GRButtonStylePlain
};

@interface GRButton : UIButton
+ (instancetype)buttonWithTitle:(nullable NSString *)title style:(GRButtonStyle)style handler:(nullable void (^)(GRButton *button))handler;
@property (nonatomic) GRButtonStyle style;
@property (nonatomic) BOOL selectedLook;
@property (nonatomic) CGFloat minimumHeight;
@property (nonatomic, copy, nullable) void (^handler)(GRButton *button);
- (void)applyTheme;
@end

// Vertical stack: each child receives the full width (or its natural width) and its fitting height.
@interface GRFlowView : UIView
@property (nonatomic) UIEdgeInsets insets;
- (void)addView:(UIView *)view;
- (void)addView:(UIView *)view top:(CGFloat)top;
- (void)addView:(UIView *)view top:(CGFloat)top fill:(BOOL)fill;
- (void)addView:(UIView *)view top:(CGFloat)top height:(CGFloat)height;
- (CGFloat)heightForWidth:(CGFloat)width;
@end

// Inline children that wrap onto new lines, like inline-block buttons.
@interface GRWrapView : UIView
@property (nonatomic) CGFloat horizontalSpacing, verticalSpacing;
- (CGFloat)heightForWidth:(CGFloat)width;
@end

// A view whose height is computed by a block (for custom rows).
@interface GRBlockView : UIView
@property (nonatomic, copy, nullable) CGFloat (^measure)(CGFloat width);
@property (nonatomic, copy, nullable) void (^layout)(UIView *view);
@end

// Runs a block for a control event; the control keeps the block alive.
void GROnEvent(UIControl *control, UIControlEvents events, void (^block)(void));

// Horizontal rule drawn as a one-pixel line.
@interface GRRuleView : UIView
+ (instancetype)ruleWithColor:(UIColor *)color;
@end

NS_ASSUME_NONNULL_END
