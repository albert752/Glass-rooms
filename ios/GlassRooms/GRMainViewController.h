// Glass Rooms for iOS 9: the whole panel in one screen, like the web client.
#import <UIKit/UIKit.h>
#import "GRPanelModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface GRMainViewController : UIViewController <GRPanelModelDelegate>
@property (nonatomic, strong, readonly) GRPanelModel *model;
- (void)connectFromPreferences;
- (void)navigate:(NSString *)destination;
- (void)openRoom:(NSString *)roomId;
- (void)openCategory:(NSString *)category title:(NSString *)title;
- (void)openSettings;
- (void)closeModal;
- (void)setThemeChoice:(NSString *)theme;
- (void)appDidEnterBackground;
- (void)appWillEnterForeground;
@end

NS_ASSUME_NONNULL_END
