//
//  ViewController.m
//  起爆器 - 端口7891，使用 NSThread
//

#import "ViewController.h"
#import <AudioToolbox/AudioToolbox.h>
#import <QuartzCore/QuartzCore.h>
#import <ifaddrs.h>
#import <arpa/inet.h>
#import <sys/socket.h>
#import <netinet/in.h>

#define SERVER_PORT 7891
#define MAX_VIBRATE_COUNT 50
#define MIN_INTERVAL_USEC 10000
#define MAX_INTERVAL_USEC 100000

@interface ViewController () {
    int _serverSocket;
    int _clientSocket;
    NSThread *_serverThread;
    BOOL _serverRunning;
    BOOL _isPaired;
}
- (void)settingsButtonTapped:(UIButton *)sender;
- (void)serverSwitchChanged:(UISwitch *)sender;
- (void)clientSwitchChanged:(UISwitch *)sender;
- (void)sliderValueChanged:(UISlider *)sender;
- (void)buttonTapped:(UIButton *)sender;
- (void)startServer;
- (void)stopServer;
- (void)connectToIP:(NSString *)ip;
- (void)disconnect;
- (void)sendVibrationCommand:(float)intensity;
- (NSString *)getLocalIP;
- (void)pairSuccess;
- (void)handleReceivedMessage:(NSString *)msg;
- (void)vibrationTimerFired:(NSTimer *)timer;
- (void)serverThreadMain;
@end

@implementation ViewController

@synthesize slider = _slider;
@synthesize actionButton = _actionButton;
@synthesize statusLabel = _statusLabel;
@synthesize settingsButton = _settingsButton;
@synthesize settingsView = _settingsView;
@synthesize serverSwitch = _serverSwitch;
@synthesize clientSwitch = _clientSwitch;
@synthesize ipLabel = _ipLabel;
@synthesize isVibrating = _isVibrating;
@synthesize vibrationTimer = _vibrationTimer;
@synthesize isConnected = _isConnected;
@synthesize isServerMode = _isServerMode;
@synthesize isClientMode = _isClientMode;

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor lightGrayColor];
    
    CGFloat screenWidth  = self.view.bounds.size.width;
    CGFloat screenHeight = self.view.bounds.size.height;
    
    // ----- 滑块 -----
    CGFloat sliderLength = screenHeight * 0.5;
    CGFloat sliderThickness = 23.0;
    self.slider = [[UISlider alloc] initWithFrame:CGRectMake(0, 0, sliderLength, sliderThickness)];
    self.slider.minimumValue = 0.0;
    self.slider.maximumValue = 1.0;
    self.slider.value = 0.0;
    self.slider.transform = CGAffineTransformMakeRotation(-M_PI_2);
    self.slider.center = CGPointMake(screenWidth/2.0, screenHeight * 0.45);
    [self.slider addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.slider];
    
    // ----- 状态标签 -----
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 250, 40)];
    CGFloat sliderBottom = self.slider.center.y + sliderLength/2.0;
    CGFloat buttonHeight = 44.0;
    CGFloat bottomMargin = 30.0;
    CGFloat buttonY = screenHeight - buttonHeight - bottomMargin;
    CGFloat labelHeight = 40.0;
    CGFloat d = (buttonY - sliderBottom - labelHeight) / 2.0;
    if (d < 0) d = 0;
    self.statusLabel.center = CGPointMake(screenWidth/2.0, sliderBottom + d + labelHeight/2.0);
    self.statusLabel.textAlignment = UITextAlignmentCenter;
    self.statusLabel.font = [UIFont boldSystemFontOfSize:20];
    self.statusLabel.textColor = [UIColor darkTextColor];
    self.statusLabel.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.statusLabel];
    [self updateStatusLabel];
    
    // ----- 按钮 -----
    self.actionButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    self.actionButton.frame = CGRectMake(0, 0, 200, buttonHeight);
    self.actionButton.center = CGPointMake(screenWidth/2.0, buttonY + buttonHeight/2.0);
    [self.actionButton setTitle:@"启动震动" forState:UIControlStateNormal];
    [self.actionButton addTarget:self action:@selector(buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.actionButton];
    
    // ----- 设置按钮 -----
    self.settingsButton = [UIButton buttonWithType:UIButtonTypeInfoLight];
    self.settingsButton.frame = CGRectMake(screenWidth - 50, 20, 40, 40);
    [self.settingsButton addTarget:self action:@selector(settingsButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.settingsButton];
    
    // ----- 设置面板 -----
    self.settingsView = [[UIView alloc] initWithFrame:CGRectMake(20, 80, screenWidth-40, 180)];
    self.settingsView.backgroundColor = [UIColor whiteColor];
    self.settingsView.layer.borderColor = [UIColor darkGrayColor].CGColor;
    self.settingsView.layer.borderWidth = 1.0;
    self.settingsView.layer.cornerRadius = 10.0;
    self.settingsView.hidden = YES;
    [self.view addSubview:self.settingsView];
    
    UILabel *serverLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 100, 30)];
    serverLabel.text = @"被控端";
    serverLabel.font = [UIFont systemFontOfSize:16];
    [self.settingsView addSubview:serverLabel];
    self.serverSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(120, 10, 0, 0)];
    [self.serverSwitch addTarget:self action:@selector(serverSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [self.settingsView addSubview:self.serverSwitch];
    
    UILabel *clientLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 60, 100, 30)];
    clientLabel.text = @"控制端";
    clientLabel.font = [UIFont systemFontOfSize:16];
    [self.settingsView addSubview:clientLabel];
    self.clientSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(120, 60, 0, 0)];
    [self.clientSwitch addTarget:self action:@selector(clientSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [self.settingsView addSubview:self.clientSwitch];
    
    self.ipLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 120, self.settingsView.bounds.size.width-20, 30)];
    self.ipLabel.text = @"IP: 未获取";
    self.ipLabel.font = [UIFont systemFontOfSize:14];
    self.ipLabel.textColor = [UIColor blueColor];
    self.ipLabel.textAlignment = UITextAlignmentCenter;
    [self.settingsView addSubview:self.ipLabel];
    
    // 初始化
    _serverSocket = -1;
    _clientSocket = -1;
    _serverRunning = NO;
    _isPaired = NO;
    self.isConnected = NO;
    self.isServerMode = NO;
    self.isClientMode = NO;
    self.isVibrating = NO;
}

