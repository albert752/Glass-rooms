#import "GRLogic.h"
#import "GRUtil.h"

static NSCalendar *GRCalendar(void) {
  NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
  calendar.timeZone = [NSTimeZone localTimeZone];
  return calendar;
}

@implementation GRLogic

+ (NSArray<NSDictionary *> *)rooms {
  static NSArray *rooms;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    rooms = @[@{@"id":@"menjador",@"name":@"Menjador"}, @{@"id":@"cuina",@"name":@"Cuina"},
              @{@"id":@"habitacio",@"name":@"Habitació"}, @{@"id":@"despatx",@"name":@"Despatx"},
              @{@"id":@"rebedor",@"name":@"Rebedor"}, @{@"id":@"bany",@"name":@"Bany"},
              @{@"id":@"passadis",@"name":@"Passadís"}, @{@"id":@"lavabo",@"name":@"Lavabo"}];
  });
  return rooms;
}

+ (NSDictionary *)roomWithId:(NSString *)roomId {
  for(NSDictionary *room in [self rooms]) { if([room[@"id"] isEqualToString:roomId]) { return room; } }
  return nil;
}

+ (NSString *)stateTextForEntity:(NSDictionary *)entity connected:(BOOL)connected demo:(BOOL)demo {
  NSString *status = GRStr(entity[@"status"]), *state = GRStr(entity[@"state"]), *domain = GRStr(entity[@"domain"]);
  if((!connected && !demo) || !entity || [status isEqualToString:@"pending"]) { return @"Pendent de connexió"; }
  if([status isEqualToString:@"missing"]) { return @"No trobada a Home Assistant"; }
  if([status isEqualToString:@"unavailable"]) { return @"No disponible"; }
  if([status isEqualToString:@"unresponsive"]) { return @"No respon a les ordres"; }
  if([status isEqualToString:@"unknown"] || !state) { return @"Estat desconegut"; }
  NSDictionary *names = @{@"on":@"Encès",@"off":@"Apagat",@"disarmed":@"Desarmada",@"armed_home":@"Armada · a casa",
                          @"armed_away":@"Armada · fora",@"armed_night":@"Armada · nit",@"armed_vacation":@"Armada · vacances",
                          @"arming":@"Armant-se",@"disarming":@"Desarmant-se",@"pending":@"Pendent",@"triggered":@"Alarma activada",
                          @"playing":@"En reproducció",@"paused":@"En pausa",@"idle":@"En espera",@"standby":@"En espera"};
  NSDictionary *attributes = GRDict(entity[@"attributes"]) ?: @{};
  BOOL on = [state isEqualToString:@"on"];
  if([domain isEqualToString:@"binary_sensor"] && (on || [state isEqualToString:@"off"])) {
    NSString *dc = GRStr(attributes[@"device_class"]);
    if([dc isEqualToString:@"door"] || [dc isEqualToString:@"window"] || [dc isEqualToString:@"opening"]) { return on ? @"Obert" : @"Tancat"; }
    if([dc isEqualToString:@"motion"] || [dc isEqualToString:@"occupancy"] || [dc isEqualToString:@"presence"]) { return on ? @"Detecció" : @"Sense detecció"; }
    if([dc isEqualToString:@"heat"]) { return on ? @"Escalfant" : @"Sense escalfar"; }
    return on ? @"Actiu" : @"Inactiu";
  }
  if([domain isEqualToString:@"scene"]) { return [@"Estat HA: " stringByAppendingString:state]; }
  if([domain isEqualToString:@"sensor"]) {
    NSString *unit = GRStr(attributes[@"unit_of_measurement"]);
    return unit.length ? [NSString stringWithFormat:@"%@ %@", state, unit] : state;
  }
  return names[state] ?: state;
}

+ (NSArray *)entities:(NSArray *)entities matching:(BOOL (^)(NSDictionary *entity))test {
  NSMutableArray *result = [NSMutableArray array];
  for(id item in entities) { if(GRDict(item) && test(item)) { [result addObject:item]; } }
  return result;
}

+ (NSArray<NSDictionary *> *)entities:(NSArray *)entities inCategory:(NSString *)category {
  return [self entities:entities matching:^BOOL(NSDictionary *entity) { return [GRStr(entity[@"category"]) isEqualToString:category]; }];
}

+ (NSArray<NSDictionary *> *)entities:(NSArray *)entities inRoom:(NSString *)room {
  return [self entities:entities matching:^BOOL(NSDictionary *entity) {
    NSString *assigned = GRStr(entity[@"room"]);
    return room ? [assigned isEqualToString:room] : assigned == nil;
  }];
}

+ (NSArray<NSDictionary *> *)lights:(NSArray *)entities {
  return [self entities:entities matching:^BOOL(NSDictionary *entity) { return [GRStr(entity[@"domain"]) isEqualToString:@"light"]; }];
}

