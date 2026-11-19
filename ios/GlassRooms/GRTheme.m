#import "GRTheme.h"
#import <CoreText/CoreText.h>

UIColor *GRHexA(uint32_t rgb, CGFloat alpha) {
  return [UIColor colorWithRed:((rgb >> 16) & 0xff) / 255.0 green:((rgb >> 8) & 0xff) / 255.0 blue:(rgb & 0xff) / 255.0 alpha:alpha];
}
UIColor *GRHex(uint32_t rgb) { return GRHexA(rgb, 1); }

static GRTheme *current;

// Jarvis reads as a condensed HUD typeface; Avenir Next Condensed ships with iOS 9.
static UIFont *GRJarvisFont(CGFloat size, CGFloat weight, BOOL digits) {
  NSString *name = weight <= -0.5 ? @"AvenirNextCondensed-UltraLight" : (weight < 0.2 ? @"AvenirNextCondensed-Regular"
    : (weight < 0.28 ? @"AvenirNextCondensed-Medium" : (weight < 0.45 ? @"AvenirNextCondensed-DemiBold" : @"AvenirNextCondensed-Bold")));
  UIFont *font = [UIFont fontWithName:name size:size];
  if(!font) { return nil; }
  if(digits) {
    UIFontDescriptor *descriptor = [font.fontDescriptor fontDescriptorByAddingAttributes:@{UIFontDescriptorFeatureSettingsAttribute:
      @[@{UIFontFeatureTypeIdentifierKey: @(kNumberSpacingType), UIFontFeatureSelectorIdentifierKey: @(kMonospacedNumbersSelector)}]}];
    font = [UIFont fontWithDescriptor:descriptor size:size];
  }
  return font;
}

UIFont *GRFont(CGFloat size, CGFloat weight) {
  if(current.jarvis) { UIFont *font = GRJarvisFont(size, weight, NO); if(font) { return font; } }
  return [UIFont systemFontOfSize:size weight:weight];
}
UIFont *GRDigits(CGFloat size, CGFloat weight) {
  if(current.jarvis) { UIFont *font = GRJarvisFont(size, weight, YES); if(font) { return font; } }
  return [UIFont monospacedDigitSystemFontOfSize:size weight:weight];
}

CGFloat GRRadius(CGFloat radius) { return current.jarvis ? MIN(radius, 4) : radius; }

void GRGlow(CALayer *layer, UIColor *color, CGFloat radius) {
  CGFloat glow = [GRTheme current].glow;
  layer.shadowColor = color.CGColor;
  layer.shadowOffset = CGSizeZero;
  layer.shadowRadius = radius;
  layer.shadowOpacity = (float)glow;
}

NSAttributedString *GRKerned(NSString *text, UIFont *font, UIColor *color, CGFloat kern) {
  return [[NSAttributedString alloc] initWithString:text ?: @"" attributes:@{NSFontAttributeName: font, NSForegroundColorAttributeName: color, NSKernAttributeName: @(kern)}];
}

@interface GRTheme ()
@property (nonatomic, readwrite) BOOL night;
@property (nonatomic, readwrite, copy) NSString *style;
@end

@implementation GRTheme

+ (GRTheme *)current {
  if(!current) { [self setStyle:@"warm" night:NO]; }
  return current;
}

+ (void)setNight:(BOOL)night { [self setStyle:current.style ?: @"warm" night:night]; }

+ (void)setStyle:(NSString *)style night:(BOOL)night {
  style = [style isEqualToString:@"jarvis"] ? @"jarvis" : @"warm";
  if(current && current.night == night && [current.style isEqualToString:style]) { return; }
  current = [[GRTheme alloc] initStyle:style night:night];
}

- (BOOL)jarvis { return [_style isEqualToString:@"jarvis"]; }

