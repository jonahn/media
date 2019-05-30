//
//  JNMp3Encoder.h
//  Media
//
//  Created by Jonathan on 2019/5/30.
//  Copyright © 2019 JNStream. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface JNMp3Encoder : NSObject
@property (nonatomic, assign, readonly) BOOL   running;
@property (nonatomic, assign) double inputSampleRate; //输入buffer帧率
@property (nonatomic, assign) double outputSampleRate; //编码输出帧率
@property (nonatomic, assign) int  outputChannelsPerFrame; //输出频道数 单声道还是双声道
@property (nonatomic, assign) int  quality; // 0 - 9 (high - low)

@property (nonatomic, copy) void(^processingEncodedData)(NSData *mp3Data);

- (void)run;

- (void)stop;

- (void)processAudioBufferList:(AudioBufferList)audioBufferList;
@end

NS_ASSUME_NONNULL_END
