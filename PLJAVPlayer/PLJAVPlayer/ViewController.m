//
//  ViewController.m
//  PLJAVPlayer
//
//  Created by Edward on 16/12/14.
//  Copyright © 2016年 coolpeng. All rights reserved.
//

#import "ViewController.h"
#import <Masonry.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import "PLJConvertTime.h"

#define SCREEN_WIDTH [UIScreen mainScreen].bounds.size.width
#define SCREEN_HEIGHT [UIScreen mainScreen].bounds.size.height
#define HEIGHT 200
#define PADDING 40

#ifdef DEBUG
#define kDebugLog(...) NSLog(@"方法名：%s\n第%d行\n%@",__func__, __LINE__,[NSString stringWithFormat:__VA_ARGS__])
#else
#define kDebugLog(...)
#endif


/**
 *  滑动方向
 */
typedef NS_ENUM(NSUInteger, Direction) {
    DirectionLeftOrRight,
    DirectionUpOrDown,
    DirectionNone
};

@interface ViewController ()

@property (nonatomic,strong) UIView *viewContainer;// 底层视图，播放视图放在此图上
@property (nonatomic,strong) AVPlayerLayer *playerLayer; // 播放层
@property (nonatomic,strong) AVPlayer *player;// 播放器对象
@property (nonatomic,strong) AVPlayerItem *playerItem;// 播放内容
@property (nonatomic,strong) UIButton *playBtn;// 播放按钮
@property (nonatomic,strong) UIView *playPanel;// 播放面板
@property (nonatomic,strong) UISlider *progressSlider;// 播放进度
@property (nonatomic,strong) UIProgressView *loadingProgress;// 缓存进度
@property (nonatomic,assign) float currentTime;// 当前播放时间
@property (nonatomic,strong) UILabel *currentTimeLabel;// 当前播放时间显示
@property (nonatomic,strong) UILabel *totalTimeLabel;// 总时长
@property (nonatomic,strong) UIButton *fullScBtn;// 全屏按钮
@property (nonatomic,strong) UIActivityIndicatorView *indicator;// 加载指示器


/**
 *  手指滑动屏幕 实现亮度、音量、播放进度 调节
 */
@property (nonatomic,assign) CGPoint startP;//首次触摸的位置
@property (nonatomic,assign) Direction direction;// 滑动的方向
@property (nonatomic,assign) float startVB; // 开始触摸时的音量或者亮度值
@property (nonatomic,assign) float startProgressRate; // 开始触摸时的播放进度比
@property (nonatomic,assign) float currentProgressRate; // 当前的播放进度比
@property (nonatomic,strong) MPVolumeView *volumeView; // 音量视图
@property (nonatomic,strong) UISlider  *volumeSlider; // 音量条

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    [self viewContainer];
    [self createPlayerLayer];
    [self.viewContainer addSubview:self.indicator];
    [self.indicator startAnimating];
    [self playPanel];
    [self loadingProgress];
    [self progressSlider];
    [self currentTimeLabel];
    [self totalTimeLabel];
    [self fullScBtn];
    [self playBtn];

    // 设置声音视图的大小
    self.volumeView.frame = CGRectMake(0, 0, self.view.frame.size.width, 9*self.view.frame.size.width/16.0);

    // 添加 设备方向变化的通知
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationChanged) name:UIDeviceOrientationDidChangeNotification object:nil];
    
    // 对声音播放方式进行设置
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionMixWithOthers error:nil];

}

// 创建播放层
- (void)createPlayerLayer {
    
    //实例化播放层
    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    self.playerLayer.frame = CGRectMake(0, 0, SCREEN_WIDTH, HEIGHT);
    self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;// 设置填充模式
    
    //将播放层添加到视图层上
    [self.viewContainer.layer addSublayer:self.playerLayer];
}


