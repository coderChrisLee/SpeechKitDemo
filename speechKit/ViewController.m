//
//  ViewController.m
//  speechKit
//
//  Created by Chris Lee on 2017/5/9.
//  Copyright © 2017年 Chris Lee. All rights reserved.
//

#import "ViewController.h"
#import <Speech/Speech.h>

@interface ViewController ()<SFSpeechRecognizerDelegate> {
    SFSpeechRecognizer *_recognizer;
    SFSpeechAudioBufferRecognitionRequest *_recognitionRequest;  //负责发起语音识别请求 为语音识别制定一个音频输入源
    SFSpeechRecognitionTask *_recognirionsTask; //页面内存储发起语音识别后的返回值，通过它可以取消或者中止当前的语音识别任务
    AVAudioEngine *_audioEngine; //语音引擎 负责提供录音输入
}
@property (weak, nonatomic) IBOutlet UITextView *textView;
@property (weak, nonatomic) IBOutlet UIButton *microphoneButton;
@end

@implementation ViewController



- (void)viewDidLoad {
    [super viewDidLoad];
    //1. 进行语音识别之前 需要用户授权。因为语音识别并不是在iOS设备本地进行识别，而是所有的语音数据都要传给苹果的后台服务器进行处理识别，所以必须得到用户的授权。
    //zh-tw 中文台湾 zh-cn中文 zh-hk zh-sg中文(新加坡)
//    NSLocale *local = [NSLocale localeWithLocaleIdentifier:@"en-US"];
//    _recognizer = [[SFSpeechRecognizer alloc] initWithLocale:local];
//    Returns speech recognizer with user's current locale, or nil if is not supported
    _recognizer = [[SFSpeechRecognizer alloc] init];
    _microphoneButton.enabled = NO;  //禁用按钮 直到语音识别被激活
    _recognizer.delegate = self;
    _audioEngine = [[AVAudioEngine alloc] init];

    [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status) {
        BOOL isButtonEnabled = NO;
        if (status == SFSpeechRecognizerAuthorizationStatusAuthorized) {
            isButtonEnabled = YES;
        }else {
            //SFSpeechRecognizerAuthorizationStatusNotDetermined 未授权
            //SFSpeechRecognizerAuthorizationStatusDenied 拒绝
            //SFSpeechRecognizerAuthorizationStatusRestricted 在该设备上被限制
            isButtonEnabled = NO;
        }
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            self.microphoneButton.enabled = isButtonEnabled;
        }];
    
    }];
    
    /*2. 使用语音需要2个授权 a.使用麦克风  b. 语音识别  在info.plist中设置 右键Open As SourceCode
    添加2个key NSMicrophoneUsageDescription，NSSpeechRecognitionUsageDescription 写下描述信息
    NSMicrophoneUsageDescription : 这个key用于指定麦克风授权使用信息 在点击录音按钮时 才会提示
     NSSpeechRecognitionUsageDescription：这个用于语音识别授权  
     必须用真机测试
    */
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self.textView resignFirstResponder];
}

- (IBAction)microphoneTapped:(id)sender {
    //录音引擎 运行状态时
    if (_audioEngine.isRunning) {
        self.microphoneButton.enabled = NO;
        [self.microphoneButton setTitle:@"开始录音" forState:(UIControlStateNormal)];
        [_audioEngine stop];
        [_recognitionRequest endAudio];
    } else {
        [self.microphoneButton setTitle:@"停止录音" forState:(UIControlStateNormal)];
        [self startRecording];
    }
}
//苹果限制了每台设备的识别次数，次数没有明确。也限制了每个App的识别次数。
//如果经常达到限制，可以跟苹果公司联系。语言识别暂用更多的电量流量，语音识别的时长一次最长持续1分钟。



