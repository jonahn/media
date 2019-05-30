//
//  JNAACEncoder.h
//  Media
//
//  Created by Jonathan on 2018/5/21.
//  Copyright © 2018年 JNStream. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

@interface JNAACEncoder : NSObject
@property (nonatomic, assign) BOOL   running;
@property (nonatomic, assign) double inputSampleRate; //输入buffer帧率
@property (nonatomic, assign) double outputSampleRate; //编码输出帧率
@property (nonatomic, assign) int    kbps;       //码率

@property (nonatomic, copy) void(^processingEncodedData)(NSData *rawAAC);

- (void)processSampleBuffer:(CMSampleBufferRef)sampleBuffer;

- (OSStatus)run;

- (void)stop;
@end