#pragma mark 懒加载相关---------------
// 底图
- (UIView *)viewContainer {
    
    if (!_viewContainer) {
        
        _viewContainer = [[UIView alloc] init];
        _viewContainer.backgroundColor = [UIColor whiteColor];
        [_viewContainer addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapAction)]];// 点击手势
        [_viewContainer addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panAction:)]];// 滑动手势
        
        [self.view addSubview:_viewContainer];
        [_viewContainer mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.view).offset(40);
            make.left.and.right.equalTo(self.view);
            make.height.equalTo(@(HEIGHT));
        }];
    }
    return _viewContainer;
}

// 播放器
- (AVPlayer *)player {
    
    if (!_player) {
        
        _player = [AVPlayer playerWithPlayerItem:self.playerItem];
        
        //注册通知，处理视频播放完毕或用户手动退出事件
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(finishPlay) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
        
        CMTime interval = CMTimeMakeWithSeconds(0.1, NSEC_PER_USEC);
        
        __weak typeof (self) weakSelf = self;
        [_player addPeriodicTimeObserverForInterval:interval queue:NULL usingBlock:^(CMTime time) {
            // 获得当前播放的时间
            float currentTime = (float)CMTimeGetSeconds(time);
            weakSelf.currentTime = currentTime;
            weakSelf.currentTimeLabel.text = [NSString stringWithFormat:@"%@",[PLJConvertTime timeFormatFromTotalSeconds:(NSInteger)currentTime]];
            if (currentTime) {//更新进度条
                weakSelf.progressSlider.value = currentTime;
            }
        }];
    }
    return _player;
}

// 播放内容
- (AVPlayerItem *)playerItem {
    
    if (!_playerItem) {
        
        // 网络视频链接
        NSString *stringOne = @"http://124.205.69.162/mp4files/6100000000521645/clips.vorwaerts-gmbh.de/big_buck_bunny.mp4";
        
//        NSString *stringTwo = @"http://v.jxvdy.com/sendfile/w5bgP3A8JgiQQo5l0hvoNGE2H16WbN09X-ONHPq3P3C1BISgf7C-qVs6_c8oaw3zKScO78I--b0BGFBRxlpw13sf2e54QA";
//
        
        NSURL *url = [NSURL URLWithString:stringOne];
        
        // 加载本地文件 播放本地视频
//        NSURL *url = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"" ofType:@"mp4"]];
        
        _playerItem = [AVPlayerItem playerItemWithURL:url];
        
        //注册观察者 监听"status"属性
        [_playerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
        
        // 注册观察者 监听"loadedTimeRanges"属性 加载缓冲
        [_playerItem addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
    }
    return _playerItem;
}

// 播放面板
- (UIView *)playPanel {
    
    if (!_playPanel) {
        
        _playPanel = [[UIView alloc] init];
        _playPanel.backgroundColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:0.8];
        _playPanel.hidden = YES;
        [self.viewContainer addSubview:_playPanel];
        [_playPanel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.right.and.bottom.equalTo(self.viewContainer);
            make.height.equalTo(@(PADDING));
        }];
    }
    return _playPanel;
}

// 当前播放的时间
- (UILabel *)currentTimeLabel {
    
    if (!_currentTimeLabel) {
        _currentTimeLabel = [[UILabel alloc] init];
        _currentTimeLabel.backgroundColor = [UIColor clearColor];
        _currentTimeLabel.textAlignment = NSTextAlignmentCenter;
        _currentTimeLabel.font = [UIFont boldSystemFontOfSize:10];
        [self.playPanel addSubview:_currentTimeLabel];
        [_currentTimeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.and.left.equalTo(self.playPanel);
            make.size.equalTo(@(PADDING));
        }];
    }
    return _currentTimeLabel;
}