+ (BOOL)entity:(NSDictionary *)entity hasEnabledAction:(NSString *)action {
  for(id control in GRArray(entity[@"controls"]) ?: @[]) {
    if([GRStr(GRDict(control)[@"action"]) isEqualToString:action] && [GRDict(control)[@"enabled"] isEqual:@YES]) { return YES; }
  }
  return NO;
}

+ (BOOL)isOk:(NSDictionary *)entity { return [GRStr(entity[@"status"]) isEqualToString:@"ok"]; }

+ (BOOL)canToggleLights:(NSArray *)lights action:(NSString *)action {
  if(!lights.count) { return NO; }
  for(NSDictionary *light in lights) {
    if(![self isOk:light] || ![self entity:light hasEnabledAction:action]) { return NO; }
  }
  return YES;
}

+ (NSUInteger)onlineLights:(NSArray *)lights live:(BOOL)live {
  NSUInteger online = 0;
  for(NSDictionary *light in lights) { if(live && [self isOk:light]) { online++; } }
  return online;
}

+ (NSString *)lightCounts:(NSArray *)lights live:(BOOL)live {
  NSUInteger online = [self onlineLights:lights live:live];
  return [NSString stringWithFormat:@"%lu online · %lu offline", (unsigned long)online, (unsigned long)(lights.count - online)];
}

+ (NSArray<NSDictionary *> *)lightsNeedingAction:(NSArray *)lights action:(NSString *)action {
  NSString *target = [action isEqualToString:@"turn_on"] ? @"on" : @"off";
  return [self entities:lights matching:^BOOL(NSDictionary *entity) { return ![GRStr(entity[@"state"]) isEqualToString:target]; }];
}

+ (NSArray<NSDictionary *> *)availableLights:(NSArray *)lights action:(NSString *)action {
  return [self entities:lights matching:^BOOL(NSDictionary *entity) {
    return [self isOk:entity] && [self entity:entity hasEnabledAction:action];
  }];
}

+ (NSString *)summaryValueForCategory:(NSString *)category entities:(NSArray *)entities connected:(BOOL)connected demo:(BOOL)demo {
  NSArray *items = [self entities:entities inCategory:category];
  if([category isEqualToString:@"lights"]) { return [self lightCounts:items live:connected || demo]; }
  if(!connected && !demo) { return @"—"; }
  NSUInteger valid = 0;
  for(NSDictionary *item in items) { if([self isOk:item]) { valid++; } }
  return [NSString stringWithFormat:@"%lu / %lu amb estat", (unsigned long)valid, (unsigned long)items.count];
}

+ (NSString *)climateReading:(NSDictionary *)entity connected:(BOOL)connected {
  NSString *state = GRStr(entity[@"state"]);
  if(!connected || ![self isOk:entity] || !state) { return @"—"; }
  NSRegularExpression *number = [NSRegularExpression regularExpressionWithPattern:@"^-?\\d+(?:\\.\\d+)?$" options:0 error:NULL];
  if(![number firstMatchInString:state options:0 range:NSMakeRange(0, state.length)]) { return @"—"; }
  NSString *unit = GRStr(GRDict(entity[@"attributes"])[@"unit_of_measurement"]);
  return unit.length ? [NSString stringWithFormat:@"%@ %@", state, unit] : state;
}

+ (NSNumber *)numericState:(NSDictionary *)entity connected:(BOOL)connected {
  NSString *state = GRStr(entity[@"state"]);
  if(!connected || ![self isOk:entity] || !state) { return nil; }
  NSRegularExpression *number = [NSRegularExpression regularExpressionWithPattern:@"^-?\\d+(?:\\.\\d+)?$" options:0 error:NULL];
  if(![number firstMatchInString:state options:0 range:NSMakeRange(0, state.length)]) { return nil; }
  return @(state.doubleValue);
}

+ (NSNumber *)averageClimate:(NSArray *)entities deviceClass:(NSString *)deviceClass connected:(BOOL)connected {
  double total = 0; NSUInteger count = 0;
  for(NSDictionary *entity in [self entities:entities inCategory:@"climate"]) {
    if(![GRStr(GRDict(entity[@"attributes"])[@"device_class"]) isEqualToString:deviceClass]) { continue; }
    NSNumber *value = [self numericState:entity connected:connected];
    if(value) { total += value.doubleValue; count++; }
  }
  return count ? @(total / count) : nil;
}

+ (NSString *)shortNumber:(double)value {
  if(!isfinite(value)) { return @"—"; }
  NSString *text = [NSString stringWithFormat:@"%.1f", round(value * 10) / 10];
  return [text isEqualToString:@"-0.0"] ? @"0,0" : [text stringByReplacingOccurrencesOfString:@"." withString:@","];
}

+ (NSDictionary *)alarmPanel:(NSArray *)entities {
  for(id entity in entities) {
    if([GRStr(GRDict(entity)[@"domain"]) isEqualToString:@"alarm_control_panel"]) { return entity; }
  }
  return nil;
}

