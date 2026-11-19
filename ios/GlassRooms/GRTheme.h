// Glass Rooms for iOS 9: two styles, each with a day and a night palette.
// "warm" (Nit càlida): night is pure black with amber; day is warm paper with burnt amber.
// "jarvis": a heads-up display; night is deep blue-black with glowing cyan, day is pale glass with deep cyan.
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

UIColor *GRHex(uint32_t rgb);
UIColor *GRHexA(uint32_t rgb, CGFloat alpha);

@interface GRTheme : NSObject
+ (GRTheme *)current;
+ (void)setNight:(BOOL)night;
+ (void)setStyle:(NSString *)style night:(BOOL)night;
@property (nonatomic, readonly) BOOL night;
@property (nonatomic, readonly, copy) NSString *style; // warm or jarvis
@property (nonatomic, readonly) BOOL jarvis;
// Surfaces: page, side drawer, dimmed backdrop behind the drawer, toast.
@property (nonatomic, readonly) UIColor *background, *panel, *backdrop, *toast, *toastText;
// Text: body, highlighted (clock, titles, lit rooms), secondary, problems, section headings.
@property (nonatomic, readonly) UIColor *text, *highlight, *muted, *issue, *section;
// Accent fill and the text drawn on it.
@property (nonatomic, readonly) UIColor *accent, *onAccent;
// Hairlines between rows, borders of controls, unlit dots, switch track and thumb when off.
@property (nonatomic, readonly) UIColor *line, *edge, *faint, *track, *knob;
@property (nonatomic, readonly) UIColor *field, *temperatureLine, *humidityLine;
// Something favourable (a cheap electricity hour).
@property (nonatomic, readonly) UIColor *good;
// Jarvis only: background grid and rings (clear in the warm style) and the glow strength (0 = none).
@property (nonatomic, readonly) UIColor *grid;
@property (nonatomic, readonly) CGFloat glow;
@end

UIFont *GRFont(CGFloat size, CGFloat weight);
UIFont *GRDigits(CGFloat size, CGFloat weight);
// Corner radius for the current style: Jarvis uses near-square corners.
CGFloat GRRadius(CGFloat radius);
// Adds the style's glow (a coloured shadow) to a layer, or removes it.
void GRGlow(CALayer *layer, UIColor *color, CGFloat radius);
NSAttributedString *GRKerned(NSString *text, UIFont *font, UIColor *color, CGFloat kern);

NS_ASSUME_NONNULL_END
