// Glass Rooms for iOS 9: presentation rules shared with glass_rooms/www/app.js.
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
+ (NSDictionary<NSString *, NSArray *> *)securityGroups:(NSArray *)entities;
// "ara", "fa 5 min", "fa 3 h", "ahir 21:04", "4/11 21:04"; nil without a date.
+ (nullable NSString *)agoText:(nullable NSString *)isoTime now:(NSDate *)now;
// Person or tracker location in Catalan: "A casa", "Fora" or the zone name.
+ (NSString *)presenceText:(NSDictionary *)entity connected:(BOOL)connected;
+ (NSString *)climateTime:(nullable NSString *)isoTime;
+ (nullable NSString *)attributeSummary:(NSDictionary *)entity live:(BOOL)live;
+ (NSString *)clockText:(NSDate *)date;
+ (NSString *)dateText:(NSDate *)date;
+ (BOOL)isNightForTheme:(NSString *)theme date:(NSDate *)date;
+ (NSString *)lastUpdateText:(nullable NSString *)fetchedAt connected:(BOOL)connected demo:(BOOL)demo;
@end

NS_ASSUME_NONNULL_END
