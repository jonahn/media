//
//  JNACCEncoder.m
//  Media
//
//  Created by Jonathan on 2018/5/21.
//  Copyright © 2018年 JNStream. All rights reserved.
//

#import "JNACCEncoder.h"
@interface JNACCEncoder ()
{
    dispatch_queue_t _encodeQueue;
}
@end
@implementation JNACCEncoder
- (instancetype)init
{
    self = [super init];
    if (self) {
        [self jn__setup];
    }
    return self;
}

- (void)jn__setup
{
    _encodeQueue = dispatch_queue_create("jn.ACCEncoder", DISPATCH_QUEUE_SERIAL);
}

- (void)processSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    
}
@end
