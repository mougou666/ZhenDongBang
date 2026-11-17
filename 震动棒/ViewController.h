//
//  ViewController.h
//  起爆器（完整远程控制版）
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController <UIAlertViewDelegate>

// UI
@property (strong, nonatomic) UISlider *slider;
@property (strong, nonatomic) UIButton *actionButton;
@property (strong, nonatomic) UILabel *statusLabel;
@property (strong, nonatomic) UIButton *settingsButton;
@property (strong, nonatomic) UIView *settingsView;
@property (strong, nonatomic) UISwitch *serverSwitch;
@property (strong, nonatomic) UISwitch *clientSwitch;
@property (strong, nonatomic) UILabel *ipLabel;

// 状态
@property (assign, nonatomic) BOOL isVibrating;
@property (strong, nonatomic) NSTimer *vibrationTimer;
@property (assign, nonatomic) BOOL isConnected;     // 是否已配对
@property (assign, nonatomic) BOOL isServerMode;
@property (assign, nonatomic) BOOL isClientMode;

// 方法
- (void)updateStatusLabel;
- (void)startVibration;
- (void)stopVibration;
- (void)vibrateWithIntensity:(NSNumber *)intensityNumber;

@end