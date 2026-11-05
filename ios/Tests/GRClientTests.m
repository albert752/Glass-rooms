// Foundation-only tests for the native client, compiled for macOS by ios/scripts/test.sh.
// Usage: GRClientTests <port> <token>   (the port belongs to ios/Tests/fake_panel.py)
#import <Foundation/Foundation.h>
#import "GRAPIClient.h"
#import "GRLogic.h"
#import "GRPanelModel.h"
#import "GRUtil.h"

static int failures = 0, checks = 0;
#define CHECK(cond, ...) do { checks++; if(!(cond)) { failures++; NSLog(@"FAIL line %d: %s", __LINE__, #cond); NSLog(@"" __VA_ARGS__); } } while(0)

static BOOL waitFor(BOOL (^done)(void), NSTimeInterval seconds) {
  NSDate *limit = [NSDate dateWithTimeIntervalSinceNow:seconds];
  while(!done() && [limit timeIntervalSinceNow] > 0) {
    [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
  }
  return done();
}

@interface Recorder : NSObject <GRPanelModelDelegate>
@property (nonatomic) NSUInteger updates, historyChanges;
@property (nonatomic, copy) NSString *toast, *configuration;
@end
@implementation Recorder
- (void)panelModel:(GRPanelModel *)model didUpdateWithForce:(BOOL)force changed:(BOOL)changed { self.updates++; }
- (void)panelModel:(GRPanelModel *)model showToast:(NSString *)message { self.toast = message; }
- (void)panelModel:(GRPanelModel *)model needsConfiguration:(NSString *)reason { self.configuration = reason; }
- (void)panelModelHistoryDidChange:(GRPanelModel *)model { self.historyChanges++; }
@end

static NSDictionary *light(NSString *entityId, NSString *state, NSString *status, BOOL enabled) {
  return @{@"entity_id": entityId, @"domain": @"light", @"category": @"lights", @"state": state ?: (id)[NSNull null], @"status": status,
           @"room": @"cuina", @"attributes": @{@"brightness": @128, @"color_temp_kelvin": @2700},
           @"controls": @[@{@"action": @"turn_on", @"enabled": @(enabled)}, @{@"action": @"turn_off", @"enabled": @(enabled)}]};
}

static void logicTests(void) {
  CHECK([GRLogic rooms].count == 8);
  CHECK([[GRLogic stateTextForEntity:light(@"light.a", @"on", @"ok", YES) connected:YES demo:NO] isEqualToString:@"Encès"]);
  CHECK([[GRLogic stateTextForEntity:light(@"light.a", @"on", @"ok", YES) connected:NO demo:NO] isEqualToString:@"Pendent de connexió"]);
  CHECK([[GRLogic stateTextForEntity:light(@"light.a", nil, @"ok", YES) connected:YES demo:NO] isEqualToString:@"Estat desconegut"]);
  CHECK([[GRLogic stateTextForEntity:light(@"light.a", @"off", @"unavailable", YES) connected:YES demo:NO] isEqualToString:@"No disponible"]);
  NSDictionary *door = @{@"domain": @"binary_sensor", @"state": @"on", @"status": @"ok", @"attributes": @{@"device_class": @"door"}};
  CHECK([[GRLogic stateTextForEntity:door connected:YES demo:NO] isEqualToString:@"Obert"]);
  NSDictionary *sensor = @{@"domain": @"sensor", @"state": @"21.4", @"status": @"ok", @"attributes": @{@"unit_of_measurement": @"°C"}};
  CHECK([[GRLogic stateTextForEntity:sensor connected:YES demo:NO] isEqualToString:@"21.4 °C"]);
  CHECK([[GRLogic climateReading:sensor connected:YES] isEqualToString:@"21.4 °C"]);
  NSDictionary *comma = @{@"state": @"21,4", @"status": @"ok"};
  CHECK([[GRLogic climateReading:comma connected:YES] isEqualToString:@"—"]);
  NSArray *lights = @[light(@"light.a", @"on", @"ok", YES), light(@"light.b", @"off", @"ok", YES), light(@"light.c", @"off", @"unavailable", YES)];
  CHECK([[GRLogic lightCounts:lights live:YES] isEqualToString:@"2 online · 1 offline"]);
  CHECK([[GRLogic lightCounts:lights live:NO] isEqualToString:@"0 online · 3 offline"]);
  CHECK([GRLogic lightsNeedingAction:lights action:@"turn_on"].count == 2);
  CHECK([GRLogic availableLights:lights action:@"turn_off"].count == 2);
  CHECK(![GRLogic canToggleLights:lights action:@"turn_on"]);
  CHECK([GRLogic canToggleLights:@[lights[1]] action:@"turn_on"]);
  CHECK(![GRLogic canToggleLights:@[light(@"light.d", @"off", @"ok", NO)] action:@"turn_on"]);
  CHECK([[GRLogic attributeSummary:lights[0] live:YES] isEqualToString:@"Brillantor: 50% · Color: 2700 K"], @"%@", [GRLogic attributeSummary:lights[0] live:YES]);
  CHECK([[GRLogic summaryValueForCategory:@"lights" entities:lights connected:YES demo:NO] isEqualToString:@"2 online · 1 offline"]);
  CHECK([[GRLogic summaryValueForCategory:@"security" entities:lights connected:NO demo:NO] isEqualToString:@"—"]);
  CHECK([GRLogic entities:lights inRoom:@"cuina"].count == 3 && [GRLogic entities:lights inRoom:nil].count == 0);
  CHECK([GRFormatNumber(21.4) isEqualToString:@"21.4"] && [GRFormatNumber(48) isEqualToString:@"48"] && [GRFormatNumber(0.45) isEqualToString:@"0.45"]);
  CHECK(GRRound(2.5) == 3 && GRRound(-2.5) == -2);
  NSDate *date = GRParseISODate(@"2026-11-04T09:30:00.250000+00:00");
  CHECK(date && fabs(date.timeIntervalSince1970 - 1793784600.25) < 0.001, @"%@", date);
  CHECK(fabs(GRParseISODate(@"2026-11-04T10:30:00+01:00").timeIntervalSince1970 - 1793784600) < 0.001);
  CHECK(GRParseISODate(@"2026-11-04 10:30") == nil && GRParseISODate(@"2026-11-04T10:30:00") == nil);
  CHECK(GRNum(@YES) == nil && GRNum(@3) != nil && GRNum(@(NAN)) == nil);
  CHECK([GRLogic isNightForTheme:@"night" date:[NSDate date]] && ![GRLogic isNightForTheme:@"day" date:[NSDate date]]);
  NSString *problem = nil;
  CHECK([[GRAPIClient normalizedBaseURL:@" http://192.168.1.10:8099/ " error:&problem].absoluteString isEqualToString:@"http://192.168.1.10:8099"]);
  CHECK([GRAPIClient normalizedBaseURL:@"192.168.1.10:8099" error:&problem] == nil && problem.length);
  CHECK([GRAPIClient normalizedBaseURL:@"http://host:8099/api" error:NULL] == nil);
  CHECK([GRAPIClient normalizedBaseURL:@"ftp://host" error:NULL] == nil);
  CHECK([[GRAPIClient fingerprintForCertificateData:[@"abc" dataUsingEncoding:NSUTF8StringEncoding]] hasPrefix:@"BA:78:16:BF"]);
}

static void serverTests(NSString *port, NSString *token) {
  NSURL *base = [NSURL URLWithString:[@"http://127.0.0.1:" stringByAppendingString:port]];
  Recorder *recorder = [Recorder new];
  GRPanelModel *model = [GRPanelModel new];
  model.delegate = recorder;

  // A wrong token never reaches state and asks for configuration.
  [model useClient:[[GRAPIClient alloc] initWithBaseURL:base token:@"wrong-token-wrong-token-wrong-token" pinnedFingerprint:nil]];
  CHECK(waitFor(^{ return (BOOL)(model.configurationProblem != nil && !model.authenticated); }, 5), @"wrong token accepted");
  CHECK([model.configurationProblem rangeOfString:@"incorrecte"].location != NSNotFound, @"%@", model.configurationProblem);

  // The panel PIN works as the app credential (fake_panel.py uses 12345678).
  [model useClient:[[GRAPIClient alloc] initWithBaseURL:base token:@"12345678" pinnedFingerprint:nil]];
  CHECK(waitFor(^{ return (BOOL)(model.connected && model.entities.count == 3); }, 5), @"PIN not accepted: %@", model.error);
  [model useClient:[[GRAPIClient alloc] initWithBaseURL:base token:token pinnedFingerprint:nil]];
  CHECK(waitFor(^{ return (BOOL)(model.connected && model.entities.count == 3); }, 5), @"state not loaded: %@", model.error);
  CHECK(model.authenticated && !model.preview);
  NSArray *kitchen = [GRLogic entities:model.entities inRoom:@"cuina"];
  CHECK(kitchen.count == 1 && [kitchen[0][@"name"] isEqualToString:@"Llum cuina"]);
  CHECK([GRLogic canToggleLights:kitchen action:@"turn_on"]);
  NSArray *climate = [GRLogic entities:model.entities inCategory:@"climate"];
  CHECK(climate.count == 1 && [[GRLogic climateReading:climate[0] connected:YES] isEqualToString:@"21.4 °C"]);

  // Room toggle: one batch request, then a confirmed state.
  [model turnLights:kitchen place:@"Cuina" action:@"turn_on" skipped:0];
  CHECK(waitFor(^{ return (BOOL)(!model.busy && [[GRLogic entities:model.entities inRoom:@"cuina"][0][@"state"] isEqual:@"on"]); }, 8), @"lights batch failed: %@", recorder.toast);

  // Brightness through /api/action with a range value.
  NSDictionary *entity = [GRLogic entities:model.entities inRoom:@"cuina"][0], *brightness = nil;
  for(NSDictionary *control in entity[@"controls"]) { if([control[@"action"] isEqual:@"brightness"]) { brightness = control; } }
  CHECK(brightness && [brightness[@"enabled"] isEqual:@YES]);
  __block NSString *actionError = @"pending";
  if(brightness) {
    [model sendAction:entity control:brightness value:@200 code:nil completion:^(NSString *error) { actionError = error; }];
    CHECK(waitFor(^{ return (BOOL)![actionError isEqual:@"pending"]; }, 5) && actionError == nil, @"brightness: %@", actionError);
  }

  // Server-side validation messages reach the app unchanged.
  actionError = @"pending";
  NSDictionary *bad = @{@"action": @"brightness", @"enabled": @YES, @"kind": @"range"};
  waitFor(^{ return (BOOL)!model.busy; }, 5);
  [model sendAction:entity control:bad value:@999 code:nil completion:^(NSString *error) { actionError = error; }];
  CHECK(waitFor(^{ return (BOOL)![actionError isEqual:@"pending"]; }, 5) && [actionError rangeOfString:@"límits"].location != NSNotFound, @"%@", actionError);

  model.climateVisible = YES;
  waitFor(^{ return (BOOL)!model.busy; }, 5);
  [model loadClimateHistory];
  CHECK(waitFor(^{ return (BOOL)(!model.historyLoading && [model.historySeries[@"sensor.test_temperatura"] count] == 3); }, 5), @"history: %@ %@", model.historySeries, model.historyError);

  __block NSString *audit = nil;
  [model loadAudit:^(NSString *text) { audit = text; }];
  CHECK(waitFor(^{ return (BOOL)(audit != nil); }, 5) && [audit rangeOfString:@"verified_actions"].location != NSNotFound);
  CHECK([audit rangeOfString:token].location == NSNotFound);
  [model useClient:nil];
}

int main(int argc, const char *argv[]) {
  @autoreleasepool {
    logicTests();
    if(argc == 3) { serverTests([NSString stringWithUTF8String:argv[1]], [NSString stringWithUTF8String:argv[2]]); }
    printf("%d checks, %d failures\n", checks, failures);
    return failures ? 1 : 0;
  }
}
