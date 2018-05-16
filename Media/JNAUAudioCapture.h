//
//  JNAUAudioCapture.h
//  ShortVideo
//
//  Created by Jonathan on 2018/4/23.
//  Copyright © 2018年 JNStream. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface JNAUAudioCapture : NSObject

@property (nonatomic, copy) void(^audioProcessingCallback)(CMSampleBufferRef sampleBuffer);

- (instancetype)initWithSampleRate:(double)sampleRate;

- (void)startCapture;

- (void)stopCapture;
@end