#pragma mark - 设置面板
- (void)settingsButtonTapped:(UIButton *)sender {
    self.settingsView.hidden = !self.settingsView.hidden;
}

- (void)serverSwitchChanged:(UISwitch *)sender {
    if (sender.isOn) {
        [self.clientSwitch setOn:NO animated:YES];
        self.isClientMode = NO;
        self.isServerMode = YES;
        [self startServer];
    } else {
        self.isServerMode = NO;
        [self stopServer];
        self.ipLabel.text = @"IP: 未获取";
    }
}

- (void)clientSwitchChanged:(UISwitch *)sender {
    if (sender.isOn) {
        [self.serverSwitch setOn:NO animated:YES];
        self.isServerMode = NO;
        self.isClientMode = YES;
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"输入对方IP"
                                                        message:@"请输入被控端的内网IP地址"
                                                       delegate:self
                                              cancelButtonTitle:@"取消"
                                              otherButtonTitles:@"连接", nil];
        alert.alertViewStyle = UIAlertViewStylePlainTextInput;
        [alert show];
    } else {
        self.isClientMode = NO;
        [self disconnect];
    }
}

#pragma mark - UIAlertViewDelegate
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) {
        NSString *ip = [alertView textFieldAtIndex:0].text;
        if (ip.length > 0) {
            [self connectToIP:ip];
        } else {
            [self.clientSwitch setOn:NO animated:YES];
            self.isClientMode = NO;
        }
    } else {
        [self.clientSwitch setOn:NO animated:YES];
        self.isClientMode = NO;
    }
}

#pragma mark - ===== BSD Socket 网络 =====