+ (NSString *)climateTime:(NSString *)isoTime {
  NSDate *date = GRParseISODate(isoTime);
  if(!date) { return @"Hora desconeguda"; }
  NSDateComponents *c = [GRCalendar() components:NSCalendarUnitDay|NSCalendarUnitMonth|NSCalendarUnitHour|NSCalendarUnitMinute fromDate:date];
  return [NSString stringWithFormat:@"%ld/%@ %@:%@", (long)c.day, GRPad2(c.month), GRPad2(c.hour), GRPad2(c.minute)];
}

+ (NSString *)attributeSummary:(NSDictionary *)entity live:(BOOL)live {
  NSDictionary *a = GRDict(entity[@"attributes"]) ?: @{};
  NSString *domain = GRStr(entity[@"domain"]);
  NSMutableArray *parts = [NSMutableArray array];
  if(![self isOk:entity] || !live) { return nil; }
  if([domain isEqualToString:@"water_heater"]) {
    NSNumber *current = GRNum(a[@"current_temperature"]);
    NSString *unit = GRStr(a[@"temperature_unit"]);
    if(current) { [parts addObject:[NSString stringWithFormat:@"Temperatura actual: %@ %@", GRFormatNumber(current.doubleValue), unit.length ? unit : @"°"]]; }
    if(GRStr(a[@"operation_mode"]).length) { [parts addObject:[@"Mode: " stringByAppendingString:a[@"operation_mode"]]]; }
  }
  if([domain isEqualToString:@"light"]) {
    NSNumber *brightness = GRNum(a[@"brightness"]), *kelvin = GRNum(a[@"color_temp_kelvin"]);
    if(brightness) { [parts addObject:[NSString stringWithFormat:@"Brillantor: %ld%%", GRRound(brightness.doubleValue / 255 * 100)]]; }
    if(kelvin) { [parts addObject:[NSString stringWithFormat:@"Color: %@ K", GRFormatNumber(kelvin.doubleValue)]]; }
  }
  NSNumber *percentage = GRNum(a[@"percentage"]);
  if([domain isEqualToString:@"fan"] && percentage) { [parts addObject:[NSString stringWithFormat:@"Velocitat: %@%%", GRFormatNumber(percentage.doubleValue)]]; }
  if([domain isEqualToString:@"media_player"]) {
    NSNumber *volume = GRNum(a[@"volume_level"]);
    if(GRStr(a[@"media_title"]).length) { [parts addObject:a[@"media_title"]]; }
    if(volume) { [parts addObject:[NSString stringWithFormat:@"Volum: %ld%%", GRRound(volume.doubleValue * 100)]]; }
  }
  return parts.count ? [parts componentsJoinedByString:@" · "] : nil;
}

+ (NSString *)clockText:(NSDate *)date {
  NSDateComponents *c = [GRCalendar() components:NSCalendarUnitHour|NSCalendarUnitMinute fromDate:date];
  return [NSString stringWithFormat:@"%@:%@", GRPad2(c.hour), GRPad2(c.minute)];
}

+ (NSString *)dateText:(NSDate *)date {
  NSArray *days = @[@"Diumenge",@"Dilluns",@"Dimarts",@"Dimecres",@"Dijous",@"Divendres",@"Dissabte"];
  NSArray *months = @[@"gener",@"febrer",@"març",@"abril",@"maig",@"juny",@"juliol",@"agost",@"setembre",@"octubre",@"novembre",@"desembre"];
  NSDateComponents *c = [GRCalendar() components:NSCalendarUnitWeekday|NSCalendarUnitDay|NSCalendarUnitMonth fromDate:date];
  return [NSString stringWithFormat:@"%@, %ld de %@", days[c.weekday - 1], (long)c.day, months[c.month - 1]];
}

+ (BOOL)isNightForTheme:(NSString *)theme date:(NSDate *)date {
  NSInteger hour = [GRCalendar() component:NSCalendarUnitHour fromDate:date];
  return [theme isEqualToString:@"night"] || ([theme isEqualToString:@"auto"] && (hour < 7 || hour >= 20));
}

+ (NSString *)lastUpdateText:(NSString *)fetchedAt connected:(BOOL)connected demo:(BOOL)demo {
  if(demo) { return @"Simulació de llums · cap ordre real"; }
  NSDate *date = GRParseISODate(fetchedAt);
  if(!connected || !date) { return @"Esperant dades de casa"; }
  NSDateComponents *c = [GRCalendar() components:NSCalendarUnitHour|NSCalendarUnitMinute|NSCalendarUnitSecond fromDate:date];
  return [NSString stringWithFormat:@"Actualitzat a les %@:%@:%@", GRPad2(c.hour), GRPad2(c.minute), GRPad2(c.second)];
}

@end
