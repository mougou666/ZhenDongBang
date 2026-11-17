//
//  AppDelegate.m
//  VibrationControl
//
//  Created by YourName on 2026/08/13.
//

#import "AppDelegate.h"
#import "ViewController.h"

@implementation AppDelegate

@synthesize window = _window;
@synthesize viewController = _viewController;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // 创建窗口
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    // 创建根视图控制器（纯代码）
    self.viewController = [[ViewController alloc] init];
    self.window.rootViewController = self.viewController;
    
    [self.window makeKeyAndVisible];
    return YES;
}

@end