// 进度条
- (UISlider *)progressSlider {
    
    if (!_progressSlider) {
        
        _progressSlider = [[UISlider alloc] init];
        _progressSlider.minimumValue = 0.0;
        _progressSlider.tintColor = [UIColor redColor];
        _progressSlider.maximumTrackTintColor = [UIColor blackColor];
        
        [_progressSlider setThumbImage:[UIImage imageNamed:@"slider_progress_icon"] forState:UIControlStateNormal];
        [_progressSlider setThumbImage:[UIImage imageNamed:@"update_progress_icon"] forState:UIControlStateHighlighted];
        
        [_progressSlider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
        [_progressSlider addTarget:self action:@selector(newSliderValue:) forControlEvents:UIControlEventTouchUpInside];
        
        [self.playPanel addSubview:_progressSlider];
        
        [_progressSlider mas_makeConstraints:^(MASConstraintMaker *make) {
            make.centerY.equalTo(self.playPanel.mas_centerY);
            make.size.height.equalTo(@10);
            make.left.equalTo(self.playPanel).offset(PADDING);
            make.right.equalTo(self.playPanel).offset(-2*PADDING);
        }];
        
    }
    return _progressSlider;
}


// 缓存条
- (UIProgressView *)loadingProgress {
    
    if (!_loadingProgress) {
        
        _loadingProgress = [[UIProgressView alloc] init];
        _loadingProgress.progress = 0.0;
        _loadingProgress.progressTintColor = [UIColor whiteColor];// 已缓存区域的颜色
        _loadingProgress.trackTintColor = [UIColor clearColor];// 未缓存区域的颜色
        [self.playPanel addSubview:_loadingProgress];
        [_loadingProgress mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.progressSlider).offset(4.5);
            make.left.and.right.equalTo(self.progressSlider);
            make.height.equalTo(@3);
        }];
    }
    
    return _loadingProgress;
}


// 总时长label
- (UILabel *)totalTimeLabel {
    
    if (!_totalTimeLabel) {
        _totalTimeLabel = [[UILabel alloc] init];
        _totalTimeLabel.backgroundColor = [UIColor clearColor];
        _totalTimeLabel.textAlignment = NSTextAlignmentCenter;
        _totalTimeLabel.font = [UIFont boldSystemFontOfSize:10];
        [self.playPanel addSubview:_totalTimeLabel];
        [_totalTimeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.and.equalTo(self.playPanel);
            make.left.equalTo(self.progressSlider.mas_right);
            make.size.equalTo(@(PADDING));
        }];
    }
    return _totalTimeLabel;
}

// 全屏按钮
- (UIButton *)fullScBtn {
    
    if (!_fullScBtn) {
        _fullScBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_fullScBtn setImage:[UIImage imageNamed:@"fullSc"] forState:UIControlStateNormal];
        [_fullScBtn setImage:[UIImage imageNamed:@"escape_icon"] forState:UIControlStateSelected];
        
        [_fullScBtn addTarget:self action:@selector(fullScAction:) forControlEvents:UIControlEventTouchUpInside];
        [self.playPanel addSubview:_fullScBtn];
        [_fullScBtn mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.and.right.equalTo(self.playPanel);
            make.size.equalTo(@(PADDING));
        }];
    }
    return _fullScBtn;
}

//  播放按钮
- (UIButton *)playBtn {
    
    if (!_playBtn) {
        
        _playBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        
        [_playBtn setImage:[UIImage imageNamed:@"play_icon"] forState:UIControlStateNormal];
        [_playBtn setImage:[UIImage imageNamed:@"pause_icon"] forState:UIControlStateSelected];
        
        [_playBtn addTarget:self action:@selector(btnAction:) forControlEvents:UIControlEventTouchUpInside];
        [self.viewContainer addSubview:_playBtn];
        
        [_playBtn mas_makeConstraints:^(MASConstraintMaker *make) {
            make.center.equalTo(self.viewContainer);
            make.size.mas_equalTo(@48);
        }];
        _playBtn.layer.cornerRadius = 24;
        _playBtn.hidden = YES;
    }
    return _playBtn;
}

