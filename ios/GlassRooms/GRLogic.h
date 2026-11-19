// Glass Rooms for iOS 9: presentation rules (states, counts, climate, weather, fan speeds, PVPC levels).
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GRLogic : NSObject
+ (NSArray<NSDictionary *> *)rooms;
+ (nullable NSDictionary *)roomWithId:(NSString *)roomId;
+ (NSString *)stateTextForEntity:(nullable NSDictionary *)entity connected:(BOOL)connected demo:(BOOL)demo;
+ (NSArray<NSDictionary *> *)entities:(NSArray *)entities inCategory:(NSString *)category;
// A nil room selects entities without an assigned room.
+ (NSArray<NSDictionary *> *)entities:(NSArray *)entities inRoom:(nullable NSString *)room;
+ (NSArray<NSDictionary *> *)lights:(NSArray *)entities;
+ (BOOL)entity:(NSDictionary *)entity hasEnabledAction:(NSString *)action;
+ (BOOL)canToggleLights:(NSArray *)lights action:(NSString *)action;
+ (NSUInteger)onlineLights:(NSArray *)lights live:(BOOL)live;
+ (NSString *)lightCounts:(NSArray *)lights live:(BOOL)live;
+ (NSArray<NSDictionary *> *)lightsNeedingAction:(NSArray *)lights action:(NSString *)action;
+ (NSArray<NSDictionary *> *)availableLights:(NSArray *)lights action:(NSString *)action;
+ (NSString *)summaryValueForCategory:(NSString *)category entities:(NSArray *)entities connected:(BOOL)connected demo:(BOOL)demo;
+ (NSString *)climateReading:(NSDictionary *)entity connected:(BOOL)connected;
// Numeric state of an available sensor, or nil.
+ (nullable NSNumber *)numericState:(NSDictionary *)entity connected:(BOOL)connected;
// Mean of the available climate sensors with this device_class ("temperature" or "humidity").
+ (nullable NSNumber *)averageClimate:(NSArray *)entities deviceClass:(NSString *)deviceClass connected:(BOOL)connected;
// Catalan decimal text with one decimal: 21.44 -> "21,4", 22 -> "22,0".
+ (NSString *)shortNumber:(double)value;
+ (nullable NSDictionary *)alarmPanel:(NSArray *)entities;
// Security page groups: alarm, cameras, openings, detections, sirens, sirenPower, people, batteries (arrays).
// Sirens and people are grouped so they never land among the openings, but the page does not show them.
+ (NSDictionary<NSString *, NSArray *> *)securityGroups:(NSArray *)entities;
// "ara", "fa 5 min", "fa 3 h", "ahir 21:04", "4/11 21:04"; nil without a date.
+ (nullable NSString *)agoText:(nullable NSString *)isoTime now:(NSDate *)now;
+ (NSString *)climateTime:(nullable NSString *)isoTime;
+ (nullable NSString *)attributeSummary:(NSDictionary *)entity live:(BOOL)live;
+ (NSString *)clockText:(NSDate *)date;
+ (NSString *)dateText:(NSDate *)date;
+ (BOOL)isNightForTheme:(NSString *)theme date:(NSDate *)date;
+ (NSString *)lastUpdateText:(nullable NSString *)fetchedAt connected:(BOOL)connected demo:(BOOL)demo;
// First available weather.* entity (outdoor temperature, e.g. Barcelona), or nil.
+ (nullable NSDictionary *)weather:(NSArray *)entities connected:(BOOL)connected;
+ (NSString *)weatherCondition:(nullable NSString *)state;
// "Barcelona 14,2° · ennuvolat", or nil without a reading.
+ (nullable NSString *)weatherLine:(NSArray *)entities connected:(BOOL)connected;
// Fan speeds the way Home Assistant converts them: speed n of N is floor(n * 100 / N) %, a percentage is speed ceil(p * N / 100).
+ (NSInteger)fanSpeedForPercentage:(double)percentage speeds:(NSInteger)speeds;
+ (NSInteger)percentageForFanSpeed:(NSInteger)speed speeds:(NSInteger)speeds;
// PVPC electricity price sensor: hourly prices (24 NSNumber or NSNull) for today (or tomorrow).
+ (nullable NSDictionary *)pvpcSensor:(NSArray *)entities;
+ (NSArray *)pvpcPrices:(NSDictionary *)sensor tomorrow:(BOOL)tomorrow;
// "low" (vall), "normal" or "high" (alta): the cheapest third of the day's hours, the middle third, the dearest third.
+ (NSString *)priceLevel:(double)price prices:(NSArray *)prices;
// Price in cents of euro per kWh with one decimal: 0.1234 €/kWh -> "12,3".
+ (NSString *)centsText:(double)euros;
@end

NS_ASSUME_NONNULL_END
