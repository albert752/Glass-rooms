// Glass Rooms for iOS 9: "Nit càlida" palettes. Night is pure black with amber; day is warm paper with burnt amber.
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

UIColor *GRHex(uint32_t rgb);
UIColor *GRHexA(uint32_t rgb, CGFloat alpha);

@interface GRTheme : NSObject
+ (GRTheme *)current;
+ (void)setNight:(BOOL)night;
@property (nonatomic, readonly) BOOL night;
// Surfaces: page, side drawer, dimmed backdrop behind the drawer, toast.
@property (nonatomic, readonly) UIColor *background, *panel, *backdrop, *toast, *toastText;
// Text: body, highlighted (clock, titles, lit rooms), secondary, problems.
@property (nonatomic, readonly) UIColor *text, *highlight, *muted, *issue;
// Accent fill and the text drawn on it.
@property (nonatomic, readonly) UIColor *accent, *onAccent;
// Hairlines between rows, borders of controls, unlit dots, switch track and thumb when off.
@property (nonatomic, readonly) UIColor *line, *edge, *faint, *track, *knob;
@property (nonatomic, readonly) UIColor *field, *temperatureLine, *humidityLine;
@end

UIFont *GRFont(CGFloat size, CGFloat weight);
UIFont *GRDigits(CGFloat size, CGFloat weight);
NSAttributedString *GRKerned(NSString *text, UIFont *font, UIColor *color, CGFloat kern);

NS_ASSUME_NONNULL_END