// 音量视图
- (MPVolumeView *)volumeView {
    
    if (!_volumeView) {
        _volumeView = [[MPVolumeView alloc] init];
        [_volumeView sizeToFit];
        
        for (UIView *view in _volumeView.subviews) {
            if ([view.class.description isEqualToString:@"MPVolumeSlider"]) {
                self.volumeSlider = (UISlider *)view;
                break;
            }
        }
    }
    return _volumeView;
}


// 加载指示器
- (UIActivityIndicatorView *)indicator {
    if (!_indicator) {
        _indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        _indicator.frame = CGRectMake(SCREEN_WIDTH*0.5-20, HEIGHT*0.5-20, 40, 40);
    }
    return _indicator;
}

#pragma mark KVO 执行观察者方法--------------
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {
    
    AVPlayerItem *playerItem = object;
    
    if ([keyPath isEqualToString:@"status"]) {// 播放状态
        
        AVPlayerStatus status = [[change objectForKey:@"new"] integerValue];
        
        if (status == AVPlayerStatusReadyToPlay) {
            
            self.progressSlider.maximumValue = CMTimeGetSeconds(playerItem.duration);
            
            self.totalTimeLabel.text = [PLJConvertTime timeFormatFromTotalSeconds:(NSInteger)self.progressSlider.maximumValue];
            [self.indicator stopAnimating];
            
            self.playPanel.hidden = NO;
            self.playBtn.hidden = NO;
            kDebugLog(@"准备播放。。。");
        }
        
    }else if ([keyPath isEqualToString:@"loadedTimeRanges"]) {
        
        NSArray *array = playerItem.loadedTimeRanges;
        
        CMTimeRange range = [array.firstObject CMTimeRangeValue];// 缓冲区域
        float startSeconds = CMTimeGetSeconds(range.start);
        float durationSeconds = CMTimeGetSeconds(range.duration);
        
        NSTimeInterval result = startSeconds + durationSeconds;// 缓冲总进度
        
        [self.loadingProgress setProgress:result * 1.0/ CMTimeGetSeconds(playerItem.duration) animated:YES];
    }
}


#pragma mark Events--------------------------
// 屏幕的单击事件
- (void)tapAction {
    self.playPanel.hidden = !self.playPanel.isHidden;// 隐藏或者显示播放面板
    self.playBtn.hidden = !self.playBtn.hidden;
}

//记录滑动屏幕开始的位置
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    
    UITouch *touch = [touches anyObject];
    self.startP = [touch locationInView:self.viewContainer];
}

// 播放或暂停事件
- (void)btnAction:(UIButton *)btn {
    
    if (self.player.rate == 0) {
        [self.player play];
        btn.selected = YES;
        [self.player seekToTime:CMTimeMakeWithSeconds(self.currentTime,1 * NSEC_PER_USEC)];
        
    }else if (self.player.status == 1) {
        [self.player pause];
        btn.selected = NO;
        [self.player seekToTime:CMTimeMakeWithSeconds(self.currentTime,1 * NSEC_PER_USEC)];
    }
}

//拖动进度条过程中  改变播放时间
- (void)sliderChanged:(UISlider *)slider {
    
    self.currentTimeLabel.text = [NSString stringWithFormat:@"%@",[PLJConvertTime timeFormatFromTotalSeconds:(NSInteger)slider.value]];
}
//根据拖动进度条最终的位置  改变播放进度
- (void)newSliderValue:(UISlider *)slider {
    [self.player seekToTime:CMTimeMakeWithSeconds(slider.value, 1 * NSEC_PER_USEC)];
}


// 屏幕缩放事件
- (void)fullScAction:(UIButton *)btn {
    
    if (btn.isSelected == YES) {
        [self changeScreenOrientation:UIInterfaceOrientationPortrait];
        btn.selected = NO;
    }else {
        [self changeScreenOrientation:UIInterfaceOrientationLandscapeRight];
        btn.selected = YES;
    }
}

