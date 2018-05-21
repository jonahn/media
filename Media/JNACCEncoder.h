//
//  JNACCEncoder.h
//  Media
//
//  Created by Jonathan on 2018/5/21.
//  Copyright © 2018年 JNStream. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

@interface JNACCEncoder : NSObject
- (void)processSampleBuffer:(CMSampleBufferRef)sampleBuffer;
@end