- (instancetype)initStyle:(NSString *)style night:(BOOL)night {
  if(!(self = [super init])) { return nil; }
  _night = night;
  _style = [style copy];
  _grid = [UIColor clearColor];
  _glow = 0;
  if([style isEqualToString:@"jarvis"] && night) {
    _background = GRHex(0x02070d); _panel = GRHex(0x051320); _backdrop = GRHexA(0x000000, .65);
    _toast = GRHex(0x0a1c2a); _toastText = GRHex(0xd8f6ff);
    _text = GRHex(0xcfeefa); _highlight = GRHex(0x8beaff); _muted = GRHex(0x5a8ba0); _issue = GRHex(0xff5a4e);
    _accent = GRHex(0x22d3ff); _onAccent = GRHex(0x001018); _section = GRHex(0x22d3ff);
    _line = GRHex(0x0b2433); _edge = GRHex(0x16506d); _faint = GRHex(0x16506d); _track = GRHex(0x0b2433); _knob = GRHex(0x2d6a85);
    _field = GRHex(0x041019); _temperatureLine = GRHex(0x22d3ff); _humidityLine = GRHex(0xffb547);
    _grid = GRHexA(0x22d3ff, .07); _glow = .85; _good = GRHex(0x3dffa8);
  } else if([style isEqualToString:@"jarvis"]) {
    _background = GRHex(0xe9f3f7); _panel = GRHex(0xf5fafc); _backdrop = GRHexA(0x0b2433, .3);
    _toast = GRHex(0x0b2433); _toastText = GRHex(0xe9f3f7);
    _text = GRHex(0x0b2433); _highlight = GRHex(0x005f86); _muted = GRHex(0x5b7c8c); _issue = GRHex(0xc0392b);
    _accent = GRHex(0x0090c0); _onAccent = GRHex(0xffffff); _section = GRHex(0x0077a0);
    _line = GRHex(0xcfe2ea); _edge = GRHex(0xa9cbd8); _faint = GRHex(0xa9cbd8); _track = GRHex(0xcfe2ea); _knob = GRHex(0xffffff);
    _field = GRHex(0xffffff); _temperatureLine = GRHex(0x0090c0); _humidityLine = GRHex(0xc77d00);
    _grid = GRHexA(0x0090c0, .08); _glow = .25; _good = GRHex(0x0a8a5a);
  } else if(night) {
    _background = GRHex(0x000000); _panel = GRHex(0x0d0a07); _backdrop = GRHexA(0x000000, .6);
    _toast = GRHex(0x1d1812); _toastText = GRHex(0xf2e6d6);
    _text = GRHex(0xf2e6d6); _highlight = GRHex(0xffcf99); _muted = GRHex(0x8c7c68); _issue = GRHex(0xe8866a);
    _accent = GRHex(0xffb766); _onAccent = GRHex(0x1a0f00); _section = _muted;
    _line = GRHex(0x1d1812); _edge = GRHex(0x2c241b); _faint = GRHex(0x2c241b); _track = GRHex(0x1d1812); _knob = GRHex(0x5c4f40);
    _field = GRHex(0x0d0a07); _temperatureLine = GRHex(0xffb766); _humidityLine = GRHex(0x9fbcc0); _good = GRHex(0x9ccf7a);
  } else {
    _background = GRHex(0xf5efe4); _panel = GRHex(0xfbf7f0); _backdrop = GRHexA(0x2b2016, .32);
    _toast = GRHex(0x2b2016); _toastText = GRHex(0xf5efe4);
    _text = GRHex(0x2b2016); _highlight = GRHex(0x7a3f0a); _muted = GRHex(0x86735c); _issue = GRHex(0xb24f26);
    _accent = GRHex(0xd9822b); _onAccent = GRHex(0xffffff); _section = _muted;
    _line = GRHex(0xe4d9c6); _edge = GRHex(0xd8cab3); _faint = GRHex(0xd8cab3); _track = GRHex(0xe4d9c6); _knob = GRHex(0xffffff);
    _field = GRHex(0xfffcf6); _temperatureLine = GRHex(0xd9822b); _humidityLine = GRHex(0x5f8a96); _good = GRHex(0x4f7d3a);
  }
  return self;
}

@end