// 屏幕滑动事件
- (void)panAction:(UIPanGestureRecognizer *)pan {
    
    /**
     UIGestureRecognizerStateBegan,     // 事件开始
     UIGestureRecognizerStateChanged,   // 事件处理中
     UIGestureRecognizerStateEnded,     // 事件结束
     */
    
    if (pan.state == UIGestureRecognizerStateBegan) {
        
        // 判断触摸的位置是位于屏幕的左侧还是右侧，左侧：亮度 右侧：音量
        if (self.startP.x <= self.viewContainer.frame.size.width) {// 亮度调节
            self.startVB = [[UIScreen mainScreen] brightness];
        }else {// 音量调节
            self.startVB = self.volumeSlider.value;
        }
        
        self.direction = DirectionNone;
        CMTime ctime = self.player.currentTime;
        self.startProgressRate = ctime.value / ctime.timescale / CMTimeGetSeconds(self.playerItem.duration);
        
    }else if (pan.state == UIGestureRecognizerStateChanged) {
        
        // 滑动的距离
        CGPoint panPoint = [pan translationInView:self.viewContainer];
        
        // 判断滑动的方向
        if (self.direction == DirectionNone) {
            
            if (panPoint.x >= 30 || panPoint.x <= -30) {
                self.direction = DirectionLeftOrRight;
            }else if (panPoint.y >= 30 || panPoint.y <= -30) {
                self.direction = DirectionUpOrDown;
            }
        }
        
        if (self.direction == DirectionNone) {
            return;
        }else if (self.direction == DirectionUpOrDown) {// 亮度和音量
            
            if (self.startP.x <= self.viewContainer.frame.size.width*0.5) {// 亮度
                
                if (panPoint.y > 0) {// 减少亮度
                    [[UIScreen mainScreen] setBrightness:self.startVB - (panPoint.y / 30.0 / 10)];
                }else {// 增加亮度
                    [[UIScreen mainScreen] setBrightness:self.startVB - (panPoint.y / 30.0 / 10)];
                }
                
            }else {// 音量
                
                if (panPoint.y > 0) {// 减少音量
                    
                    [self.volumeSlider setValue:self.startVB - (panPoint.y / 30.0 / 10) animated:YES];
                }else {// 增加音量
                    
                    [self.volumeSlider setValue:self.startVB + (-panPoint.y / 30.0 / 10) animated:YES];
                }
            }
            
        }else if (self.direction == DirectionLeftOrRight){// 进度
            float progressRate = self.startProgressRate +  (panPoint.x / 30.0 / 20);
            
            if (progressRate > 1) {
                self.currentProgressRate =1.0;
                self.currentTimeLabel.text = [PLJConvertTime timeFormatFromTotalSeconds:(NSInteger)self.progressSlider.maximumValue];
            }else if (progressRate < 0) {
                self.currentProgressRate = 0.0;
                self.currentTimeLabel.text = @"00:00";
            }else {
                self.currentProgressRate = progressRate;
                self.currentTimeLabel.text = [PLJConvertTime timeFormatFromTotalSeconds:(NSInteger)self.progressSlider.maximumValue * progressRate];
            }
        }
        
    }else if (pan.state == UIGestureRecognizerStateEnded) {
        
        if (self.direction == DirectionLeftOrRight) {
            [self.player seekToTime:CMTimeMakeWithSeconds(self.progressSlider.maximumValue * self.currentProgressRate, 1 * NSEC_PER_USEC)];
        }
    }
}


#pragma mark 通知处理---------------------
// 监听设备方向的变化
- (void)orientationChanged {
    
    // 获取设备的旋转方向
    UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
    
    switch (orientation) {
        case UIDeviceOrientationPortrait: {
            [self changeScreenOrientation: UIInterfaceOrientationPortrait];
            self.fullScBtn.selected = NO;
            break;
        }
        case UIDeviceOrientationLandscapeLeft: {// 当左右旋转时，设备方向和状态栏要旋转的方向相反
            [self changeScreenOrientation:UIInterfaceOrientationLandscapeRight];
            self.fullScBtn.selected = YES;
            break;
        }
        case UIDeviceOrientationLandscapeRight: {
            [self changeScreenOrientation:UIInterfaceOrientationLandscapeLeft];
            self.fullScBtn.selected = YES;
            break;
        }
        default:
            break;
    }
}

