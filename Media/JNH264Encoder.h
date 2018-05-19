//
//  JNH264Encoder.h
//  Media
//
//  Created by Jonathan on 2018/5/18.
//  Copyright © 2018年 JNStream. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>

@interface JNH264Encoder : NSObject
@property (nonatomic, assign) BOOL running;
@property (nonatomic, assign) CGSize videoSize;//视频大小
@property (nonatomic, assign) int fps; //帧率
@property (nonatomic, assign) int kbps; //码率
@property (nonatomic, assign) int gop;  //每过几秒设置关键帧, gop越大压缩越多，直播设置小一点:3

//不是关键帧没有sps pps
@property (nonatomic, copy)   void(^processingEncodedData)(NSData *sps, NSData *pps, NSData *frameData, BOOL isKeyFrame);

- (void)processVideoBuffer:(CVPixelBufferRef)pixelBuffer timeInfo:(CMTime)timeInfo;

- (OSStatus)run;

- (void)stop;
@end
