#import "GRTheme.h"

UIColor *GRHexA(uint32_t rgb, CGFloat alpha) {
  return [UIColor colorWithRed:((rgb >> 16) & 0xff) / 255.0 green:((rgb >> 8) & 0xff) / 255.0 blue:(rgb & 0xff) / 255.0 alpha:alpha];
}
UIColor *GRHex(uint32_t rgb) { return GRHexA(rgb, 1); }

UIFont *GRFont(CGFloat size, CGFloat weight) { return [UIFont systemFontOfSize:size weight:weight]; }
UIFont *GRDigits(CGFloat size, CGFloat weight) { return [UIFont monospacedDigitSystemFontOfSize:size weight:weight]; }

NSAttributedString *GRKerned(NSString *text, UIFont *font, UIColor *color, CGFloat kern) {
  return [[NSAttributedString alloc] initWithString:text ?: @"" attributes:@{NSFontAttributeName: font, NSForegroundColorAttributeName: color, NSKernAttributeName: @(kern)}];
}

static GRTheme *current;

@interface GRTheme ()
@property (nonatomic, readwrite) BOOL night;
@end

@implementation GRTheme

+ (GRTheme *)current {
  if(!current) { [self setNight:NO]; }
  return current;
}

+ (void)setNight:(BOOL)night {
  if(current && current.night == night) { return; }
  current = [[GRTheme alloc] initNight:night];
}

- (instancetype)initNight:(BOOL)night {
  if(!(self = [super init])) { return nil; }
  _night = night;
  if(night) {
    _background = GRHex(0x000000); _panel = GRHex(0x0d0a07); _backdrop = GRHexA(0x000000, .6);
    _toast = GRHex(0x1d1812); _toastText = GRHex(0xf2e6d6);
    _text = GRHex(0xf2e6d6); _highlight = GRHex(0xffcf99); _muted = GRHex(0x8c7c68); _issue = GRHex(0xe8866a);
    _accent = GRHex(0xffb766); _onAccent = GRHex(0x1a0f00);
    _line = GRHex(0x1d1812); _edge = GRHex(0x2c241b); _faint = GRHex(0x2c241b); _track = GRHex(0x1d1812); _knob = GRHex(0x5c4f40);
    _field = GRHex(0x0d0a07); _temperatureLine = GRHex(0xffb766); _humidityLine = GRHex(0x9fbcc0);
  } else {
    _background = GRHex(0xf5efe4); _panel = GRHex(0xfbf7f0); _backdrop = GRHexA(0x2b2016, .32);
    _toast = GRHex(0x2b2016); _toastText = GRHex(0xf5efe4);
    _text = GRHex(0x2b2016); _highlight = GRHex(0x7a3f0a); _muted = GRHex(0x86735c); _issue = GRHex(0xb24f26);
    _accent = GRHex(0xd9822b); _onAccent = GRHex(0xffffff);
    _line = GRHex(0xe4d9c6); _edge = GRHex(0xd8cab3); _faint = GRHex(0xd8cab3); _track = GRHex(0xe4d9c6); _knob = GRHex(0xffffff);
    _field = GRHex(0xfffcf6); _temperatureLine = GRHex(0xd9822b); _humidityLine = GRHex(0x5f8a96);
  }
  return self;
}

@end
