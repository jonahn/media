//
//  WWengAUAudioCapture.h
//  ShortVideo
//
//  Created by Jonathan on 2018/4/23.
//  Copyright © 2018年 WWeng. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface WWengAUAudioCapture : NSObject

@property (nonatomic, copy) void(^audioProcessingCallback)(CMSampleBufferRef sampleBuffer);



- (instancetype)initWithSampleRate:(double)sampleRate;

- (void)startCapture;

- (void)stopCapture;
@end
