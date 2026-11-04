#import "GRTheme.h"

UIColor *GRHexA(uint32_t rgb, CGFloat alpha) {
  return [UIColor colorWithRed:((rgb >> 16) & 0xff) / 255.0 green:((rgb >> 8) & 0xff) / 255.0 blue:(rgb & 0xff) / 255.0 alpha:alpha];
}
UIColor *GRHex(uint32_t rgb) { return GRHexA(rgb, 1); }

UIFont *GRFont(CGFloat size, CGFloat weight) { return [UIFont systemFontOfSize:size weight:weight]; }

NSAttributedString *GRKerned(NSString *text, UIFont *font, UIColor *color, CGFloat kern) {
  return [[NSAttributedString alloc] initWithString:text ?: @"" attributes:@{NSFontAttributeName: font, NSForegroundColorAttributeName: color, NSKernAttributeName: @(kern)}];
}

static GRTheme *current;

@interface GRTheme ()
@property (nonatomic, readwrite) BOOL night, glass;
@end

@implementation GRTheme

+ (GRTheme *)current {
  if(!current) { [self setNight:NO glass:NO]; }
  return current;
}

+ (void)setNight:(BOOL)night glass:(BOOL)glass {
  if(current && current.night == night && current.glass == glass) { return; }
  current = [[GRTheme alloc] initNight:night glass:glass];
}