//当点击开始录音时调用 开始语音识别和监听麦克风
- (void)startRecording {
    if (_recognirionsTask != nil) {
        [_recognirionsTask cancel];
        _recognirionsTask = nil;
    }
    //检查音频引擎是否有输入源，即有效的录音入口
    AVAudioInputNode *inputNode = _audioEngine.inputNode;
    if (!inputNode) {
        NSLog(@"Audio engine has no input node");
        return;
    }
    //创建音频会话
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    NSError *error1 = nil;
    NSError *error2 = nil;
    NSError *error3 = nil;
    /*1. AVAudioSessionCategoryAmbient ---background sounds such as rain, car engine noise, etc
     2. AVAudioSessionCategorySoloAmbient ---background sounds.  Other music will stop playing
     3. AVAudioSessionCategoryPlayback --- Use this category for music tracks.
     4. AVAudioSessionCategoryPlayAndRecord ---when recording and playing back audio.
     5. AVAudioSessionCategoryAudioProcessing ---when using a hardware codec or signal processor while
     not playing or recording audio.
     6. AVAudioSessionCategoryMultiRoute ---
     Input is limited to the last-in input port. Eligible inputs consist of the following:
     AVAudioSessionPortUSBAudio, AVAudioSessionPortHeadsetMic, and AVAudioSessionPortBuiltInMic.
     Eligible outputs consist of the following:
     AVAudioSessionPortUSBAudio, AVAudioSessionPortLineOut, AVAudioSessionPortHeadphones, AVAudioSessionPortHDMI,
     and AVAudioSessionPortBuiltInSpeaker.
     Note that AVAudioSessionPortBuiltInSpeaker is only allowed to be used when there are no other eligible
     outputs connected.
    */
    [audioSession setCategory:AVAudioSessionCategoryRecord error:&error1];//7. Use this category when recording audio.
    [audioSession setMode:AVAudioSessionModeMeasurement error:&error2];
    [audioSession setActive:YES error:&error3];
    if (error1 || error2 ||error3) {
        NSLog(@"audioSession properties weren't set because of an error");
        return;
    }
    
    //在后面 用它将录音数据转发给苹果服务器
    _recognitionRequest = [[SFSpeechAudioBufferRecognitionRequest alloc] init];
    if ( !_recognitionRequest) {
        return;
    }
    
    _recognitionRequest.shouldReportPartialResults = YES;  //说话语音识别结果 分批返回 默认为YES
    
    // If request.shouldReportPartialResults is true, result handler will be called
    // repeatedly with partial results, then finally with a final result or an error.
    //识别器建立一个识别任务 每次采集到语音数据 返回最终文稿 以及取消停止出现错误时都会调用该block
    _recognirionsTask = [_recognizer recognitionTaskWithRequest:_recognitionRequest resultHandler:^(SFSpeechRecognitionResult * _Nullable result, NSError * _Nullable error) {
        BOOL isFinal = NO;
        if (result!=nil) {
            self.textView.text = result.bestTranscription.formattedString;//最佳音译文稿
            isFinal = result.isFinal;
        }
        //完成录音
        if (error != nil || isFinal) {
            [_audioEngine stop];
            [inputNode removeTapOnBus:0];
            _recognitionRequest = nil;
            _recognirionsTask = nil;
            self.microphoneButton.enabled = YES;
        }
    }];
    
    //向_recognitionRequest加入一个音频输入 可以在启动_recognirionsTask之后再添加音频输入 因为Speech框架会在添加完音频输入后立即开始识别
    AVAudioFormat *recordingFormat = [inputNode outputFormatForBus:0];
    [inputNode installTapOnBus:0 bufferSize:1024 format:recordingFormat block:^(AVAudioPCMBuffer * _Nonnull buffer, AVAudioTime * _Nonnull when) {
        [_recognitionRequest appendAudioPCMBuffer:buffer];
    }];
  
    //启动语音引擎
    [_audioEngine prepare];
    NSError *error4 = nil;
    [_audioEngine startAndReturnError:&error4];
    if (error4) {
        NSLog(@"audioEngine couldn't start because of an error.");
        return;
    }
    
    self.textView.text = @"说点什么吧，我在听";
    
}

//确保语音识别是可用的 当不可用或状态发生改变时 改变录音按钮enable属性
#pragma mark -SFSpeechRecognizerDelegate 代理方法
- (void)speechRecognizer:(SFSpeechRecognizer *)speechRecognizer availabilityDidChange:(BOOL)available {
    self.microphoneButton.enabled = available;
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
