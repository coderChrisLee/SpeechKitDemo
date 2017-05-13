# SpeechKitDemo

## 基于iOS 10之后系统的SpeechKit框架进行语音识别
## Demo内有详细的注释,主要类别及作用：

 1. SFSpeechRecognizer *_recognizer;//语音识别器
 2. SFSpeechAudioBufferRecognitionRequest *_recognitionRequest;  //负责发起语音识别请求 为语音识别指定一个音频输入源
 3. SFSpeechRecognitionTask *_recognirionsTask; //页面内存储发起语音识别后的返回值，通过它可以取消或者中止当前的语音识别任务
 4. AVAudioEngine *_audioEngine; //语音引擎 负责提供录音输入
 
 参考链接：[Building a Speech-to-Text App Using Speech Framework in iOS 10](http://www.appcoda.com/siri-speech-framework/)
 
 运行效果图：
 
![语音识别](https://raw.githubusercontent.com/coderChrisLee/SpeechKitDemo/master/speechRecoginiton.PNG)
