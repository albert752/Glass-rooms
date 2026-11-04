// Glass Rooms for iOS 9: day and night palettes taken from glass_rooms/www/style.css.
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

UIColor *GRHex(uint32_t rgb);
UIColor *GRHexA(uint32_t rgb, CGFloat alpha);

@interface GRTheme : NSObject
+ (GRTheme *)current;
+ (void)setNight:(BOOL)night glass:(BOOL)glass;
@property (nonatomic, readonly) BOOL night, glass;
@property (nonatomic, readonly) NSArray<UIColor *> *backgroundStops;
@property (nonatomic, readonly) UIColor *text, *rail, *railBorder, *nav, *navActive, *navActiveBackground, *brandBorder, *brandFill, *brandFillStrong;
@property (nonatomic, readonly) UIColor *muted, *subtitle, *sectionLabel, *sectionNote, *footer, *leaf, *timeIcon;
@property (nonatomic, readonly) UIColor *card, *cardBorder, *cardLit, *cardLitBorder, *cardDark, *cardDarkBorder, *meta, *metaBorder, *metaIssue, *dot, *dotIssue;
@property (nonatomic, readonly) UIColor *bulbLit, *bulbLitBackground, *bulbDark, *bulbDarkBackground;
@property (nonatomic, readonly) UIColor *allLights, *allLightsBorder, *allLightsText, *allLightsOn, *allLightsOnBorder, *allLightsOnText;
@property (nonatomic, readonly) UIColor *summaryIcon, *summaryNote, *outline, *outlineBorder, *outlineText;
@property (nonatomic, readonly) UIColor *climateCard, *climateBorder, *climateLine, *climateIcon, *climateKind, *climateIssue;
@property (nonatomic, readonly) UIColor *period, *periodBorder, *periodText, *periodSelected, *periodSelectedBorder;
@property (nonatomic, readonly) UIColor *chart, *chartBorder, *chartAxis, *chartEndpoints, *chartSelected, *temperatureLine, *humidityLine, *markerStroke;
@property (nonatomic, readonly) UIColor *drawer, *drawerBorder, *drawerLine, *backdrop, *iconButton, *infoBox, *infoText, *segmented, *segmentedSelected, *segmentedSelectedText;
@property (nonatomic, readonly) UIColor *deviceState, *deviceIssue, *deviceNote, *entityId, *groupBadge;
@property (nonatomic, readonly) UIColor *action, *actionBorder, *actionText, *actionDisabled, *actionDisabledBorder, *field, *fieldBorder, *fieldText;
@property (nonatomic, readonly) UIColor *primary, *toast, *errorText;
@end

UIFont *GRFont(CGFloat size, CGFloat weight);
NSAttributedString *GRKerned(NSString *text, UIFont *font, UIColor *color, CGFloat kern);

NS_ASSUME_NONNULL_END
