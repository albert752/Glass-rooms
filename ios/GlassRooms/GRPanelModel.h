// Glass Rooms for iOS 9: panel state, polling and commands. Mirrors the web client's rules.
#import <Foundation/Foundation.h>
#import "GRAPIClient.h"

NS_ASSUME_NONNULL_BEGIN

@class GRPanelModel;

@protocol GRPanelModelDelegate <NSObject>
// changed is NO when only the footer status needs to be redrawn.
- (void)panelModel:(GRPanelModel *)model didUpdateWithForce:(BOOL)force changed:(BOOL)changed;
- (void)panelModel:(GRPanelModel *)model showToast:(nullable NSString *)message;
- (void)panelModel:(GRPanelModel *)model needsConfiguration:(NSString *)reason;
- (void)panelModelHistoryDidChange:(GRPanelModel *)model;
@end

@interface GRPanelModel : NSObject
@property (nonatomic, weak, nullable) id<GRPanelModelDelegate> delegate;
@property (nonatomic, strong, readonly, nullable) GRAPIClient *client;
@property (nonatomic, readonly) BOOL connected, preview, demo, liveUpdates, busy, authenticated;
@property (nonatomic, readonly, copy) NSArray<NSDictionary *> *entities;
@property (nonatomic, readonly, copy, nullable) NSString *fetchedAt, *error, *configurationProblem;
@property (nonatomic) BOOL climateVisible;
@property (nonatomic, readonly) NSInteger historyHours;
@property (nonatomic, readonly, copy) NSDictionary *historySeries;
@property (nonatomic, readonly) BOOL historyLoading;
@property (nonatomic, readonly, copy, nullable) NSString *historyError;

- (void)useClient:(nullable GRAPIClient *)client;
- (void)enterBackground;
- (void)enterForeground;
- (void)refresh:(BOOL)force;
- (void)sendAction:(NSDictionary *)entity control:(NSDictionary *)control value:(nullable id)value code:(nullable NSString *)code
        completion:(void (^)(NSString *_Nullable error))completion;
- (void)turnLights:(NSArray<NSDictionary *> *)lights place:(NSString *)place action:(NSString *)action skipped:(NSUInteger)skipped;
- (void)loadClimateHistory;
- (void)changeClimatePeriod:(NSInteger)hours;
- (void)loadAudit:(void (^)(NSString *text))completion;
@end

NS_ASSUME_NONNULL_END