- (NSString *)getLocalIP {
    NSString *address = @"error";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = getifaddrs(&interfaces);
    if (success == 0) {
        temp_addr = interfaces;
        while(temp_addr != NULL) {
            if(temp_addr->ifa_addr->sa_family == AF_INET) {
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
    }
    freeifaddrs(interfaces);
    return address;
}

- (void)startServer {
    if (_serverRunning) return;
    _serverRunning = YES;
    self.ipLabel.text = [NSString stringWithFormat:@"IP: %@", [self getLocalIP]];
    _serverThread = [[NSThread alloc] initWithTarget:self selector:@selector(serverThreadMain) object:nil];
    [_serverThread start];
}

// 服务端线程主函数
- (void)serverThreadMain {
    @autoreleasepool {
        int sock = socket(AF_INET, SOCK_STREAM, 0);
        if (sock < 0) {
            NSLog(@"创建socket失败");
            return;
        }
        int reuse = 1;
        setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));
        
        struct sockaddr_in addr;
        memset(&addr, 0, sizeof(addr));
        addr.sin_family = AF_INET;
        addr.sin_port = htons(SERVER_PORT);
        addr.sin_addr.s_addr = INADDR_ANY;
        if (bind(sock, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
            NSLog(@"绑定失败");
            close(sock);
            return;
        }
        listen(sock, 1);
        _serverSocket = sock;
        NSLog(@"服务端启动，等待连接...");
        
        struct sockaddr_in clientAddr;
        socklen_t len = sizeof(clientAddr);
        int client = accept(sock, (struct sockaddr *)&clientAddr, &len);
        if (client < 0) {
            NSLog(@"accept失败");
            close(sock);
            return;
        }
        _clientSocket = client;
        NSLog(@"客户端已连接");
        
        // 发送配对指令
        const char *pairMsg = "pair\n";
        send(client, pairMsg, strlen(pairMsg), 0);
        
        // 接收数据循环
        char buffer[1024];
        while (_serverRunning) {
            ssize_t n = recv(client, buffer, sizeof(buffer)-1, 0);
            if (n <= 0) break;
            buffer[n] = '\0';
            NSString *msg = [NSString stringWithUTF8String:buffer];
            [self performSelectorOnMainThread:@selector(handleReceivedMessage:) withObject:msg waitUntilDone:NO];
        }
        close(client);
        _clientSocket = -1;
        close(sock);
        _serverSocket = -1;
    }
}

- (void)connectToIP:(NSString *)ip {
    if (_clientSocket >= 0) {
        [self disconnect];
    }
    int sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) {
        [self.clientSwitch setOn:NO animated:YES];
        self.isClientMode = NO;
        return;
    }
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(SERVER_PORT);
    if (inet_pton(AF_INET, [ip UTF8String], &addr.sin_addr) <= 0) {
        close(sock);
        [self.clientSwitch setOn:NO animated:YES];
        self.isClientMode = NO;
        return;
    }
    if (connect(sock, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        close(sock);
        [self.clientSwitch setOn:NO animated:YES];
        self.isClientMode = NO;
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"连接失败" message:@"无法连接到该IP" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        return;
    }
    _clientSocket = sock;
    NSLog(@"连接成功");
    
    // 启动接收线程（使用NSThread）
    [NSThread detachNewThreadSelector:@selector(clientReceiveThreadMain) toTarget:self withObject:nil];
}

- (void)clientReceiveThreadMain {
    @autoreleasepool {
        char buffer[1024];
        while (_clientSocket >= 0) {
            ssize_t n = recv(_clientSocket, buffer, sizeof(buffer)-1, 0);
            if (n <= 0) break;
            buffer[n] = '\0';
            NSString *msg = [NSString stringWithUTF8String:buffer];
            [self performSelectorOnMainThread:@selector(handleReceivedMessage:) withObject:msg waitUntilDone:NO];
        }
    }
}

- (void)disconnect {
    if (_clientSocket >= 0) {
        close(_clientSocket);
        _clientSocket = -1;
    }
    if (_serverSocket >= 0) {
        close(_serverSocket);
        _serverSocket = -1;
    }
    self.isConnected = NO;
    _isPaired = NO;
}

- (void)stopServer {
    _serverRunning = NO;
    if (_serverSocket >= 0) {
        close(_serverSocket);
        _serverSocket = -1;
    }
    [self disconnect];
    if (_serverThread && ![_serverThread isFinished]) {
        [_serverThread cancel];
    }
    _serverThread = nil;
}

- (void)handleReceivedMessage:(NSString *)msg {
    msg = [msg stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([msg isEqualToString:@"pair"]) {
        // 收到配对请求，回应pong
        NSString *pong = @"pong\n";
        const char *data = [pong UTF8String];
        send(_clientSocket, data, strlen(data), 0);
        [self pairSuccess];
    } else if ([msg isEqualToString:@"pong"]) {
        // 收到配对回应
        [self pairSuccess];
    } else if ([msg hasPrefix:@"vibrate:"]) {
        float intensity = [[msg substringFromIndex:8] floatValue];
        if (intensity > 1.0) intensity = 1.0;
        if (intensity < 0) intensity = 0;
        NSNumber *num = [NSNumber numberWithFloat:intensity];
        [self performSelectorOnMainThread:@selector(vibrateWithIntensity:) withObject:num waitUntilDone:NO];
    }
}

- (void)pairSuccess {
    if (_isPaired) return;
    _isPaired = YES;
    self.isConnected = YES;
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"提示" message:@"蓝牙已连接" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alert show];
}

- (void)sendVibrationCommand:(float)intensity {
    if (!self.isConnected || !_isPaired || _clientSocket < 0) return;
    NSString *cmd = [NSString stringWithFormat:@"vibrate:%.2f\n", intensity];
    const char *data = [cmd UTF8String];
    send(_clientSocket, data, strlen(data), 0);
}

#pragma mark - UI 与滑块
- (void)sliderValueChanged:(UISlider *)sender {
    [self updateStatusLabel];
    if (self.isClientMode && self.isConnected && _isPaired) {
        [self sendVibrationCommand:sender.value];
    }
}

- (void)updateStatusLabel {
    float value = self.slider.value;
    NSString *text;
    if (value < 0.25) {
        text = @"还行awa";
    } else if (value < 0.5) {
        text = @"初现端倪";
    } else if (value < 0.75) {
        text = @"神秘";
    } else {
        text = @"要炸了qwq";
    }
    self.statusLabel.text = text;
}

- (void)buttonTapped:(UIButton *)sender {
    if (self.isVibrating) {
        [self stopVibration];
        [self.actionButton setTitle:@"启动震动" forState:UIControlStateNormal];
    } else {
        [self startVibration];
        [self.actionButton setTitle:@"停止震动" forState:UIControlStateNormal];
    }
}

#pragma mark - 震动控制
- (void)startVibration {
    if (self.isVibrating) return;
    self.isVibrating = YES;
    self.vibrationTimer = [NSTimer scheduledTimerWithTimeInterval:0.3
                                                           target:self
                                                         selector:@selector(vibrationTimerFired:)
                                                         userInfo:nil
                                                          repeats:YES];
}

- (void)stopVibration {
    if (!self.isVibrating) return;
    self.isVibrating = NO;
    [self.vibrationTimer invalidate];
    self.vibrationTimer = nil;
}

- (void)vibrationTimerFired:(NSTimer *)timer {
    float intensity = self.slider.value;
    NSNumber *num = [NSNumber numberWithFloat:intensity];
    [self vibrateWithIntensity:num];
}

- (void)vibrateWithIntensity:(NSNumber *)intensityNumber {
    float intensity = [intensityNumber floatValue];
    NSInteger count = (NSInteger)(intensity * MAX_VIBRATE_COUNT);
    if (count == 0) return;
    int interval = (int)(MAX_INTERVAL_USEC - intensity * (MAX_INTERVAL_USEC - MIN_INTERVAL_USEC));
    for (NSInteger i = 0; i < count; i++) {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
        usleep(interval);
    }
}

#pragma mark - 清理
- (void)dealloc {
    [self stopServer];
    [self disconnect];
    [self.vibrationTimer invalidate];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

@end