//视频播放完毕处理
- (void)finishPlay {
    
    [self.player seekToTime:kCMTimeZero completionHandler:^(BOOL finished) {
        self.playBtn.selected = NO;// 改变btn选中状态
        [self.progressSlider setValue:0.0 animated:YES];// 将进度条设置为0
        [self.player replaceCurrentItemWithPlayerItem:nil];
        [self.player replaceCurrentItemWithPlayerItem:self.playerItem];
    }];
}


#pragma mark Private Method--------------------

// 状态栏要旋转的方向
- (void)changeScreenOrientation:(UIInterfaceOrientation)orientation {
    
    //获取到当前状态栏的方向
    UIInterfaceOrientation currentOrientation = [UIApplication sharedApplication].statusBarOrientation;
    
    // 如果设备的方向和状态栏要旋转的方向一致，就不需要做任何适配
    if (currentOrientation == orientation) {
        return;
    }
    
    /**
     *  对要旋转的方向进行判断
     */
    if (orientation == UIInterfaceOrientationPortrait) {// 由横屏旋转成竖屏状态
        
        [self.viewContainer mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.view).with.offset(40);
            make.left.and.right.equalTo(self.view);
            make.height.equalTo(@(HEIGHT));
        }];
        
        /**
         注意此处：SCREEN_HEIGHT 的值为旋转之前横屏状态下的高度（手机实际的宽度），所以当旋转成竖屏时，屏幕的宽度即为 SCREEN_HEIGHT
         */
        self.playerLayer.frame = CGRectMake(0, 0, SCREEN_HEIGHT, HEIGHT);
        
    }else{// 旋转成横屏状态
        if (currentOrientation == UIInterfaceOrientationPortrait) {// 由竖屏状态旋转到横屏状态
            [self.viewContainer mas_remakeConstraints:^(MASConstraintMaker *make) {
                make.width.equalTo(@(SCREEN_HEIGHT));
                make.height.equalTo(@(SCREEN_WIDTH));
                make.center.equalTo(self.viewContainer.superview);
            }];
            self.playerLayer.frame = CGRectMake(0, 0, SCREEN_HEIGHT, SCREEN_WIDTH);
        }
    }
    
    // 设置状态栏的方向
    [[UIApplication sharedApplication]setStatusBarOrientation:orientation animated:NO];
    
    //  获取旋转状态栏所需的时间
    CGFloat duration = [UIApplication sharedApplication].statusBarOrientation;
    
    self.viewContainer.transform = [self makeRotation];
    
    [UIView setAnimationDuration:duration];
    [UIView commitAnimations];
}

//iOS6.0之后, 要想让状态栏可以旋转,必须设置状态栏不能自动旋转
- (BOOL)shouldAutorotate {
    return NO;
}


// 设置视频view要旋转的角度
- (CGAffineTransform)makeRotation {
    
    // 状态栏的方向
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    
    if (orientation == UIInterfaceOrientationPortrait) {
        return  CGAffineTransformIdentity;
    }else if (orientation == UIInterfaceOrientationLandscapeLeft) {
        return CGAffineTransformMakeRotation(-M_PI_2);
    }else if (orientation == UIInterfaceOrientationLandscapeRight) {
        return CGAffineTransformMakeRotation(M_PI_2);
    }else {
        return CGAffineTransformIdentity;
    }
}

- (void)dealloc {
    
    [self.playerItem removeObserver:self forKeyPath:@"status" context:nil];
    [self.playerItem removeObserver:self forKeyPath:@"loadedTimeRanges" context:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];

}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