- (instancetype)initNight:(BOOL)night glass:(BOOL)glass {
  if(!(self = [super init])) { return nil; }
  _night = night; _glass = glass;
  // Shared accents (the lit bulb keeps its warm colours at night, like the web panel).
  _bulbLit = GRHex(0x8a6730); _bulbLitBackground = GRHexA(0xf6e5bb, .62);
  _temperatureLine = GRHex(0xbd7958); _humidityLine = GRHex(0x668ca1); _markerStroke = GRHex(0x546e67);
  _backdrop = GRHexA(0x273123, .24); _primary = GRHex(0x748561); _toast = GRHex(0x414d36); _errorText = GRHex(0xa45c42);
  if(!night) {
    _backgroundStops = @[GRHex(0xf9f5eb), GRHex(0xeeece3), GRHex(0xe5e6dc)];
    _text = GRHex(0x383d35); _rail = glass ? GRHex(0xfaf9f2) : GRHex(0xf3f3e9); _railBorder = GRHexA(0xffffff, .65);
    _nav = GRHex(0x7c8174); _navActive = GRHex(0x4e5b40); _navActiveBackground = GRHex(0xe0e5d6);
    _brandBorder = GRHex(0x747c65); _brandFill = GRHexA(0x7b8b66, .12); _brandFillStrong = GRHex(0x889477);
    _muted = GRHex(0x8a917e); _subtitle = GRHex(0x858a7e); _sectionLabel = GRHex(0x777d6d); _sectionNote = GRHex(0x969b8c);
    _footer = GRHex(0x919785); _leaf = GRHex(0x7c8b68); _timeIcon = GRHex(0x939477);
    _card = glass ? GRHex(0xfaf9f2) : GRHex(0xf8f8f0); _cardBorder = GRHexA(0xffffff, .86);
    _cardLit = GRHex(0xfff8e9); _cardLitBorder = GRHex(0xead4a1); _cardDark = GRHex(0xe7eae5); _cardDarkBorder = GRHex(0xd2d9d0);
    _meta = GRHex(0x717966); _metaBorder = GRHexA(0xb6bea6, .22); _metaIssue = GRHex(0x92794c); _dot = GRHex(0xa4ab94); _dotIssue = GRHex(0xb9955a);
    _bulbDark = GRHex(0x52645a); _bulbDarkBackground = GRHexA(0xe1e7e2, .62);
    _allLights = GRHex(0xe7ece2); _allLightsBorder = GRHex(0xc9d2c3); _allLightsText = GRHex(0x405548);
    _allLightsOn = GRHex(0xf6e5bb); _allLightsOnBorder = GRHex(0xe5c989); _allLightsOnText = GRHex(0x715228);
    _summaryIcon = GRHex(0x89947a); _summaryNote = GRHex(0x858c79);
    _outline = GRHexA(0xffffff, .23); _outlineBorder = GRHex(0xcbd0bf); _outlineText = _text;
    _climateCard = GRHex(0xf8f8f0); _climateBorder = GRHex(0xdce2d2); _climateLine = GRHex(0xe1e5d9); _climateIcon = GRHex(0x758c84);
    _climateKind = GRHex(0x7e897c); _climateIssue = GRHex(0xa47848);
    _period = GRHex(0xf8f8f0); _periodBorder = GRHex(0xcbd2c4); _periodText = GRHex(0x52634f); _periodSelected = GRHex(0xdfe9da); _periodSelectedBorder = GRHex(0x91aa8d);
    _chart = GRHex(0xfdfdf8); _chartBorder = GRHex(0xe1e5d9); _chartAxis = GRHex(0xd5ddd2); _chartEndpoints = GRHex(0x7e897c); _chartSelected = GRHex(0x4d6258);
    _drawer = GRHex(0xf3f4eb); _drawerBorder = GRHex(0xffffff); _drawerLine = GRHex(0xdee2d5); _iconButton = GRHex(0xe7eadd);
    _infoBox = GRHex(0xe9eddf); _infoText = GRHex(0x808875); _segmented = GRHex(0xe4e8da); _segmentedSelected = GRHex(0xfafbf5); _segmentedSelectedText = _text;
    _deviceState = GRHex(0x788669); _deviceIssue = GRHex(0xab8152); _deviceNote = GRHex(0x8b907f); _entityId = GRHex(0x909582); _groupBadge = GRHex(0xe1e6d8);
    _action = GRHex(0xe7ebdf); _actionBorder = GRHex(0xbdc6af); _actionText = _text; _actionDisabled = GRHex(0xeeeee7); _actionDisabledBorder = GRHex(0xd1d5c9);
    _field = GRHex(0xf9faf3); _fieldBorder = GRHex(0xc2cab6); _fieldText = GRHex(0x47513e);
  } else {
    _backgroundStops = @[GRHex(0x2c4050), GRHex(0x20323e), GRHex(0x152731)];
    _text = GRHex(0xe2e8e8); _rail = GRHex(0x192d39); _railBorder = GRHex(0x354955);
    _nav = GRHex(0x8fa4ad); _navActive = GRHex(0xdbe8e3); _navActiveBackground = GRHex(0x344d59);
    _brandBorder = GRHex(0x9eb0ae); _brandFill = GRHexA(0x7b8b66, .12); _brandFillStrong = GRHex(0x889477);
    _muted = GRHex(0xa2b3b9); _subtitle = _muted; _sectionLabel = _muted; _sectionNote = _muted; _footer = _muted; _leaf = GRHex(0x7c8b68); _timeIcon = GRHex(0xb4c9c3);
    _card = GRHex(0x2d414c); _cardBorder = GRHex(0x445762);
    _cardLit = GRHex(0x3e4741); _cardLitBorder = GRHex(0xa58e5e); _cardDark = GRHex(0x263741); _cardDarkBorder = GRHex(0x3b5059);
    _meta = GRHex(0xb2beb6); _metaBorder = GRHex(0x4d6165); _metaIssue = GRHex(0xdbbc8a); _dot = GRHex(0xa4ab94); _dotIssue = GRHex(0xb9955a);
    _bulbDark = GRHex(0x82949b); _bulbDarkBackground = GRHexA(0x172831, .62);
    _allLights = GRHex(0x344d56); _allLightsBorder = GRHex(0x5c7479); _allLightsText = GRHex(0xd9e5df);
    _allLightsOn = GRHex(0x5a503e); _allLightsOnBorder = GRHex(0x9d8356); _allLightsOnText = GRHex(0xffe3a6);
    _summaryIcon = GRHex(0xb4c9c3); _summaryNote = GRHex(0xa8babd);
    _outline = GRHexA(0x465c6a, .25); _outlineBorder = GRHex(0x526672); _outlineText = GRHex(0xbacbd0);
    _climateCard = GRHex(0x2d414c); _climateBorder = GRHex(0x445762); _climateLine = GRHex(0x445762); _climateIcon = GRHex(0x758c84);
    _climateKind = GRHex(0xb2beb6); _climateIssue = GRHex(0xdbbc8a);
    _period = GRHex(0x2d414c); _periodBorder = GRHex(0x5b7070); _periodText = GRHex(0xd5e1dc); _periodSelected = GRHex(0x496455); _periodSelectedBorder = GRHex(0x829d84);
    _chart = GRHex(0x263b45); _chartBorder = GRHex(0x445762); _chartAxis = GRHex(0x546970); _chartEndpoints = GRHex(0xb2beb6); _chartSelected = GRHex(0xd5e1dc);
    _drawer = GRHex(0x243944); _drawerBorder = GRHex(0x50616b); _drawerLine = GRHex(0x425862); _iconButton = GRHex(0x344d56);
    _infoBox = GRHex(0x344d56); _infoText = GRHex(0xc4d0d1); _segmented = GRHex(0x344d56); _segmentedSelected = GRHex(0x607780); _segmentedSelectedText = GRHex(0xffffff);
    _deviceState = GRHex(0xb8cfa9); _deviceIssue = GRHex(0xdbbc8a); _deviceNote = GRHex(0xa8babd); _entityId = GRHex(0xa8babd); _groupBadge = GRHex(0x344d56);
    _action = GRHex(0x3a535c); _actionBorder = GRHex(0x6d8389); _actionText = GRHex(0xdde7e5); _actionDisabled = GRHex(0x364a53); _actionDisabledBorder = GRHex(0x4e626a);
    _field = GRHex(0x3a535c); _fieldBorder = GRHex(0x6d8389); _fieldText = GRHex(0xdde7e5);
  }
  return self;
}

@end
